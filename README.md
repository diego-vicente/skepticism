# skepticism

An adversarial, spec-first verification workflow for [Claude Code](https://claude.com/claude-code).

## How to install

```
/plugin marketplace add https://tangled.org/diego.codes/skepticism
/plugin install skeptic@skepticism
```

The repo and marketplace are named `skepticism`; the installed plugin is
`skeptic`. After installing, its skills are available as:

- **`/skeptic:coding`** — the full adversarial workflow (spec → failing tests →
  review tests → implement → review implementation → report).
- **`/skeptic:spec`** — author or refine a specification on its own.
