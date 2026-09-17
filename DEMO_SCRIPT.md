# Demo Script — dbt Model Refactoring on Altimate Workspaces

**Audience:** dbt / analytics-engineering practitioners
**Duration:** 12–15 minutes end-to-end
**Branch:** `dbt-model-refactoring-demo`
**Target model:** `customer_order_summary`

---

## What you are demoing

A bloated real-world-shaped dbt model — grown organically over months —
gets refactored on Workspaces using a custom skill (`refactor-dbt-with-report`)
that delegates to Altimate's built-in dbt skills. The demo ends with a
concrete, quantified before/after report the skill displays inline — and
optionally saves as `REFACTOR_REPORT.md` if the audience wants a file to
share.

---

## Pre-demo checklist (do this once, before the room joins)

1. `git checkout dbt-model-refactoring-demo`
2. `git status` — confirm clean working tree (only ignored files present).
3. Open the repo in Workspaces. Confirm the following files are visible:
   - `models/marts/customer_order_summary.sql` ← the messy target
   - `models/marts/customer_kpis.sql` ← downstream #1
   - `models/marts/orders_enriched.sql` ← downstream #2
   - `models/marts/schema.yml`
   - `.claude/skills/refactor-dbt-with-report/SKILL.md` ← the custom skill
4. Confirm the Altimate skills are loaded (Workspaces sidebar shows
   `dbt-analyze`, `dbt-develop`, `data-parity`, `cost-report`,
   `query-optimize`, `lineage-diff`, `dbt-schema-verify`).
5. (If demoing warehouse mode) confirm Snowflake profile is reachable:
   `dbt debug --target dev` should succeed.
6. Delete any stale `REFACTOR_REPORT.md` from a previous run (only relevant
   if you plan to demo the "save the report" prompt).

---

## The 30-second setup line

> "This is jaffle_shop — the canonical dbt demo project. Someone on the team
> added `customer_order_summary` about six months ago. It started small and
> now it's 250 lines with seven joins, two self-joins, and a 60-line CTE
> that does RFM segmentation. Two dashboards depend on it. Nobody wants to
> touch it. We're going to fix it in the next ten minutes without breaking
> anything downstream."

---

## Step-by-step run

### Step 1 — Show the mess (60s)

Open `models/marts/customer_order_summary.sql`. Scroll top-to-bottom slowly.
Call out:

- Line ~40: payment pivot re-implemented inline (already exists in `orders.sql`)
- Line ~65: self-join on `raw_orders` for "second order date"
- Line ~90: correlated subquery inside another self-join for "first order"
- Line ~140: RFM CASE statements with hardcoded thresholds
- Line ~180: `first_order_details` and `most_recent_order_details` — near-duplicate CTEs

Then open `customer_kpis.sql` and `orders_enriched.sql` — say:

> "Both of these `ref` the monster. Whatever we do has to keep them working."

### Step 2 — Invoke the custom skill (30s)

In Workspaces, type:

```
Refactor customer_order_summary using the refactor-dbt-with-report skill.
```

The skill will ask three questions. Answer them live:

| Question | Answer to give |
|---|---|
| Target model? | `customer_order_summary` |
| Include warehouse query stats? | **Ask the room.** If they say yes and Snowflake is wired up → yes, profile `dev`, 30 days. If they hesitate → no, static-only. |
| Parity strictness? | Row-count + spot-check hash (default) |

### Step 3 — Phase 1: Baseline capture (~2 min)

The skill will:
- Emit static metrics for the current model (lines, joins, CTEs, largest CTE)
- Call `dbt-analyze` → show the downstream tree (`customer_kpis`,
  `orders_enriched`) and which columns each consumes
- *(if warehouse=yes)* Call `cost-report` → show current avg runtime, credits,
  run frequency for the target model

**Talking point while it runs:**
> "Notice we haven't changed a single character of SQL yet. The skill is
> capturing what 'good' has to look like before it moves — row count,
> column outputs, and downstream contracts."

### Step 4 — Phase 2: Plan review (~2 min)

The skill emits a plan. Expect roughly:

- Extract `int_order_payment_methods` — the payment pivot
- Extract `int_customer_order_history` — RFM + tenure aggregations
- Extract `int_customer_first_last_orders` — first + most-recent order details
- Hoist `payment_methods`, `tenure_thresholds`, `monetary_thresholds` to `dbt_project.yml` vars
- Reduce `customer_order_summary` to a thin join over the three intermediates
- Preserve the current column list byte-for-byte

