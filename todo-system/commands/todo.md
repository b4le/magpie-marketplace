---
allowed-tools:
  - Skill
description: "Manage todos: add, review, or roadmap"
arguments:
  - name: subcommand
    description: "Sub-command: add <title>, review, or roadmap"
    required: false
---

Parse the argument provided after `/todo`:

- Extract the first word as the sub-command (`add`, `review`, or `roadmap`)
- Everything after the sub-command is additional context

Then route:

1. **`add`** — Invoke the `todo-manage` skill with the remaining text as the todo title.
2. **`review`** — Invoke the `todo-review` skill to show a status overview.
3. **`roadmap`** — Invoke the `todo-review` skill with args `roadmap` to show the full roadmap with stats.
4. **No argument or unrecognised sub-command** — Output this help block and stop:

```
/todo add <title>  — Add a new todo item
/todo review       — Show todo status overview
/todo roadmap      — Show full roadmap with stats
```
