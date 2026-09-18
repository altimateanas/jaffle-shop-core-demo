# Demo — Jira Ticket → Merge-Ready dbt PR

**Total budget: 5 minutes.** Hard cap. Skill itself runs in ≤ 3 min.
**Branch:** `dbt-jira-use-case`
**Ticket:** `DEMO-81`
**Skill:** `dbt-jira-ticket-to-merge-ready-pr`

**Time budget:**

| Step | Cap | What |
|---|---|---|
| 1 | 0:20 | Set the scene — read the ticket line |
| 2 | 0:05 | Invoke skill (`Implement DEMO-81`) |
| 3 | 3:00 | Skill runs — narrate 3 headline beats |
| 4 | 0:45 | Walk the PR body |
| 5 | 0:30 | Diff stat + close line |
| **Total** | **~4:40** | 20s slack |

**What the skill does NOT do** (cut for speed and trust):
- Auto-review its own PR. The auto-reviewer in lint-only mode produces
  false positives (missing ORDER BY when present, PII on categoricals).
  Better to skip than to explain away noise.
- Explore data shape before writing SQL. Equivalence is the proof.
- List blast radius or PII scan in the PR body unless the ticket asks.
  Every claim in the PR body must be an engine output.

---

## Context — your prep, NOT your script

*Read this before you demo. Do not read it out loud during the 5-min
budget. Say-out-loud lines are marked in italics in DEMO STEPS.*

**The gap this demo closes.** Every AI code assistant can generate SQL.
None of them can prove the change is safe before asking a human to review
it. This demo is about that gap.

**The mechanism.** A PM's Jira ticket becomes a merge-ready dbt PR. The
skill delegates the safety-critical step to an Altimate engine:
`altimate_core_equivalence` proves every pre-existing column on the
target model is byte-identical after the change. The ticket said
"additive." The engine proves it.

**One-line pitch (say only if asked "what am I looking at?"):**
> *"AI you can trust with production dbt — because the safety proof is an
> engine, not a promise."*

**What we do NOT claim:** the PR is auto-merged. A human clicks merge.

---

## Prerequisites (do these once, before the demo)

1. **Repo on branch `dbt-jira-use-case`, working tree clean.**
   ```bash
   git checkout dbt-jira-use-case
   git pull
   git status
   ```
2. **dbt profile connects.** `dbt debug` green.
3. **Workspace has this skill loaded:**
   `dbt-jira-ticket-to-merge-ready-pr` (from
   `jaffle-shop-core-demo/dbt-jira-ticket-to-merge-ready-pr_SKILL.md` in this
   repo — attach to Workspace). Also add JIRA integration in workspace setup with proper creds.
4. Remove files `dbt-jira-ticket-to-merge-ready-pr_SKILL.md` and `jaffle-shop-core-demo/DEMO_SCRIPT.md` from your repo as they may cause confusion.
5. **Altimate-code warehouse connection wired** (`jaffle_shop_core_dev`
   or equivalent). The skill needs `sql_execute` to run the equivalence
   snapshot + diff.
6. **Atlassian MCP is connected** and can reach the Jira site hosting
   `DEMO-81`. If OAuth prompt appears mid-demo, you lose ~20s — approve
   ahead of time.
7. **`DEMO-81` exists in Jira** with the description from the "Ticket
   content" section below.
8. **`gh` CLI is authenticated** (`gh auth status`).
9. **Drop stale sidecar if present:**
   ```sql
   DROP TABLE IF EXISTS anas.js_dbt.customers_before;
   ```
10. In Workspaces:

```
Implement JIRA <Ticket no>.
```
---

## Ticket content — paste this into Jira as `DEMO-81`

**Title:** `Add first_order_channel to customer reporting`

**Description:**

> For a Q4 acquisition experiment, Marketing needs to know the payment
> channel of each customer's **first** order. Add a `first_order_channel`
> column to the customer-facing customer model.
>
> Values: `credit_card`, `coupon`, `bank_transfer`, `gift_card`, `mixed`
> (`mixed` = first order combined more than one method). Derive from the
> `*_amount` columns already on `orders`.
>
> **Acceptance criteria**
> - Column exists on the customer-facing customer model.
> - Additive only — existing columns byte-identical, no historical values move.
> - `accepted_values` test on the five values above.
> - No new PII.
> - Reuse the existing `payment_methods` list from `orders.sql` — don't re-hardcode.
>
> **Out of scope:** dashboard changes, any refactoring.

**Labels:** `analytics-engineering`, `additive-change`, `q4-campaign`

---

## DEMO STEPS

### 1. Set the scene (0:20)

Ticket open in a browser tab. Read only the **first sentence** aloud:
*"For a Q4 acquisition experiment, Marketing needs the payment channel
of each customer's first order."* Then one framing line:

> *"Prose from a PM. Watch the skill make the change and prove nothing
> else moved."*

### 2. Invoke the skill (0:05)

In Workspaces:

```
Implement DEMO-81.
```

That's it. No model name, no column spec, no test hints.

### 3. Watch it work (3:00, hands-off — narrate 3 beats only)

