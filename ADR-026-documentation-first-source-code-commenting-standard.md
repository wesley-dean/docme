# ADR-026: Documentation-First Source Code Commenting Standard for AI-Assisted Development

Date: 2025-12-23

## Status

Accepted

## Intent and Scope

This Architecture Decision Record defines a **documentation-first,
narrative-heavy source code commenting standard** intended for use in projects
that employ AI/LLM-assisted code generation or modification.

This ADR is deliberately **project-agnostic**.  It does not assume the presence of
other Architecture Decision Records, specific architectures, or particular
tooling.  It is intended to be reusable across projects, teams, and
organizations.

The standard applies both to:
- newly written code, and
- existing code that is being documented, refactored, or reviewed with AI.

This ADR is intentionally verbose.  Verbosity is a design choice, not an accident.

<!--
Preamble (Optional Context)

This standard is written in service of *fewer incidents*.

Incidents are often rooted not in missing features, but in misunderstanding:
code that behaves differently than a maintainer expects, safeguards that are
misread under pressure, or intent that has decayed over time.  Treating
documentation as a first-class artifact reduces these risks by lowering cognitive
load at the moment of review and decision.

The Knowledge -> Discernment -> Action model is implicitly supported here:
documentation provides the knowledge required to reason clearly, discernment
enables sound judgment under stress, and informed action reduces the likelihood
of preventable incidents.

This preamble is optional and may be removed in projects where such framing is
unhelpful.
-->

## Core Premise

Source code is read far more often than it is written.

It is read:
- by junior developers,
- by tired developers,
- by stressed developers during incidents,
- by maintainers returning to code months or years later,
- and increasingly, by reviewers validating AI-generated changes.

This ADR assumes a human reader who is:
- short on time,
- under cognitive load,
- and not immersed in the original author’s mental context.

The goal of this standard is not elegance.
The goal is **comprehension under stress**.

## The Problem This ADR Addresses

AI/LLM-generated code frequently exhibits the following failure patterns:

- Minimal or missing comments
- Comments that restate syntax instead of explaining intent
- Loss of “why” during refactors
- Destructive rewrites when asked to “add documentation”
- Stubbed or replaced function bodies
- Silent removal of edge-case handling
- Overconfident tone masking incorrect behavior

These problems are not hypothetical.  They occur regularly in real workflows.

This ADR exists to counteract those tendencies explicitly.

## Guiding Principle

**Documentation is architecture.**

Comments and docstrings are not decorative.
They are part of the system’s safety, maintainability, and incident-prevention
surface.

This ADR adopts an intentionally extreme posture:

> Target approximately two lines of meaningful documentation
> for every line of executable code.

This ratio is a guiding norm, not a rigid metric.
The standard is met when a reader can understand both **what** the code does
and **why it exists** without reverse-engineering behavior.

## Human-Centered Design Perspective

This ADR centers the experience of a tired or stressed human.

That perspective drives several deliberate choices:
- Redundancy is allowed.
- Obvious facts may be restated if they reduce cognitive load.
- Trade-offs are explained even if they seem “obvious” to experts.
- Failure modes are described explicitly.
- Non-goals are documented to prevent false assumptions.

Clarity is prioritized over cleverness.

## Documentation Density and Narrative Style

Code should read like a book written in plain language.

This means:
- complete sentences,
- consistent structure,
- and an explanatory tone.

Documentation SHOULD explain:
- motivation,
- constraints,
- safety posture,
- and consequences.

Documentation SHOULD NOT:
- merely label code blocks,
- rely on the reader to infer intent,
- or assume prior familiarity with the system.

## Mandatory Documentation Targets

The following MUST be documented in all applicable languages:

- File/module headers
- Public classes
- Public functions and methods
- Non-trivial private helpers
- Configuration variables (environment variables, flags, config keys)
- Policy-defining constants
- Non-obvious data structures
- Safety mechanisms (dry-run modes, validation, guards)
- Edge cases and exceptional behavior

Undocumented behavior is considered a defect.

## Required Documentation Content

Where applicable, documentation SHOULD include:

- Purpose and scope
- Background and motivation
- Inputs and outputs (types, shapes, semantics)
- Preconditions and assumptions
- Invariants that must always hold
- Failure modes and error handling
- Security or privacy considerations
- Configuration precedence and defaults
- Non-goals and excluded behaviors
- Concrete examples that resemble real usage

Not every section applies everywhere, but omissions should be intentional.

## Structured Commenting (Doxygen-Style)

This ADR adopts a **Doxygen-style conceptual structure** across languages.

Exact syntax varies by language, but the following concepts should be present:

- @brief
- @details
- @param / inputs
- @retval / return semantics
- @var (for configuration and globals)
- @par Examples
- @code blocks

Consistency matters more than syntax perfection.

## Non-Destructive AI-Assisted Documentation Updates

This section is critical.

When using an AI/LLM to **add or improve documentation in existing files**,
the following rules are mandatory.

