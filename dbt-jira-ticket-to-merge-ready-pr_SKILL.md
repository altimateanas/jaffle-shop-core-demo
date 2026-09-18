---
name: dbt-jira-ticket-to-merge-ready-pr
description: >
  Turn a Jira ticket into a merge-ready dbt PR, with the safety checks that
  make the change trustworthy: DAG grounding via lineage, existing-pattern
  reuse via convention scan, byte-identical proof for pre-existing columns
  via equivalence, blast-radius enumeration with downstream owners, PII
  scan, and a final independent review pass that re-runs the same Altimate
  engines against the PR diff and posts an advisory verdict as a PR
  comment. Use when the user says "implement <JIRA-KEY>", "build the ticket
  <JIRA-KEY>", or hands you a Jira URL and asks for a PR. Delegates every
  safety-critical step to an Altimate-code engine — the LLM parses intent
  and composes SQL; engines decide whether the change is safe.
---

# dbt-jira-ticket-to-merge-ready-pr

## When to invoke

Trigger this skill when any of the following is true:

- User says "implement `<JIRA-KEY>`", "build `<JIRA-KEY>`", "turn
  `<JIRA-KEY>` into a PR", or pastes a Jira URL and asks for a dbt
  change.
- The change is scoped to a **single dbt project**, and the requested
  outcome is a PR (not a scratch investigation or an ad-hoc query).
- Atlassian MCP is connected in the workspace.

Do **not** invoke for:

- Refactors — use `refactor-dbt-with-report` instead.
- Cross-project changes (multiple dbt projects, warehouse migrations).
- Tickets whose acceptance criteria explicitly require breaking
  changes — this skill is optimized for additive-safe changes and will
  block itself at the equivalence gate. If the ticket is intentionally
  semantic, run with the `--allow-semantic-change` intent flag (see
  Phase 7).

## Non-goals

- Do **not** merge the PR. The final phase posts an advisory verdict;
  a human clicks merge.
- Do **not** refactor the target model, even if it is obviously
  bloated. If the ticket says "additive," respect it.
- Do **not** touch models outside the ticket's scope. Downstream models
  are read for blast radius, never modified.
- Do **not** create dashboards, warehouses, or infrastructure. Model +
  YAML + tests only.

## Inputs to collect from the user

Ask **once**, up front, only if not already given:

1. **Jira ticket key or URL** (required).
2. **Target dbt project path** — default: current working directory.
3. **Base branch** — default: `main`.
4. **Warehouse profile / target** — default: `dev` in `profiles.yml`.
   Needed for Phase 7 (equivalence build).

Do not ask about scope, tests, or which model to touch. Those come
from the ticket. Asking makes the demo weaker.

---

## Phase 1 — Fetch ticket

**Tool:** Atlassian MCP (`mcp__claude_ai_Atlassian__*`).

**Fetch:** ticket summary, description, acceptance criteria, labels,
comments, linked exposures (if present in ticket body).

**Store:** raw ticket payload in memory for provenance. Every later
phase references this — the PR body and review comment cite the
ticket key.

**Failure mode:** if Atlassian MCP is not connected or auth fails,
stop and prompt the user to run `mcp__claude_ai_Atlassian__authenticate`.
Do not proceed with a hand-copied ticket body — provenance matters.

---

## Phase 2 — Extract intent

**Tool:** one bounded LLM call.

**Return a structured object:**

```json
{
  "ticket_key": "AI-4823",
  "new_columns": [{"name": "first_order_channel",
                   "allowed_values": ["credit_card", "coupon",
                                      "bank_transfer", "gift_card",
                                      "mixed"]}],
  "target_layer_hint": "customer-facing customer model",
  "constraints": {
    "additive_only": true,
    "no_new_pii": true,
    "no_refactor": true,
    "reuse_existing_patterns": [
      {"pattern": "payment_methods list",
       "location_hint": "orders.sql"}
    ]
  },
  "downstream_owner_notification_required": true,
  "out_of_scope": ["BI dashboards", "refactoring"]
}
```

