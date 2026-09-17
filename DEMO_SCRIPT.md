# Demo Script — dbt Model Refactoring on Altimate Workspaces

**Audience:** dbt / analytics-engineering practitioners
**Duration:** 5–6 minutes end-to-end (up to 8 with the optional warehouse benchmark)
**Branch:** `dbt-model-refactoring-demo`
**Target model:** `customer_order_summary`

---

## What you are demoing

A bloated real-world-shaped dbt model — grown organically over months —
gets refactored on Workspaces using a custom skill (`refactor-dbt-with-report`)
that delegates to Altimate's built-in dbt skills. The demo ends with a
quantified before/after report the skill displays inline — leading with a
plain-English **Bottleneck Summary** and an **Outcome Axes Improved** table
(readability, maintainability, performance, cost, governance, best-practice
compliance) — and an optional final step that measures the refactor
against real Snowflake query history.

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
6. If a Snowflake `customer_order_summary_before` table exists from a
   prior run, drop it (see the reset section below).

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

The skill will ask **two** questions up front. Answer them live:

| Question | Answer to give |
|---|---|
| Target model? | `customer_order_summary` |
| Parity strictness? | Row-count + spot-check hash (default) |

**Warehouse benchmarking is NOT asked here.** The skill offers it as an
optional final step (Step 9) after the report is displayed. This keeps the
main run fast and lets the audience decide whether real-warehouse numbers
matter for them.

### Step 3 — Phase 1: Baseline capture (~90s)

The skill will (in parallel where possible):
- Emit static metrics for the current model (lines, joins, CTEs, largest CTE)
- Call `dbt-analyze` → show the downstream tree (`customer_kpis`,
  `orders_enriched`) and which columns each consumes
- Materialize a `_before` snapshot of the current model + capture an
  aggregate signature (row count, sum/min/max on `customer_lifetime_value`)

**Talking point while it runs:**
> "Notice we haven't changed a single character of SQL yet. The skill is
> capturing what 'good' has to look like before it moves — row count,
> column outputs, and downstream contracts."

### Step 4 — Phase 2: Plan review (~60s)

The skill emits a plan. Expect roughly:

- Extract `int_order_payment_methods` — the payment pivot
- Extract `int_customer_order_history` — RFM + tenure aggregations
- Extract `int_customer_first_last_orders` — first + most-recent order details
- Hoist `payment_methods`, `tenure_thresholds`, `monetary_thresholds` to `dbt_project.yml` vars
- Reduce `customer_order_summary` to a thin join over the three intermediates
- Preserve the current column list byte-for-byte

**Say "go" to approve.**

### Step 5 — Phase 3: Execute (~90s, mostly hands-off)

The skill writes ≤5 files (three ephemeral intermediates + rewritten
target + updated `dbt_project.yml`), appends the new model entries to
the existing `models/marts/schema.yml`, and goes straight to Phase 4.
No standalone compile step.

> "The intermediates are materialized as **ephemeral**, so they inline
> into the target model at compile time — no separate warehouse round
> trip to create them as views. And the skill skips the standalone
> compile step because any error will surface in Phase 4's build with
> the same clarity."

### Step 6 — Phase 4: Parity validation (~90s)

The skill runs **one** build (`build --model +customer_order_summary+`)
that exercises the target *and* its downstream, then runs an aggregate
SQL check (count / sum / min / max on `customer_lifetime_value`) against
the `_before` snapshot. If — and only if — that check disagrees, it
falls back to `data-parity` for a full column-level diff.

**Talking point:**
> "The safety net is a single aggregate query that catches row-count drift
> and value drift on the grain column. It's ~200ms. Full column-hash diff
> is available if we need it, but for a clean refactor it's overkill and
> costs a warehouse round trip we don't need."

### Step 7 — Phase 5: Static optimization signals (~30s)

The skill runs `sql-review` on the refactored SQL to surface remaining
anti-patterns. It filters out warnings that match the project's own
conventions (like `SELECT *` in import CTEs) so the "Next-step
optimizations" list stays signal, not noise.

### Step 8 — Walk the report (~60s — the main event)

The skill **displays the report inline in chat**. The report is *not*
saved to a file — persistence is not part of this skill.

Walk the sections in this order (this is what the report was redesigned
for):

1. **Bottleneck summary** (2–4 sentences at the top) — the plain-English
   diagnosis of what made the model painful. Read this out loud verbatim.
   This is what a data lead skims first.