### Known Failure Mode

LLMs often:
- rewrite entire files when only comments were requested,
- replace complex logic with stubs,
- remove edge-case handling,
- or silently alter control flow.

These outcomes increase incident risk and are unacceptable.

### Mandatory Rules

1. **Comment-only intent must be honored**
   - If the request is “add documentation,” executable code must remain unchanged.

2. **Small, bounded edits**
   - Work on one function, class, or section at a time.
   - Avoid whole-file rewrites unless explicitly requested.

3. **Preserve code verbatim**
   - Function bodies must not be modified.
   - Control flow must not change.
   - Imports, constants, and ordering must be preserved.

4. **Fail safely**
   - If preservation cannot be guaranteed, the assistant must stop and ask for guidance.

5. **Verification**
   - Use diffs, checksums, or tooling to confirm only comments changed.
   - Run linters and tests where feasible.

Destructive “helpfulness” invalidates the change.

## Teaching and Onboarding Value

This documentation style serves as:
- onboarding material,
- operational runbooks embedded in code,
- and a guardrail against accidental misuse.

Well-documented code reduces reliance on tribal knowledge
and makes review more objective.

## Trade-offs and Costs

This approach has real costs:

- Larger files
- More verbose diffs
- Increased documentation maintenance effort
- Slower initial development

These costs are accepted because the alternative
is misunderstanding at scale.

## Applicability Beyond New Code

This ADR explicitly supports:
- retrofitting documentation onto legacy code,
- reviewing AI-generated patches,
- and incrementally improving clarity without refactoring logic.

It is intended to be used as instruction when an LLM is told:
“Update the documentation for this file.”

## Ambiguity Detection and Explicit Marking

Ambiguity is expected in real-world codebases, especially in:
- legacy systems,
- code written under time pressure,
- code with decayed context,
- or code partially or wholly generated by an AI/LLM.

When the purpose, usage, constraints, or rationale of a code block cannot be
determined with reasonable confidence, **the ambiguity must be made explicit**.

### Do Not Guess Intent

Guessing intent is more harmful than leaving intent undocumented.

When documentation is added or updated using AI assistance, the assistant MUST
NOT:
- invent a rationale,
- speculate about design intent,
- or retroactively justify behavior without evidence.

Plausible-sounding explanations that are incorrect increase incident risk.

### Required Behavior When Ambiguity Is Detected

When an ambiguous construct is encountered and its intent cannot be confidently
established from context, the following MUST be done:

- Add a `@TODO` comment at the relevant location.
- Clearly state *what is unclear*, using plain, neutral language.
- Do not propose a solution or explanation unless explicitly requested.

The goal is to surface uncertainty for human review, not to resolve it prematurely.

### Examples of Acceptable `@TODO` Comments

- `@TODO Explain why this method is useful`
- `@TODO Clarify when this function should be called`
- `@TODO Document expected invariants for this data structure`
- `@TODO Confirm whether this behavior is intentional or historical`
- `@TODO Explain why this special case exists`

These comments should be specific, factual, and non-judgmental.

### Review and Stewardship Value

Explicitly marking ambiguity:
- prevents false confidence,
- guides reviewer attention,
- enables intentional follow-up,
- and supports safe, incremental improvement.

A visible `@TODO` is not a failure.
It is an honest signal that human judgment is required.

### Relationship to Non-Destructive Documentation Updates

When documenting existing code, encountering ambiguity is a valid stopping
condition.

If intent cannot be established without modifying code behavior or making
assumptions, the assistant should:
- add a `@TODO` comment,
- preserve the code exactly,
- and defer resolution to a human maintainer.

This behavior is preferred to speculative documentation.

## Addendum A: Shell Script Example

```bash
###############################################################################
# @file example.bash
# @brief Performs a privileged maintenance task safely.
#
# @details
# This script exists to solve a specific operational problem while avoiding
# unsafe defaults.  It favors explicit configuration and fails closed when
# required inputs are missing.
#
# @var CONFIG_PATH
# Path to the configuration file.  Later values override earlier ones.
###############################################################################
```

## Addendum B: Python Example

```python
def example_function(value, dry_run=True):
    """
    @brief Perform a controlled operation.

    @details
    This function exists to make an otherwise risky operation explicit and
    reviewable.  Dry-run mode is the default to reduce accidental impact.

    @param value
        The input value to operate on.

    @param dry_run
        When True, no changes are made.

    @retval dict
        A structured summary of actions taken or proposed.

    @par Examples
    @code
    result = example_function(42, dry_run=True)
    print(result)
    @endcode
    """
```

## Summary

This ADR establishes a documentation-first standard that treats comments
as a core safety and comprehension mechanism.

It is intentionally verbose.
It is intentionally redundant.
It is intentionally human-centered.

In AI-assisted development, this standard supports
Knowledge → Discernment → Action by providing clarity before judgment
and judgment before change — in service of **fewer incidents**.
