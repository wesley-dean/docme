# docme — Documentation-First, Non-Destructive Code Commenting with LLMs

## Overview

This project exists to solve a very specific, deliberately constrained problem:

**How do we use Large Language Models (LLMs) to improve source code documentation
without risking silent, destructive changes to executable code?**

The tools in this repository enable *documentation-only* updates to existing
source files, driven by a strict documentation standard (ADR-026) and reinforced
by tooling that assumes LLM output is *untrusted* until verified.

This project is intentionally conservative.

It prioritizes:
- human comprehension under stress,
- non-destructive automation,
- and explicit guardrails around AI-assisted changes.

The result is a workflow that favors *fewer incidents* over cleverness.

---

## Why This Project Exists

Modern LLMs are extremely capable, but they exhibit well-documented failure
modes when asked to “just add comments”:

- rewriting entire files,
- altering control flow,
- replacing logic with stubs,
- inventing rationale,
- or silently dropping edge cases.

ADR-026 (Documentation-First Source Code Commenting Standard) exists to counter
these tendencies by treating documentation as a **first-class architectural
artifact**, not decoration.

This repository provides:
- a repeatable prompt construction mechanism,
- strict output sanitization,
- and safe, auditable application of changes,

so that documentation can be improved *without modifying behavior*.

If a change cannot be proven safe, it is rejected.

---

## Quick Start

### Prerequisites

You will need:

- `sh` (POSIX-compliant shell)
- `jq`
- `awk`, `sed`, `grep` (BSD or GNU)
- [`llm`](https://pypi.org/project/llm/) CLI
- Either:
  - `jinja2-cli`, **or**
  - Docker (for the Jinja2 CLI fallback image)

### Basic Usage

```bash
docme path/to/source_file.sh
```

This will:

1. Render a documentation-only prompt using `comment_code_prompt.sh`
2. Send the prompt to an LLM (default: `gpt-5.2`)
3. Sanitize the output to remove Markdown fencing
4. Overwrite the original file **after creating a backup**

A backup is written as:

```text
path/to/source_file.sh~
```

### Using STDIN / STDOUT

```bash
cat source.py | docme > source.documented.py
```

No backups are created when operating as a stream.

---

## Selecting a Model

By default, `docme` uses:

```text
gpt-5.2
```

To use a different model, set the `model` environment variable:

```bash
model=gpt-4o-mini docme script.sh
model=qwen2.5-coder:7b docme script.sh
```

This design allows experimentation while keeping the default path aligned with
the most reliable behavior observed during testing.

---

## Tools in This Repository

### `docme`

**Primary user-facing command.**

`docme` orchestrates the full workflow:
- prompt generation,
- LLM invocation,
- output sanitization,
- and safe file replacement.

#### Behavior

- Accepts 0 or more filenames
- Iterates over files when multiple are provided
- Creates `~` backups before overwriting
- Uses STDIN/STDOUT when no filenames are given

#### Environment Variables

- `model` — LLM model name (default: `gpt-5.2`)

---

### `comment_code_prompt.sh`

Generates a **single, deterministic prompt** on stdout.

It:
- reads an ADR describing the documentation standard,
- reads source code verbatim,
- JSON-encodes both safely using `jq`,
- renders a Jinja2 template.

It does *not* call an LLM.

#### Usage

```bash
comment_code_prompt.sh source_file
comment_code_prompt.sh -a custom_adr.md source_file
comment_code_prompt.sh -t custom_template.j2 source_file
comment_code_prompt.sh - source_from_stdin
```

#### Options

- `-a ADR.md` — path to ADR file
  Default: `ADR-026-documentation-first-source-code-commenting-standard.md`
- `-t TEMPLATE.j2` — Jinja2 template path
- `-h` — help

#### Environment Overrides

- `ADR_PATH`
- `TEMPLATE_PATH`
- `JINJA2_CMD`
- `JINJA2_DOCKER_IMAGE` (default: `wesleydean/jinja2-cli:latest`)

---

### `sanitize_llm_output.sh`

A **strict POSIX filter** that removes a single outer Markdown code fence and
rejects output that still contains fencing.

It is intentionally conservative.

#### Sourced Usage

```bash
. ./sanitize_llm_output.sh
render | sanitize_llm_output_helper
```

#### Executed Usage

```bash
sanitize_llm_output.sh < llm_output.txt
```

If fencing remains after sanitization, the script fails loudly.

This behavior is by design.

---

## Architecture Decision Record (ADR-026)

ADR-026 defines the documentation standard enforced by this project.

Its core principles:

- Documentation is architecture
- Comments exist for tired, stressed humans
- Verbosity is a feature, not a flaw
- Ambiguity must be marked explicitly (`@TODO`)
- AI-assisted documentation **must not** modify executable code

This ADR is included in the repository and is intended to be reusable across
projects.

---

## Safety and Design Philosophy

This project deliberately separates concerns:

- Prompt construction is deterministic
- LLMs propose changes
- Tooling enforces constraints

LLMs are treated as **suggestion engines**, not authorities.

All enforcement happens outside the model.

This design choice is informed by extensive experimentation across:
- cloud-hosted models,
- local models via Ollama,
- and varying hardware constraints.

The conclusions from those experiments are documented separately to preserve
institutional memory.

## Frequently Anticipated Questions

### Why ADR-026 and not ADR-001

Because the ADR was copied out of another project where it was, in fact,
ADR-026.

### Why sanitize to remove the Markdown code fences

Because some of the local LLM tools (e.g., ollama) with certain models proved
to be "too helpful" and not follow all of the instructions, particularly those
that relate to how the code is spit out at the end.  The sanitize script looks
to see if the output starts with a Markdown fence, it removes that line; if
it ends with the end of a code fence, remove that, too.

### Why all of the POSIX nonsense?

Because I'm pedantic and I want this to work in a variety of environments,
including when I run it under Linux as well as OpenBSD and FreeBSD, not to
mention situations where non-current versions of Bash are used.

#### But you use Bash everywhere?

Yes.  Yes I do.

### But why so much documentation

Because, again, pedantic.  More importantly, because I work on a bunch of
projects and stuff gets confusing, because I forget stuff, because good
documentation is important by itself, not to mention as a signal of someone
taking their craft seriously.

#### Could you just send it to ChatGPT, Copilot, etc. and ask it what's up

Yes.  Yes I could.  I would rather the documentation live with the source
code and not require external tooling.

### Won't the documentation get out of date

It may very well become outdated.  Regenerate the documentation.  Dependencies
become outdated, too.

### Could this be used in a CI/CD pipeline

Sure, why not.  I suspect that LLM calls may become expensive when large
numbers of files are included in PRs and/or changed often.

I would recommend reviewing the changes before merging them into a repo.

### Can I run this locally with something like ollama

Yes.  Absolutely.  That said, I've found that smaller models tend to not do
a very good job of following directions, documenting entire files (even when
very small), etc..

The results of my experimenting are found in:
[llm-assisted-documentation-experiments.md](./llm-assisted-documentation-experiments.md)

---

## License

Creative Commons License 1.0 Universal.
See [LICENSE](LICENSE).

---

## Contributing

Contributions are welcome.

Please preserve the conservative, safety-first posture of this project.
If a feature increases convenience at the expense of correctness or auditability,
it is likely out of scope.

---

## Author

Wes Dean