2. **Outcome axes improved** — an 8-row table showing which qualities
   improved and *why*: Readability, Maintainability, Reusability,
   Performance, Cost, Governance / testability, Best-practice compliance,
   Semantic behavior preserved. Performance and Cost will show
   **"Not measured"** — call this out honestly and use it to lead into
   Step 9.
3. **Code-shape metrics** — the raw before/after numbers (lines, joins,
   CTEs, hardcoded literals). This is evidence for the axes above.
4. **Parity evidence** — row count matches, aggregate signature matches,
   build passed. This is the "we didn't break anything" section.
5. **Next-step optimizations** — surviving lint findings and things
   flagged but out of scope (e.g., `orders.sql` also duplicates the
   payment pivot; consolidating that was out of scope for this refactor).

Expected numbers (from the reference run):
- Lines: 218 → ~85 in target (~60% reduction)
- Joins: 8 → 3
- CTEs: 11 → 4
- Repeated hardcoded literals: 8 → 0 (hoisted to `dbt_project.yml` vars)
- Columns removed as unused: 0 (all outputs stay; downstream contract preserved)
- Full project build after refactor: all green, downstream (`customer_kpis`, `orders_enriched`) unaffected

Close with:

> "This report is the deliverable. It goes in the PR description, it goes
> in the team's #data-eng channel, and it explains which qualities got
> better — not just that lines went down."

### Step 9 — (Optional) warehouse benchmark on real query history (~3 min)

**This is the new final beat.** After displaying the report, the skill
asks: *"Would you like to run a warehouse benchmark now to measure real
runtime, bytes scanned, and credits — comparing the refactored model
against its historical query stats?"*

- **For a customer-facing demo where cost matters** → answer **yes**.
  The skill will ask which warehouse profile and how many days of history
  to compare, then:
  1. Read the **historical baseline** from
     `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` via `cost-report` (this is
     an *average* over N days — needs history because
     `ACCOUNT_USAGE` has ~45 min ingestion lag).
  2. Trigger one **fresh run** of the refactored model.
  3. Read the fresh run's runtime + bytes from
     `INFORMATION_SCHEMA.QUERY_HISTORY_BY_WAREHOUSE()` (near-realtime —
     visible within seconds).
  4. **Append** a warehouse-metrics block to the already-displayed
     report and flip the Performance and Cost rows in "Outcome axes
     improved" from "Not measured" to real Yes/No with numbers.

  **Framing to use with the audience:** *"Before is the average of the
  last 30 days — this model ran ~400 times, so the number is stable.
  After is a single fresh run of the refactored version, read seconds
  after it finished. Different sources, on purpose — Snowflake's
  ACCOUNT_USAGE has a 45-minute ingestion lag, so we can't use it for
  the fresh run."*

- **For a quick walkthrough or no-warehouse setup** → answer **no**.
  The static report already stands on its own.

- **Common gotcha:** if `cost-report` returns zero historical rows (the
  model has never run in prod, or `ACCOUNT_USAGE` grants are missing),
  the skill will stop and say so. It will NOT fabricate a "before"
  number from a single run of the old code. In that case, skip Step 9
  and rely on the static report.

### Step 10 — (Optional, 30s) show the diff

`git diff --stat` in the terminal. Audience sees:
- 4 new files in `models/intermediate/` (three int models + schema.yml)
- 1 rewritten `customer_order_summary.sql` (218 → ~85 lines)
- 1 updated `dbt_project.yml` (new vars + intermediate materialization)
- 1 updated `models/marts/schema.yml`

---

## Reset instructions (between demo runs)

```bash
git checkout .
git clean -fd models/intermediate/  # only if the skill created this dir
git status  # should be clean
```

If the skill left a `_before` sidecar table in Snowflake it did not clean
up, drop it:

```sql
DROP TABLE IF EXISTS <db>.<schema>.customer_order_summary_before;
```

---

## What to say if something goes wrong

| Symptom | Recovery |
|---|---|
| Skill can't find `dbt-analyze` | Confirm Altimate skills are enabled in Workspaces settings. Fall back to static-only mode. |
| `data-parity` fails on row count | This is the demo's best moment — say "this is why we do it". Show the diff, roll back, do not deploy. |
| Warehouse benchmark (Step 9) times out or errors | Skip it — the static report displayed in Step 8 already stands alone. |
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
