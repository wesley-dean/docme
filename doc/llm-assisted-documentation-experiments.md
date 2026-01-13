# LLM-Assisted Documentation Experiments: Findings and Design Conclusions

## Purpose and Scope

This document captures the empirical findings, constraints, and design conclusions from an extended series of experiments evaluating large language models (LLMs) for *documentation-only source code transformation* under a strict, ADR-driven contract.

The goal is explicitly *institutional memory*: to preserve why certain architectural and tooling decisions were made, so they do not need to be rediscovered or re-litigated in the future.

This is **not** an Architecture Decision Record (ADR).  However, it intentionally mirrors the depth, rigor, and epistemic discipline of ADR-000 (Capability Scope, Epistemic Honesty, and Separation of Concerns), and should be read as a companion research artifact grounded in those principles.

The findings below are based on repeated, hands-on experimentation across multiple models, runtimes, hardware configurations, and prompt refinements.

## Problem Statement

The problem under investigation was narrowly defined:

- Given an existing source code file
- Given a documentation standard expressed as an ADR (ADR-026)
- Can an LLM be reliably used to:
  - Update **documentation comments only**
  - Preserve all executable code byte-for-byte
  - Achieve *complete coverage* (file header, functions, configuration variables)
  - Return the *entire revised file*, with no extra text

This is a *source-to-source transformation* problem, not a generative one.

Success criteria were intentionally strict, because the output is intended to be consumed programmatically and potentially applied automatically.

## Prompt Viability

A central question was whether the prompt itself was fundamentally flawed, ambiguous, or underspecified.

This question has been conclusively answered.

### GPT-5.2 as a Proof of Possibility

When run against GPT-5.2:

- The prompt was followed precisely
- All required documentation targets were annotated
- Only comments were modified
- The entire file was returned
- No extraneous commentary, formatting, or explanation was added

This outcome establishes a critical fact:

> **The prompt is semantically correct and sufficient to express the desired transformation.**

Any failures observed elsewhere are therefore attributable to *model capability, training focus, or runtime constraints*, not to prompt ambiguity.

## Model Class Behaviors

### GPT-5.2

- Behaves as an authoritative, tool-like transformer
- Performs systematic, exhaustive passes over the file
- Correctly balances strict constraints with coverage requirements

This model represents the reference behavior.

### GPT-4o-mini

- Correctly understands constraints
- Exhibits strong *conservatism*
- Tends to make minimal, low-risk changes
- Commonly updates only the file header and stops

This is not a misunderstanding; it is a risk-avoidance strategy under strict rules.

### Local Models via Ollama (General)

Across multiple local models, a consistent pattern emerged:

- Partial compliance with intent
- Frequent early stopping
- Incomplete coverage (functions and variables often undocumented)
- Formatting reflexes (Markdown code fencing)
- Sensitivity to output token limits

These behaviors are not random; they reflect training priorities.

Local models are primarily optimized for *human-facing interaction and examples*, not for CI/CD-style source transformations.

## Specific Local Model Observations

### CodeGemma (7B)

- Frequently switches task identity
- May output example code instead of transforming input
- In some cases, changed the language entirely (e.g., shell → Python)
- Poor fit for this use case

**Conclusion:** unsuitable for documentation-only refactoring.

### Qwen2.5-Coder (7B)

- Correctly applies documentation logic
- Respects “comments only” constraints
- Stays in the correct language
- Suffers from:
  - Markdown fencing
  - Output truncation at default limits
  - Occasional early stopping

With sufficient output budget and external enforcement, this model is usable.

### Llama 3.x (local)

- Reliably returns the full file
- Often limits changes to the file header
- Avoids deeper edits under strict constraints

This mirrors GPT-4o-mini’s conservative strategy.

## Formatting Artifacts: Code Fencing

Markdown code fencing (```…```) emerged as a universal issue across local models.

Key conclusions:

- Fencing is a *presentation reflex*, not a semantic failure
- It persists even when explicitly forbidden in the prompt
- It does **not** correlate with incorrect documentation logic

The correct architectural response is **mechanical sanitization**, not further prompt refinement.

This issue is considered solved via post-processing.

## Output Truncation and Early Termination

Several models returned only the top portion of files, especially for files >100 lines.

Root cause:

- Default output token limits are insufficient for full-file regeneration
- Models terminate silently when limits are reached

Mitigations:

- Explicitly raise output token limits (`num_predict`, `max_tokens`)
- Reject outputs that are significantly shorter than the original
- Prefer diff-based output formats for local models when feasible

## Hardware Constraints and Memory

### 32 GB RAM

- Severely limits usable model size
- Constrains context and output budgets
- Increases likelihood of conservative or partial behavior

32 GB is workable only for small models with strict external enforcement.

### 64 GB RAM

- Enables 13B–16B class models
- Significantly improves coverage reliability
- Reduces early stopping behavior

This represents the first *productive* tier for local experimentation in this domain.

### 128 GB RAM

- Enables 30B–70B class models
- Allows sustained attention across complex, multi-part constraints
- Produces behavior closer to GPT-5.2 in terms of coverage

Even at this level, formatting artifacts remain, but semantic correctness improves substantially.

## Enforcement vs Trust

A critical architectural conclusion emerged:

> **LLMs cannot be treated as rule enforcers.  They must be treated as proposal generators.**

Correctness must be established by tooling:

- Sanitizing output
- Rejecting truncated results
- Verifying non-comment lines are unchanged
- Checking documentation coverage heuristics

This design aligns directly with the principles articulated in ADR-000 regarding epistemic honesty and separation of concerns.

## Final Conclusions

1. The prompt works as intended.
2. GPT-5.2 demonstrates authoritative compliance.
3. Local models exhibit predictable, explainable limitations.
4. Hardware capacity materially affects coverage behavior.
5. Formatting issues are orthogonal and solvable.
6. External enforcement is mandatory for safety.

The resulting system design is deliberate, principled, and justified by evidence—not convenience.

## Recommended Policy Going Forward

- Treat GPT-5.2 as the authoritative path for correctness-critical runs
- Use local models for best-effort or private workflows with enforcement
- Preserve this document as the justification for that bifurcation

Future revisitation should begin here, not from scratch.