Everything downstream operates on this object, **not** raw ticket
prose. This keeps generation deterministic and makes the ticket
easy to swap for testing.

---

## Phase 3 — Ground in the DAG

**Tool:** `altimate_lineage_upstream` (and/or `altimate_lineage_column`
if the ticket names a column that already exists elsewhere).

**Do:**

1. From `target_layer_hint` ("customer-facing customer model"), enumerate
   candidate models — read `models/**/*.sql` + `schema.yml` descriptions.
2. Rank by lineage position — for a "customer-facing" hint, pick the
   model that is **upstream** of any consuming marts. In this repo,
   `customers` is upstream of `customer_lifetime_summary`, so
   `customers` wins.
3. If the new column's building blocks already exist elsewhere
   (`credit_card_amount` etc. live on `orders`), record the source so
   Phase 6 references them via `ref()` rather than recomputing.

**Output:** `{target_model: "customers", source_models: ["orders"]}`.

**Failure mode:** if lineage returns zero candidates or the top two are
tied, stop and ask the user to name the model. Do not guess.

---

## Phase 4 — Learn convention

**Tools:** `Grep`, `Read`, `altimate_test_introspect`.

**Scan for existing patterns matching the `reuse_existing_patterns`
list from Phase 2.** For each pattern:

- **Payment methods list:** grep for `payment_methods` across `models/`.
  Find it at `models/orders.sql:1`. Decide the reuse strategy:
  - If it's already a project var → reuse as-is.
  - If it's a local `{% set %}` → **promote** to `vars:` in
    `dbt_project.yml` and rewrite both callsites in the same commit.

**Also scan for house-style tests on adjacent columns.** In this repo,
`orders.status` uses `accepted_values` — mirror that shape when the
ticket asks for a constrained value set.

**Output:** list of edits to make **beyond** the target model, each
justified by a discovered pattern. Every edit here must be justifiable
as "matching an existing convention," not new invention.

---

## Phase 5 — Map blast radius

**Tool:** `altimate_lineage_downstream` (plus manual walk of
`exposures:` in schema files).

**Do:**

1. From `target_model` (`customers`), enumerate every downstream
   model, seed, snapshot, and exposure.
2. For each, extract owner from `meta.owner`, `meta.team`, or the
   exposure's `owner.email`.
3. Group by owner. This is the tagging list for the PR body.

**Expected in this repo, given `customers` as target:**

| Downstream | Kind | Owner |
|---|---|---|
| `orders` (via relationships test) | model | (no meta) |
| `customer_lifetime_summary` | model | analytics-engineering@altimate.ai |
| `orders_enriched` | model | analytics-engineering@altimate.ai |
| `weekly_marketing_dashboard` | exposure | marketing-analytics@altimate.ai |
| `finance_mrr_review` | exposure | finance-analytics@altimate.ai |

**Output:** blast radius table + de-duplicated owner list.

**If any downstream is a `high` maturity exposure** and the ticket did
not explicitly acknowledge it, add a note to the intent object that
Phase 10 review will surface.

---

## Phase 6 — Generate the change

**Tools:** `Read`, `Write`, `Edit`.

**Rules:**

1. **Additive only.** Do not delete or rewrite any existing line in
   `target_model`. New CTE(s) and new column(s) in the `final` select.
   Verify by diffing against pre-change file — every existing line
   must appear unchanged.
2. **Reuse discovered patterns.** Use the `payment_methods` project
   var promoted in Phase 4, not a new hardcoded list.
3. **Test coverage.** For every new column with `allowed_values`, emit
   an `accepted_values` test in the appropriate `schema.yml`, using
   the exact list from Phase 2.
4. **Descriptions.** Every new column gets a one-line `description:`
   in `schema.yml`. This is a project convention.
