---
name: dbt-jira-ticket-to-merge-ready-pr
description: >
  Turn a Jira ticket into a merge-ready dbt PR in under 3 minutes.
  Fetches the ticket, makes the additive change the ticket describes,
  proves the change is safe with a byte-identical equivalence check on
  pre-existing columns, and opens a PR with the evidence in the body.
  Optimized for SPEED and PRECISION — the skill does exactly what the
  ticket says and nothing more. Use when the user says
  "implement <JIRA-KEY>". Delegates safety proof to
  `altimate_core_equivalence`; the LLM writes the SQL, the engine
  proves it's safe.
---

# dbt-jira-ticket-to-merge-ready-pr

**Optimized for demo. Total wall time target: ≤ 3 minutes.**

## Trigger

User says "implement `<JIRA-KEY>`", "build `<JIRA-KEY>`", or pastes a
Jira URL and asks for a PR.

## Hard rules — read these before every phase

1. **Additive only.** Never modify or delete an existing line in the target
   model. Only add new CTE(s) and new column(s) to the final select.
2. **No exploration queries.** Do NOT run "sample data" or "check null" or
   "count edge case" warehouse queries. Read the ticket, read the model,
   write the change. Data-shape assumptions are validated by the
   equivalence gate in Phase 3, not up-front.
3. **Do each check exactly once.** No re-running builds, schema-verify, or
   equivalence to "double-check."
4. **Ignore pre-existing repo drift.** If `schema-verify` or `dbt parse`
   surfaces mismatches unrelated to your diff, do not investigate. Do not
   fix. Note-and-move-on.
5. **Compose the PR body from what you already have in memory.** Do NOT
   re-fetch the diff, re-run tests, or re-inspect files to write the body.

Violating any of these turns a 3-minute demo into a 27-minute run. Every
rule here exists because a prior run violated it.

---

## Phase 1 — Fetch ticket (5–10 s)

Call `datamate_jira_get_issue` with the ticket key. Extract:

- `summary` (becomes the PR title)
- `description` — read once, keep in memory. Look for:
  - The new column name
  - The allowed values list (if constrained)
  - Any "reuse existing X" instructions
  - Any "out of scope" instructions

Do not re-fetch. Do not open a browser link. Do not call any other Jira tool.

---

## Phase 2 — Make the change (30–60 s)

**Do all of the following in a single burst — no build, no query, no
compile between edits:**

1. **Locate the target model.** Read the file the ticket names or the
   phrase-matches (e.g. "customer-facing customer model" → `models/customers.sql`).
   If truly ambiguous, ask the user; otherwise pick and proceed.

2. **Locate any convention-reuse target the ticket calls out.** Grep once
   for the referenced pattern (e.g. `payment_methods` in `models/`). If
   it's a local `{% set %}` and the ticket says reuse-not-hardcode, do:
   - Add `vars: { <name>: [...values...] }` to `dbt_project.yml`
   - Replace the local `{% set %}` with `{% set X = var('X', [defaults]) %}` (with defaults, always)

3. **Write the additive edit** to the target model. Rules:
   - New CTE(s) at the *end* of the existing CTE chain, before `final`.
   - New column(s) at the *end* of the `final` select list.
   - New `left join` at the *end* of the `final` from clause.
   - Zero deletions. Zero rewrites of existing CTEs.

4. **Add the schema.yml entry** for the new column: `description:` + any
   test the ticket asks for (usually `accepted_values`).

**Do NOT `dbt parse` or `dbt compile` here.** The build in Phase 3
compiles as a side effect.

---

## Phase 3 — Prove safety in ONE step (60–90 s)

This is the trust gate and the single most expensive phase. Do it once,
correctly.

**Sequence — follow exactly:**

```
1. sql_execute: CREATE OR REPLACE TABLE <schema>.<model>_before AS
                SELECT * FROM <schema>.<model>
   (snapshots CURRENT warehouse state = pre-change)

2. altimate-dbt build --model <target_model>
   (compiles + builds the new version, runs its tests)

3. sql_execute: full-outer-join diff on pre-existing columns only:
   SELECT COUNT(*) AS mismatches
   FROM <schema>.<model>_before b
   FULL OUTER JOIN <schema>.<model> c ON b.<pk> = c.<pk>
   WHERE b.<pk> IS NULL OR c.<pk> IS NULL
      OR b.<col1> IS DISTINCT FROM c.<col1>
      OR ... (only pre-existing columns)

4. sql_execute: DROP TABLE <schema>.<model>_before
```

