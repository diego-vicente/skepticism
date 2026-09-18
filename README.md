# `skepticism` - An agentic workflow for people that don't trust an AI agent


This repository contains an experimental version of an agentic workflow that I have been recently using for programming. It is based on a simple idea: **I don't trust an AI agent, but I trust several of them**. `skepticism` features an **adversarial workflow**, in which different subagents in isolation are spawned to review the previous' subagents work, its quality, and compliance to a spec.

Currently, `skepticism` is a plugin for [Claude Code](https://claude.com/claude-code).


## How to install

Installing the framework is as easy as running these two commands from a Claude Code conversation:

```
/plugin marketplace add https://tangled.org/diego.codes/skepticism/raw/main/.claude-plugin/marketplace.json
/plugin install skeptic@skepticism
```

Or, run these commands from your shell:

```shell
claude plugin marketplace add https://tangled.org/diego.codes/skepticism/raw/main/.claude-plugin/marketplace.json
claude plugin install skeptic@skepticism
```

That will automatically include the `skeptic` plugin, which contains all the following skills:

- **`/skeptic:spec`** — author or refine a specification on its own.
- **`/skeptic:coding`** — the full adversarial workflow: from a spec, defines the tests and then implements them.


## How to use

Like most agentic programming frameworks, `skepticism`'s cornerstone is the specification: before any coding, the assistant creates a document defining what's to be done and how to verify compliance. That's what the adversarial agents cling to — how well the previous agent adhered to the pre-existing spec. Using the `/skeptic:spec` skill, the agent helps you define a human-readable document and find blind spots in the specification.

Once a specification is in place, `/skeptic:coding` starts a rigid process in which:
1. It reads the spec and understands it. A spec (from `/skeptic:spec` or other source) is required for this process.
2. It implements failing tests. Adversarial subagents are spawned to verify the usefulness, compliance and quality of those tests.
3. It implements the code until the tests are green. Adversarial subagents are once more spawned to verify quality and compliance of the code produced.
4. The result is reported to the user. If there was some hiccup or further iteration is needed, the agent may prompt the user to iterate back to any of the points before or clarify the spec.

Two things the workflow will stop and ask you about, rather than deciding on your behalf:

- **Test cost.** When an acceptance criterion can't be tested both faithfully and cheaply — it needs a trained model, a seeded database, a new harness — the test author writes what fits your existing suite, and hands you the rest as a choice: build the scaffolding, accept a lower-fidelity mock, or defer it as a known gap. Deferred criteria are recorded and reported back at the end; the framework will happily leave a hole, but never a quiet one.
- **Commits.** It can commit after each phase (which is what makes re-reviewing only the delta possible), but it asks first and always works on a branch.


## It leaves no trace

`skepticism` is a way of working, not a dependency your project takes on. Nothing about it reaches the remote: no requirement IDs or process commentary in your code or tests, no framework references in commit messages, and no committed artifacts. Specs, coverage maps and run state all live under `.skepticism/`, which is excluded through `.git/info/exclude` — local to your clone, never pushed. Writing that exclusion into `.gitignore` would itself commit a reference to the framework, which rather defeats the point.

This is enforced, not just asked for: `leak-check` runs as part of the deterministic gate before any reviewer is spawned, and a project's own gate override can't switch it off. The cost of the trade is that the index of past runs is local to the machine you worked on.


## Contributing

The code is MIT licensed, so feel free to tune a local version or fork it. I am open to including new code and features if it fits my mental model, but this project is my daily driver so I may push back to include changes upstream. **If you would like to collaborate with a feature, please open an issue first**. All pull requests without previous discussions will be dropped.

```sh
# Clone the repo
git clone https://tangled.org/diego.codes/skepticism
cd skepticism

# Run Claude Code with your local checkout loaded as a plugin (session-only).
# This uses your working copy, so you test your edits — unlike `plugin install`,
# which clones the published version from the marketplace source.
claude --plugin-dir .
```

The plugin ships its own eval harness under `evals/` — deterministic script tests
plus adversarial behavioral scenarios that verify the workflow does what it
promises. Run the hermetic subset (no API needed) before sending a change:

```sh
bash evals/run.sh --ci
```

See `evals/README.md` for the behavioral and triggering tiers.