**Say "go" to approve.**

### Step 5 — Phase 3: Execute (~3 min, mostly hands-off)

The skill creates the intermediate files, updates `schema.yml`, rewrites the
target model, and runs `altimate-dbt compile` after each change. Narrate:

> "Every file change is followed by a compile check. If anything is broken,
> we know immediately — not after we've made 15 changes."

### Step 6 — Phase 4: Parity validation (~2 min)

The skill materializes the refactored model to a sidecar name and calls
`data-parity` against the baseline. Expected output: row counts match,
grain-column hash matches, spot-check numeric column matches.

**Talking point:**
> "This is the safety net. If we accidentally changed a `left join` to an
> `inner join`, or dropped a NULL row somewhere, data-parity catches it here
> — before it hits the dashboards."

### Step 7 — Phase 5: Post-refactor signals (~1 min, warehouse mode only)

The skill runs `query-optimize` on the cleaner SQL and surfaces next-step
recommendations (typically: this model is now a strong incremental candidate
because the extracted intermediates make the delta pattern obvious). These
recommendations are **not** applied — they're captured in the report as
"next steps".

### Step 8 — Walk the report (~2 min)

The skill will **display the report inline in chat**. Walk the tables row by
row without switching windows.

**Static mode (no warehouse):**
- Lines: 250 → ~30 in target (~85% reduction)
- Joins in target: 7 → 3
- CTEs in target: 8 → 3
- Largest CTE: 60 → ~15 lines
- Repeated literals: 4 → 0 (all in vars)
- Unused columns removed: 2 (the `used_*_flag` columns nothing consumed)

**Warehouse mode (adds):**
- Avg runtime delta
- Credits over window delta
- Estimated annual savings

Then walk through the "Parity evidence" section and the "Next-step
optimizations" section. Close with:

> "This report is the deliverable. It goes in the PR description, it goes in
> the team's #data-eng channel, and it proves the refactor was safe."

**Then the skill asks:** *"Do you also want me to save this report to
`REFACTOR_REPORT.md` in the project root?"*

- **For a live customer-facing demo:** answer **yes** so you can screenshot
  the file, drop it into a follow-up email, or open it side-by-side.
- **For a quick internal walkthrough:** answer **no** — the inline display
  is enough and it keeps the repo clean between runs.

### Step 9 — (Optional, 30s) show the diff

`git diff --stat` in the terminal. Audience sees:
- 3 new small files in `models/marts/intermediate/`
- 1 rewritten `customer_order_summary.sql`
- 1 updated `dbt_project.yml` (new vars)
- 1 updated `models/marts/schema.yml`
- 1 new `REFACTOR_REPORT.md` *(only if you said "yes" to save in Step 8)*

---

## Reset instructions (between demo runs)

```bash
git checkout .
git clean -fd models/marts/intermediate/  # only if the skill created this dir
rm -f REFACTOR_REPORT.md
git status  # should be clean
```

If the skill materialized `_before` / `_after` sidecar tables in Snowflake
that it did not clean up, drop them:

```sql
DROP SCHEMA IF EXISTS <db>.refactor_baseline_<yyyymmdd>;
DROP SCHEMA IF EXISTS <db>.refactor_candidate_<yyyymmdd>;
```

---

## What to say if something goes wrong

| Symptom | Recovery |
|---|---|
| Skill can't find `dbt-analyze` | Confirm Altimate skills are enabled in Workspaces settings. Fall back to static-only mode. |
| `data-parity` fails on row count | This is the demo's best moment — say "this is why we do it". Show the diff, roll back, do not deploy. |
| Warehouse mode times out | Cancel and re-run in static-only mode. The report still lands with code-shape metrics. |
| `dbt compile` fails after Phase 3 | Skill will surface the error. Read it out loud, fix the one line, re-run compile. |
| Report shows no downstream consumers | You forgot to seed `customer_kpis` / `orders_enriched`. Check the branch. |

---

## Talking points to weave in

- **"We didn't invent anything."** The custom skill delegates to `dbt-analyze`,
  `data-parity`, `cost-report`, `query-optimize` — all shipped with Altimate.
  The skill's job is to orchestrate them into a repeatable refactor flow.
- **"The report is the point."** The refactored code is nice; the quantified
  report is what makes this defensible in a PR review.
- **"Parity is non-negotiable."** No refactor ships without a passing
  `data-parity` result. This is how you refactor without fear.
