---
id: training/rule/compile-on-model-change
scope: project
created: 2026-03-25T13:14:50.187Z
updated: 2026-03-25T20:10:53.248Z
tags: ["training","rule"]
---

<!-- training
kind: rule
source: user instruction
applied: 9
-->
Always run `altimate-dbt compile --model <name>` immediately after creating or modifying any dbt model. This must happen before `altimate-dbt build` — compile catches Jinja/syntax errors fast without hitting the warehouse.