The skill runs 5 phases. **Do not narrate all of them** — speak only at
these three moments:

| When | Beat | Say |
|---|---|---|
| ~0:15 in — after ticket fetch | **Grounding** | *"It read the ticket, picked `customers` as the target — the only customer-facing customer model — and is now writing the additive edit."* |
| ~1:00 in — when the build runs | **The safety gate** *(pause on this — this is the payoff)* | *"This is the safety gate. It's building the model, then diffing every pre-existing column against the pre-change snapshot. If any of them moved, the skill stops here and no PR opens. That's the trust anchor — the engine decides, not the model."* |
| ~2:30 in — after PR opens | **Done** | *"PR is up. Body has the equivalence proof — row count and column-hash match. Now the human takes over."* |

Everything else — the Jinja loops, the schema.yml edit, the project-var
promotion — **runs silently.** They show up in the diff; that's where
you'll walk them.

### 4. Walk the PR (0:45 — the payoff)

Open the PR in a browser. Do it in this order:

1. **PR body — "Safety evidence"** (~20s). Point at:
   - Additivity proof: `100 rows, 6 pre-existing columns byte-identical`
   - Files touched: 4
   - Convention reuse: `payment_methods` promoted to project var
   > *"Every claim in this body is an engine output, not a paragraph."*

2. **PR body — "What changed"** (~15s). Read the 4 bullets. Emphasize
   that `customers.sql` was only added-to, never rewritten.
   > *"Zero existing lines deleted from the target model. Ticket said
   > no refactor — skill obeyed."*

3. **PR body — "Why"** (~10s). Point at the ticket-quoted paragraph.
   > *"The reason for the change is the ticket. Linked back, one click
   > away."*

### 5. Diff + close (0:30)

```bash
git diff --stat main..HEAD
```

Expected: 4 files touched.
- `models/customers.sql` — new CTEs, new column, zero deletions
- `models/schema.yml` — `first_order_channel` column entry + test
- `dbt_project.yml` — `payment_methods` promoted to project var
- `models/orders.sql` — one-line change to consume the var

Close:
> *"Three minutes ago this was a paragraph from a PM. Now it's a PR with
> an equivalence proof — 100 rows, zero mismatches on pre-existing
> columns — linked back to the ticket. The engine gates the safety, the
> LLM writes the SQL, the human owns the merge. That's the loop."*

---

## Optional — the "bad path" companion (`DEMO-82`)

**Skip if tight on time.** Powerful if the audience asks for a second
round — because it shows the safety gate **refusing** to open a PR.

**Ticket to create:** `DEMO-82` — *"Fix the value-segment cutoffs on
`customer_lifetime_summary` — the `mid_value` band should start at 15,
not 20."*

Run:
```
Implement DEMO-82.
```

The skill will produce a valid-looking one-line change. **Phase 3
(equivalence) fails** — customers in the LTV 15-19 band flip segments.

- The skill **stops before opening a PR**.
- Chat shows the mismatch count.
- Say: *"Ticket said 'fix,' but equivalence saw N customers change
  segment. Semantic change, not additive. No PR opens — human owns
  the migration call."*

---

## Reset between runs

```bash
git checkout .
git checkout dbt-jira-use-case
git status                                         # clean

# Close the demo PR (do NOT merge):
gh pr close <PR#> --delete-branch

# Revert DEMO-81 to "To Do" in Jira.

# Drop the sidecar:
DROP TABLE IF EXISTS anas.js_dbt.customers_before;
```

---

## If something breaks

| Symptom | Recovery |
|---|---|
| Atlassian MCP prompts for OAuth mid-demo | Approve in browser, re-run. Costs ~20s. |
| Skill runs > 5 min | Interrupt. This is a skill bug — read the trace, tighten SKILL.md. Do not try to salvage the run on stage. |
| Phase 3 equivalence fails on `DEMO-81` (should pass) | The additive change wasn't actually additive. Read the mismatch out loud — this is the gate doing its job. Do not open the PR. Investigate offline. |
| `gh pr create` fails on auth | Run `gh auth status`, re-auth, re-run. |
| Skill invokes `dbt_pr_review` and it fires 20 lint findings | Interrupt. SKILL.md forbids this — the review tool is in lint-only mode and produces false positives. Fix the skill, don't triage the findings. |
| Demo running long | Skip Step 5 (diff walkthrough). Step 4 (PR body) is the payoff. |

---

## What lives in this branch

- `.claude/skills/dbt-jira-ticket-to-merge-ready-pr/SKILL.md` — the skill (lean, 5 phases)
- `DEMO_SCRIPT.md` — this file
- `models/marts/customer_lifetime_summary.sql` — downstream mart (used by "bad path" ticket)
- `models/marts/orders_enriched.sql` — downstream mart
- `models/marts/schema.yml` — marts docs + exposures + owner metadata
- `models/schema.yml` — baseline schema (with `total_order_amount` → `customer_lifetime_value` drift fixed)
- All jaffle-shop baseline models from `main`

The skill is the deliverable. Everything else is the stage.
