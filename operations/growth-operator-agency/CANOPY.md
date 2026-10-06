# Canopy Operation Notes

This is a ready-to-run Canopy operation copied from `templates/growth-operator-agency`.

Before using it for a real creator or business:

1. Fill in `company.yaml` with real business context.
2. Review `SYSTEM.md`, `INVARIANTS.md`, and `ENCODING.md`.
3. Use `agents/growth-ceo.md` as the default orchestrator.
4. Invoke skills from `skills/*/SKILL.md`; the Claude shims live in `.claude/commands/`.
5. Keep client/business secrets out of git.

For a new client or brand, copy the template instead of editing this base operation directly:

```bash
cp -R templates/growth-operator-agency operations/<creator-or-brand-name>
```