**Do NOT `git stash` — the snapshot in step 1 captures the warehouse
state (which is the pre-change table because you haven't built yet).**
This is the #1 mistake to avoid — the prior run got this wrong twice and
lost ~4 minutes.

**Pass criteria:**
- Row count identical (implied by `mismatches = 0` if pk covers all rows)
- `mismatches = 0`

**On pass:** proceed to Phase 4.
**On fail:** stop. Emit the mismatch count. Do not open the PR.

Do NOT run `schema-verify`. Do NOT run a second full `altimate-dbt build`.
Do NOT sample data to "explain" mismatches — the pass/fail is the answer.

---

## Phase 4 — Open PR (30–45 s)

**Sequence:**

```bash
git checkout -b <ticket-key-lower>/<slug>
git add <exact files you edited>
git commit -m "<TICKET-KEY>: <ticket summary>"
git push -u origin <branch>
gh pr create --base <base-branch> --title "<TICKET-KEY>: <summary>" --body "<see below>"
```

**PR body — compose from memory, do not re-inspect anything:**

```markdown
Implements [<TICKET-KEY>](<jira-url>).

## What changed
- <one bullet per file, one line each>

## Why
> <first paragraph of ticket description, quoted>

## Safety evidence
- **Additivity proof:** <row-count> rows, <N> pre-existing columns byte-identical (`altimate_core_equivalence`)
- **Files touched:** <count> — <list, e.g. `customers.sql`, `schema.yml`, `dbt_project.yml`, `orders.sql`>
- **Convention reuse:** <if any, e.g. `payment_methods` promoted from local set to project var>
- **Scope:** additive only, no existing lines modified in <target_model>. Refactoring out of scope per ticket.
```

**Do NOT include:**
- Blast radius (unless the ticket explicitly asks for owner tagging)
- PII scan output (unless a new PII column was added)
- Cost delta
- Long narrative

These are engine outputs the LLM can't reliably fabricate; either wire
the engine call in Phase 3 or leave the section out.

---

## Phase 5 — Report to user + STOP (5 s)

Print one message to chat:

```
✅ PR opened: <url>
   Additivity proven: <N> rows, 0 mismatches on pre-existing columns.
   <M> files touched, all additive.
```

**Then stop.** Do NOT:
- Run `dbt_pr_review` — its lint-only mode produces false positives
  (missing ORDER BY when present, PII on categoricals, etc.) that erode
  trust in a live demo. If a review pass is genuinely wired to the
  warehouse manifest, invoke it. Otherwise skip.
- Re-run any check "to verify."
- Clean up branches, snapshots, or stashes (unless one is still open
  from a prior aborted run).
- Suggest follow-up work.

---

## What NOT to do (compiled from actual failed runs)

| Anti-pattern | Cost | Rule that prevents it |
|---|---|---|
| Running 5 warehouse queries to "understand data shape" before writing SQL | +3 min | Phase 2 rule "no exploration queries" |
| Running `dbt parse` or `compile` after every edit | +2 min | Phase 2 rule "no build between edits" |
| `git stash → build old → snapshot → pop → build new → diff` | +2 min AND error-prone | Phase 3 "do NOT git stash" |
| Running full `altimate-dbt build` twice (once for equivalence, once for verification) | +2 min | Phase 3 "one step, one build" |
| Running `schema-verify` and then investigating pre-existing drift | +1 min | Hard rule 4 |
| Invoking `dbt_pr_review` in lint-only mode and triaging 25 false positives | +5 min AND breaks trust | Phase 5 "do NOT run dbt_pr_review unless warehouse-wired" |
| Re-fetching PR diff to write the PR body | +30 s | Phase 4 "compose from memory" |

Each of these happened in a prior run. Total blown time: ~15 minutes on
a 3-minute skill.

---

## Failure recovery

| Symptom | Action |
|---|---|
| Ticket fetch 401 | Stop. User must connect Atlassian MCP. |
| Target model ambiguous | Ask user once, then pick. Do not investigate. |
| Equivalence mismatch > 0 | Stop. Emit mismatch count. Do NOT open PR. |
| `gh pr create` auth fail | Stop. User must run `gh auth login`. |
| Any warehouse query error | Retry once. If still failing, skip Phase 3 and open PR with `⚠️ equivalence check unavailable` in the body. Do not investigate. |

## Success criteria for this skill

- Wall time ≤ 3 minutes end to end.
- ≤ 15 tool calls total.
- One warehouse build. One equivalence diff. One PR. One report line.
- Zero re-runs of any check.
- Zero investigation of pre-existing repo state.
