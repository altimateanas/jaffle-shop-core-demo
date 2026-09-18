# Demo — Jira Ticket → Merge-Ready dbt PR

**Total budget: 5 minutes.** Hard cap. If you run over, drop Step 5.
**Branch:** `dbt-jira-use-case`
**Ticket:** `AI-4823`
**Skill:** `dbt-jira-ticket-to-merge-ready-pr`

## Context — your prep, NOT your script

*Read this before you demo. Do not read it out loud during the 5-min
budget. The only lines to say out loud are marked in italics in the
DEMO STEPS section.*

**The gap this demo closes.** Every AI code assistant can generate SQL.
None of them can prove the change is safe before asking a human to
review it. This demo is about that gap.

**The mechanism.** A PM's Jira ticket becomes a merge-ready dbt PR.
Every step that could produce an unsafe outcome delegates to an
Altimate engine: lineage grounds the target model, convention scan
enforces house style, equivalence proves pre-existing columns are
byte-identical, blast radius pulls downstream owners, PII scan runs
on the diff, and a final review phase re-invokes the same engines
against the PR diff and posts an advisory verdict as a comment.

**One-line pitch (say only if asked "what am I looking at?"):**
> *"AI you can trust with production dbt — because Altimate engines
> fence every step, including the final review."*

**What we do NOT claim:** the PR is auto-merged. Reviewer posts a
verdict; a human clicks merge. That's the point.

---

## Prerequisites (do these once, before the demo)

1. **Repo on branch `dbt-jira-use-case`, working tree clean.**
   ```bash
   git checkout dbt-jira-use-case
   git pull
   git status
   ```
2. **dbt profile connects.** `~/.dbt/profiles.yml → jaffle_shop.target: dev`, then `dbt debug` green.
3. **Workspace has this skill loaded:**
   - name of skill->`dbt-jira-ticket-to-merge-ready-pr`, SKILL.md content->(see `jaffle-shop-core-demo/dbt-jira-ticket-to-merge-ready-pr_SKILL.md`)
4. **Altimate-code tools available in workspace:** lineage (upstream + downstream + column), equivalence, PII scan, cost estimate, validate.
5. **Atlassian MCP is connected** and can reach the Jira site hosting ` for example AI-4823`. If OAuth prompt appears mid-demo, you lose ~20s — approve it ahead of time.
6. **`AI-4823` exists in Jira** with the exact description below (see "Ticket content"). Include acceptance criteria verbatim — the skill parses them.
7. **`gh` CLI is authenticated** to the repo (`gh auth status`).
8. **If a stale sidecar snapshot exists from a prior run, drop it:**
   ```sql
   DROP TABLE IF EXISTS anas.js_dbt.customers_before_ai4823;
   ```
9. In Workspaces give prompt and run the workflow:

```
Implement JIRA ticket <your JIRA ticket id>.
```
---

## Ticket content — paste this into Jira as maybe in `AI-4823`

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
> - Downstream models + exposures still build; owners tagged in the PR.
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

> *"Prose from a PM. The ticket doesn't name a model. Watch the skill
> figure that out, make the change, and prove nothing else moved."*

Do NOT open `customers.sql` — save the file reveal for the diff step.

### 2. Invoke the skill (0:05)

In Workspaces:

```
Implement AI-4823.
```

That's it. No model name, no column spec, no test hints — the ticket
carries the intent, the skill does the rest.

### 3. Watch it work (2:30, hands-off — narrate 4 beats only)

The skill runs 10 phases internally. **Do not narrate all of them** —
you'll lose the room. Stay silent during transitions and speak only at
these four moments:

| When | Beat (30s each, max) | Say |
|---|---|---|
| ~0:30 in — after lineage picks the model | **Grounding** | *"The ticket didn't name a model. Lineage picked `customers` — it's upstream of the marts, so that's where a customer-level dimension belongs."* |
| ~1:00 in — after convention scan | **House style** | *"It found the existing `payment_methods` list in `orders.sql` and promoted it to a project var. It didn't re-hardcode — it matched house style."* |
| ~1:45 in — when equivalence runs | **Safety gate** (the payoff — pause on this one) | *"This is the safety gate. Every pre-existing column, byte-identical. If any of them moved, the skill stops here and no PR gets opened. This is what makes it different from every other AI code assistant."* |
| ~2:20 in — after PR opens and review runs | **Independent review** | *"And it just reviewed its own PR — same Altimate engines, re-run against the PR diff. Advisory verdict, posted as a comment. Not the model grading itself; the engines re-run."* |