5. **No new files** unless the ticket requires a new model. This ticket
   is a column addition; no new SQL files.

**Concrete edits for AI-4823:**

- `models/customers.sql` — add a `first_order_channel_calc` CTE that
  joins to `orders` scoped to each customer's `first_order` date,
  classifying the payment mix into one of the five values. Add
  `first_order_channel` to the `final` select.
- `models/schema.yml` — add `first_order_channel` column entry to
  `customers` model with description + `accepted_values` test.
- `dbt_project.yml` — promote `payment_methods` to `vars:`.
- `models/orders.sql` — replace local `{% set payment_methods %}` with
  `{% set payment_methods = var('payment_methods') %}`.

---

## Phase 7 — Prove additivity (the safety gate)

**Tool:** `altimate_core_equivalence` (or fall back to `data-parity`
skill if unavailable).

**Do:**

1. Build the target model at HEAD (pre-change) into a sidecar table
   `<schema>.customers_before_ai4823`.
2. Apply the Phase 6 edits.
3. Build the target model post-change.
4. For every column that existed pre-change, compute row-count and
   column-hash. Compare.

**Pass criteria:**

- Row count identical.
- Every pre-existing column: byte-identical hash.

**On pass:** proceed to Phase 8.

**On fail:** **stop.** Do not open the PR. Emit the mismatch table
inline. This is the safety gate — a "one-line change" that moves
historical values is exactly what this gate exists to catch.

**Override:** if intent object carries `allow_semantic_change: true`,
skip the hard fail but require the PR body to include a migration
note section. Only set this flag when the ticket explicitly asks for
a semantic change (e.g., "fix the bucket boundary" tickets).

---

## Phase 8 — Scan for harm

**Tools:** `altimate_pii_scan`, `altimate_cost_estimate` (optional).

**PII scan:**

- Run on the diff (new columns only, not the whole model).
- If any new column classifies as PII → append a `⚠️ PII` block to the
  PR body and require reviewer acknowledgment in Phase 10.

**Cost delta (if tool available):**

- Estimate runtime + credit delta on the target model.
- Include as a one-line note in the PR body.

Both are informational — neither blocks the PR at this phase. The
blocking decision, if any, comes from Phase 10 based on ticket
constraints.

---

## Phase 9 — Open the PR

**Tools:** `git`, `gh pr create`.

**Do:**

1. Create branch: `<ticket-key-lower>/<slug>` — e.g.
   `ai-4823/first-order-channel`.
2. Commit with message: `<TICKET-KEY>: <ticket summary>` — no
   Co-Authored-By line unless user requested it.
3. Open PR against the base branch collected in Inputs.
4. **PR body structure:**

   ```markdown
   Implements [<TICKET-KEY>](<jira-url>).

   ## What changed
   - <one bullet per file touched>

   ## Why (from ticket)
   > <ticket description first paragraph, quoted>

   ## Safety evidence
   - **Additivity proof**: <equivalence table — row count, N columns byte-identical>
   - **Blast radius**: <owner-grouped downstream list from Phase 5>
   - **PII scan**: <clean | flagged: [column list]>
   - **Cost delta**: <if available>
   - **Convention reuse**: <pattern reused + location, e.g. `payment_methods` from `orders.sql:1` promoted to project var>

   ## Scope statement
   Refactoring of `customers` is explicitly out of scope per ticket.
   Only additive changes made.

   ## Downstream owners tagged
   @marketing-analytics @finance-analytics @analytics-engineering
   ```

5. **Do not** merge the PR. Do not enable auto-merge.

---

## Phase 10 — Independent review pass (advisory)

This is the phase that makes the whole workflow trustworthy. It
**re-runs the Altimate engines against the PR diff** (not against the
in-memory pre-PR state from earlier phases). Distinct inputs, distinct
tool calls, distinct verdict document.

**Do:**

