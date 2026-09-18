# Demo — dbt Model Refactoring on Altimate Workspaces

**Duration:** 5–6 min core, +2 min optional warehouse benchmark
**Branch:** `dbt-model-refactoring-demo`
**Target model:** `customer_order_summary`

---

## Context — the story you tell

This is jaffle_shop, dbt's canonical demo project. On top of the clean
baseline (staging → `customers` / `orders`), the branch adds a realistic
mart layer with one deliberately problematic model:

- **`models/marts/customer_order_summary.sql`** — 218 lines. Someone
  built it six months ago and it grew every sprint. It has:
  - 8 joins in a single query, including a correlated-subquery pattern
    just to get "second order date"
  - An 11-CTE structure, one of them 50 lines mixing recency, frequency,
    monetary and tenure logic in one shot
  - The payment pivot re-implemented from `raw_payments` — logic already
    exists in `orders.sql`
  - Segment thresholds (tenure days, frequency counts, LTV bands)
    hardcoded as inline literals in 8 places
- **`models/marts/customer_kpis.sql`** and
  **`models/marts/orders_enriched.sql`** — two downstream models that
  `ref` the monster. Any change has to keep both working.
- **`.claude/skills/refactor-dbt-with-report/SKILL.md`** — a custom skill
  that orchestrates Altimate's built-in dbt skills (`dbt-analyze`,
  `dbt-develop`, `data-parity`, `cost-report`, `query-optimize`,
  `sql-review`) into a repeatable refactor flow with a quantified report.

**One-line pitch for the room:**
> *"250-line model, two dashboards depend on it, nobody wants to touch
> it as it has a lot of random added code, performance also gets impacted because of such code pieces. We're going to fix it using our custom skills and Altimate Code harness and prove nothing broke."*

**What the demo proves:**
1. Refactoring a real dbt model can be **fast** (minutes, not days).
2. It can be **safe** — row count and value parity is a hard gate.
3. The output isn't just cleaner code — it's a **quantified report** that
   names which qualities improved (readability, maintainability,
   governance, best-practice compliance) with before/after evidence.

**What we do NOT claim without warehouse mode:** performance or cost
improvements. Those need the optional Phase 7 benchmark.

---

## DEMO STEPS:

```bash
git checkout dbt-model-refactoring-demo
git pull
git status                                         # working tree clean
```

Confirm in Workspaces:
1. Repo opened on branch `dbt-model-refactoring-demo`.
2. Setup the dbt profiles.yml with your Snowflake credentials ` ~/.dbt/profiles.yml → jaffle_shop.target: dev` and make sure it connects (`dbt debug`).
3. Make sure you have a workspace linked with skill : `refactor-dbt-with-report` in `SKILL.md` format. For this take the skill from repo `jaffle-shop-core-demo/refactor-dbt-with-report_SKILL.md` and attach it to your workspace. Once done, delete this skill from your repo to avoid confusion.
4. If a stale sidecar snapshot exists from a prior run, drop it:
   ```sql
   DROP TABLE IF EXISTS anas.js_dbt.customer_order_summary_before;
   ```
5. Once you have workspace connected, go ahead with your prompt:
In Workspaces:
```
Refactor customer_order_summary model.
```
---

## Detailed Execution steps(not actually required for demo)

### 1. Open the monster (~30s)

Open `models/marts/customer_order_summary.sql`. Scroll top to bottom.
Point out lines 71–120 (the 50-line CTE), lines 108–115 (the
correlated-subquery self-join for `second_order_date`), and lines 90–107
(the hardcoded thresholds). Then open `customer_kpis.sql` and
`orders_enriched.sql` — one line each showing `ref('customer_order_summary')`.

### 2. Invoke the skill (~10s)

In Workspaces:

```
Refactor customer_order_summary using the refactor-dbt-with-report skill.
```

Answer the **two** questions the skill asks:

| Question | Answer |
|---|---|
| Target model? | `customer_order_summary` |
| Parity strictness? | Row-count + spot-check hash (default) |

Warehouse benchmarking is NOT asked here — it's the final optional step.

