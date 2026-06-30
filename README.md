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

As most agentic programming frameworks, `skepticism` cornerstone are specifications: before the actual coding, the assistant will create a document defining what's to be done and how to verify its compliance. That's what the adversarial agents cling on to: how much adherence to the pre-existing spec the previous agent achieved. Using the skill `\skeptic:spec`, the agent will help the user define a human-readable document and find blind spots in the specification.

Once an specification is in place, `\skeptic:coding` will start a rigid process in which:
1. It reads the spec and understands it. A spec (from `\skeptic:spec` or other source) is required for this process.
2. It implements failing tests. Adversarial subagents are spawned to verify the usefulness, compliance and quality of those tests.
3. It implements the code until the tests are green. Adversarial subagents are once more spawned to verify quality and compliance of the code produced.
4. The result is reported to the user. If there was some hiccup or further iteration is needed, the agent may prompt the user to iterate back to any of the points before or clarify the spec.


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
