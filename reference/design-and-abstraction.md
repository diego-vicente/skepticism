# Design & abstraction (situational reference)

Consult this when you are shaping modules, types, interfaces, or class
hierarchies — i.e. making structural decisions, not just writing a function. The
always-on essentials live in `coding-essentials.md`; this expands the parts that
only apply when there's real design to do.

The throughline: **earn abstraction, don't anticipate it.** Generated code fails
far more often by over-abstracting than under-abstracting.

## Abstraction — earn it
- **Rule of three.** Don't abstract a pattern until you've seen it ~3 times.
  Premature abstraction is harder to undo than a little duplication.
- **DRY is about knowledge, not characters.** Deduplicate a *decision/rule* that
  genuinely appears in several places. Do NOT merge two pieces of code that only
  *look* similar but represent different concepts — that coupling hurts later
  when they need to change independently.
- **Composition over inheritance.** Use inheritance only for genuine is-a
  hierarchies; default to composing small pieces.

## SOLID, in moderation
- Single-responsibility and dependency-inversion usually earn their keep.
- But do NOT manufacture interfaces, factories, or layers for code that has
  exactly one implementation. An interface with one implementer is not
  "open/closed" — it's the over-abstraction trap. Add the seam when the second
  case actually arrives.

## Deep modules, simple interfaces (Ousterhout)
- A good module hides substantial complexity behind a small, clear interface.
  Value = functionality ÷ interface complexity.
- Be suspicious of **shallow modules** — a class/function whose interface is
  about as complicated as its body earns nothing and just adds a hop.
- **Pull complexity downward.** Better for the *implementer* of a module to
  absorb a little complexity than to push it onto every *caller*. Make the
  common case easy from the outside.
- This is why "many tiny functions" can be a net loss: it multiplies shallow
  interfaces. Prefer fewer, deeper units.

## Make illegal states unrepresentable
- Encode invariants in types/data structures so bad states can't be constructed,
  instead of validating them at every use site.
- **Parse, don't validate:** turn untrusted input into a trusted shape once at
  the boundary, then rely on the type inside rather than re-checking everywhere.
- Prefer enums/sum-types/smart constructors over stringly-typed flags and
  boolean soup.

## Coupling & cohesion
- High cohesion (a unit does one thing) and low coupling (few, well-defined
  dependencies) are the real readability/maintainability drivers — more than any
  line-count rule. If you can't describe a module's job in one sentence without
  "and", its responsibility is split.