1. **Re-fetch the PR diff** via `gh pr diff <PR#>`.
2. **Re-run `altimate_core_equivalence`** on the deployed branch —
   confirm the change on-disk still produces byte-identical pre-existing
   columns. (Catches: last-minute local edits, uncommitted files.)
3. **Re-run `altimate_lineage_downstream`** on the PR branch — confirm
   the blast radius stated in the PR body still matches reality.
4. **Re-run `altimate_pii_scan`** on the diff.
5. **Re-check `altimate_core_validate` + `dbt parse`** on the PR
   branch. Fails → verdict is `REQUEST_CHANGES` regardless of anything
   else.
6. **Convention check:** verify no new hardcoded literals matching
   patterns promoted in Phase 4. If `payment_methods` was promoted to
   a var but the diff still contains a hardcoded list somewhere, flag
   it.

**Compose verdict:**

| Signal | Weight |
|---|---|
| Any equivalence mismatch | Blocking (verdict → REQUEST_CHANGES) |
| Compile failure | Blocking |
| New PII column without ticket acknowledgment | Blocking |
| Downstream owner missed in PR body | Comment (verdict → COMMENT) |
| Convention regression (hardcoded pattern that should be var) | Comment |
| High-maturity exposure affected but not called out | Comment |
| All checks pass | Approve (verdict → APPROVE) |

**Post the verdict as a PR comment** via `gh pr review --comment` (or
`--request-changes` for blocking findings). **Never `--approve`
automatically** — even on a clean pass, the reviewer's verdict is
"Approve pending human review." Automation should not click the final
merge lever.

**Verdict comment format:**

```markdown
## Automated review — `dbt-jira-ticket-to-merge-ready-pr`

**Verdict:** <APPROVE | COMMENT | REQUEST_CHANGES>

**Re-run against PR diff:**
- Equivalence: <pass/fail + column count>
- Blast radius: <matches PR body? yes/no + delta>
- PII: <clean | flagged>
- Compile: <pass/fail>
- Convention: <clean | regressions>

**Findings:**
1. <finding + suggested action>

_This review re-invoked Altimate engines against the PR diff. It is
advisory — a human still owns the merge decision._
```

---

## Outputs the skill produces

- New branch on the local repo, pushed to remote.
- One open PR against base branch with evidence-rich body.
- One PR review comment from the automated reviewer.
- Inline chat summary: PR URL, verdict, and any blocking findings.

## Outputs the skill does **not** produce

- No merge.
- No auto-close of the PR (even on `REQUEST_CHANGES`).
- No changes to Jira ticket state (no auto-transition to "In Review").
  If the user wants that, they run it as a follow-up.

## Failure recovery

| Phase | Failure | Recovery |
|---|---|---|
| 1 | Atlassian MCP disconnected | Prompt user to authenticate. Do not fabricate ticket body. |
| 3 | Lineage ambiguous | Ask user to name target model. Do not guess. |
| 6 | Existing line modified (non-additive) | Roll back edits, re-generate with stricter additivity prompt. |
| 7 | Equivalence fails | **Stop.** Emit mismatch table. Do not open PR. |
| 8 | New PII flagged | Continue to PR, mark in body, escalate in Phase 10. |
| 9 | `gh` auth fails | Prompt user; do not commit locally without pushing. |
| 10 | Reviewer engine call fails | Post partial verdict with `[engine unavailable]` marker per missing signal. Do not skip Phase 10. |

## What earns this skill its keep

Vanilla LLM code assistants generate SQL. This skill's differentiator is
that **every step that could produce an unsafe outcome delegates to an
Altimate engine**:

- LLM chooses SQL text; equivalence engine decides if it's safe.
- LLM guesses the target model; lineage engine confirms.
- LLM writes tests; convention scan enforces they match house style.
- LLM authors the PR body; reviewer re-runs the engines to verify the
  body's claims match the diff.

The skill's reliability is not "the model is smart." It's "the engines
fence the model."