### 3. Watch it work (~4 min, hands-off)

The skill runs six phases end-to-end. Narrate at the transitions:

- **Baseline (Phase 1)** — static metrics, `dbt-analyze` for downstream
  impact, one baseline snapshot on the warehouse.
  > *"It's mapping the two downstream consumers and freezing what
  > 'correct' looks like before it moves."*
- **Plan (Phase 2)** — plan appears; **say "go"** to approve.
- **Execute (Phase 3)** — file writes only, no per-file compile.
  > *"Intermediates are ephemeral — they inline into the target at
  > compile time, so no extra warehouse round trips."*
- **Parity (Phase 4)** — one build of target + downstream, one aggregate
  SQL check against the baseline snapshot.
  > *"This is the safety gate. Row count and aggregate signature have
  > to match, or the run stops."*
- **Static signals (Phase 5)** — `sql-review` on the cleaner SQL.
- **Report (Phase 6)** — displayed inline in chat.

### 4. Walk the report (~60s — the payoff)

Read the sections in order:

1. **Bottleneck summary** (2–4 sentences) — the plain-English diagnosis.
   Read aloud verbatim.
2. **Outcome axes improved** — 8 rows. Call attention to Readability,
   Maintainability, Reusability, Governance, Best-practice compliance
   moving to "Yes" with a concrete why. Performance and Cost will show
   **"Not measured"** — flag this and use it to segue into Step 5.
3. **Code-shape metrics** — before/after numbers backing the axes above.
   Expected: 218 → ~85 lines, 8 → 3 joins, 11 → 4 CTEs, 8 → 0 repeated
   literals.
4. **Parity evidence** — row count and aggregate signature identical,
   downstream consumers still passing.
5. **Next-step optimizations** — items the skill found but didn't apply.

Close with:
> *"This report goes in the PR description. It doesn't just show that
> lines went down — it names which qualities got better, with evidence."*

### 5. Warehouse benchmark (~2 min, optional)

After the report, the skill asks: *"Would you like to run a warehouse
benchmark now?"*

- **If demoing cost impact → say yes.** The skill will pull the
  historical baseline from `ACCOUNT_USAGE.QUERY_HISTORY` via
  `cost-report`, trigger a fresh run of the refactored model, read the
  fresh run's runtime + bytes from `INFORMATION_SCHEMA` (~seconds), then
  append a warehouse-metrics block and flip Performance/Cost in the
  outcome axes to real numbers.
  - **Say this out loud:** *"Before is the 30-day average — this model
    ran many times, so the number is stable. After is one fresh run,
    read seconds after it finished. Different sources on purpose because
    Snowflake's `ACCOUNT_USAGE` has 45 min ingestion lag."*
- **If not → say no.** The static report already stands alone.
- **If `cost-report` reports zero historical rows**, the skill stops.
  Move on — don't force it.

### 6. (Optional) Show the diff (~15s)

```bash
git diff --stat
```

Audience sees ~5 files touched: 3 ephemeral intermediates in
`models/intermediate/`, rewritten `customer_order_summary.sql`, updated
`dbt_project.yml` (vars), updated `models/marts/schema.yml`.

---

## Reset between runs

```bash
git checkout .
git clean -fd models/intermediate/
git status                                         # clean

# In Snowflake:
DROP TABLE IF EXISTS anas.js_dbt.customer_order_summary_before;
```

---

## If something breaks

| Symptom | Recovery |
|---|---|
| Skill can't find an Altimate sub-skill | Check Workspaces settings; the skill needs `dbt-analyze`, `data-parity`, `cost-report`, `query-optimize`, `sql-review` loaded. |
| Phase 4 parity fails | This means the refactor changed output. Skill stops automatically. Read the mismatch out loud — this is the safety gate doing its job. Do not deploy; investigate. |
| Phase 4 build fails on jinja/ref error | Skill surfaces the exact error. Fix the one line, rerun the skill from Phase 3. |
| Warehouse benchmark (Step 5) times out or errors | Skip it. The static report is the deliverable. |
| Demo running long | Skip Step 5 (the warehouse benchmark) — that alone saves 2 min. |