Everything else — Atlassian fetch, intent extraction, blast radius,
PII scan, cost delta — **runs silently.** They show up in the PR body;
that's where you'll walk them.

### 4. Walk the PR (1:15 — the payoff)

Open the PR in a browser tab. Do it in this order:

1. **PR body — "Safety evidence" section** (~30s). Point at:
   - Equivalence: row count + N columns byte-identical ✅
   - Blast radius: owner-grouped downstream list
   - PII: clean
   - Convention reuse: `payment_methods` promoted
   > *"Every claim in this body is an engine output, not a paragraph."*

2. **Owner tags** (~10s). Point at `@marketing-analytics`,
   `@finance-analytics`, `@analytics-engineering`.
   > *"Owners pulled from `meta.owner` and exposure `owner.email` —
   > nobody had to remember to tag them."*

3. **Automated review comment** (~30s). Scroll to it.
   > *"Verdict is APPROVE. But look at the caveat — 'human still owns
   > the merge decision.' The skill never auto-approves. That's the
   > line we don't cross."*

### 5. Diff + close (0:30)

```bash
git diff --stat main..HEAD
```

Expected: 4 files touched. Zero deletions from `customers.sql`.

> *"Four files, all additive. Zero lines deleted from the target.
> Ticket said no refactor — skill obeyed. Two minutes ago this was a
> paragraph from a PM. Now it's a PR with an equivalence proof, a
> blast radius, a PII scan, and an independent review — linked back
> to the ticket. That's AI you can trust with production dbt."*

---

## Optional — the "bad path" companion (`AI-4824`)

Skip if tight on time. Powerful if you have the extra minute — because
it shows the safety gate **refusing** to open a PR.

**Ticket to create:** `AI-4824` — *"Fix the value-segment cutoffs on
`customer_lifetime_summary` — the `mid_value` band should start at 15,
not 20."*

Run:
```
Implement AI-4824.
```

The skill will produce a valid-looking one-line change to
`customer_lifetime_summary.sql`. **Phase 7 (equivalence) fails** —
customers in the 15-19 LTV band flip segments.

- The skill **stops before opening a PR**.
- Chat shows the mismatch table.
- Say: *"Ticket said 'fix,' but equivalence saw N customers change
  segment. That's a semantic change, not a bugfix. The skill won't
  open a PR against a fence like that — a human has to make the call
  and add a migration note."*

Then optionally re-run mentioning `--allow-semantic-change` (or add a
Jira comment saying "intentional, add migration note") to show the
skill respecting an explicit override.

---

## Reset between runs

```bash
git checkout .
git checkout dbt-jira-use-case
git status                                         # clean

# In GitHub, close (don't merge) the demo PR:
gh pr close <PR#> --delete-branch

# In Jira, revert AI-4823 to "To Do" and clear comments the skill added.

# In Snowflake:
DROP TABLE IF EXISTS anas.js_dbt.customers_before_ai4823;
```

---

## If something breaks

| Symptom | Recovery |
|---|---|
| Atlassian MCP prompts for OAuth mid-demo | Approve in browser, re-run `Implement AI-4823`. Costs ~20s. |
| Skill picks `customer_lifetime_summary` instead of `customers` | Lineage direction flipped. Interrupt: *"Lineage flipped upstream/downstream — moving on."* Re-run. |
| Phase 7 equivalence fails on `AI-4823` (should pass) | The additive change wasn't actually additive. Read the mismatch out loud — this is the gate doing its job. Do not open the PR. Investigate offline. |
| `gh pr create` fails on auth | Run `gh auth status` in a side terminal, re-auth if needed. |
| Phase 10 reviewer engine call fails | Verdict comment still posts with `[engine unavailable]` markers per missing signal. Acceptable in demo — narrate as "reviewer degrades gracefully, human review still gates merge." |
| Demo running long | Skip Step 5 (diff walkthrough) and the "bad path" section. Step 4 (PR walkthrough with the review verdict) is the payoff. |

---

## What lives in this branch

- `.claude/skills/dbt-jira-ticket-to-merge-ready-pr/SKILL.md` — the skill definition
- `DEMO_SCRIPT.md` — this file
- `models/marts/customer_lifetime_summary.sql` — downstream mart (blast-radius target)
- `models/marts/orders_enriched.sql` — downstream mart (blast-radius target)
- `models/marts/schema.yml` — marts docs + exposures + owner metadata
- All jaffle-shop baseline models from `main`, unchanged

The skill is the deliverable. Everything else is the stage.
