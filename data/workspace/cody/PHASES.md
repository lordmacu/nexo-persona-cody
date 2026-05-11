# Phases

This is a starter `PHASES.md`. Replace it with your project's
real phases before asking Cody about "what's pending?". Cody
parses sub-phases by the `#### <id> — <title>   <status>`
pattern; the status marker is `⬜` pending, `🔄` in progress,
`✅` done.

## Phase 1 — Bootstrap

Initial setup work for your project.

#### 1.1 — First sub-phase   ⬜

Replace this with your project's first work item. A good first
sub-phase is small, has a clear acceptance criterion, and can
be shipped in one Claude Code dispatch (~1-4 h work).

When you're ready, ask Cody:

```
cody> dispatch 1.1
```

It will call `program_phase phase_id=1.1` and report a goal_id
you can `agent_status` against.
