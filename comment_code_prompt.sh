#!/bin/sh
###############################################################################
# @file comment_code_prompt.sh
# @brief Render a “comment-only” documentation prompt from ADR + source code.
#
# @details
# This script produces a single prompt on stdout. It does not call any LLM.
# The prompt is intended to be piped into a tool like `llm`.
#
# This file is intentionally documentation-heavy because it is often used in
# automation where failures are discovered under time pressure (CI, incident
# response, or one-off “generate a prompt” workflows).
#
# The design prioritizes correctness under “messy text” conditions:
# - ADR Markdown and source code can include quotes, backslashes, and newlines.
# - We avoid shell escaping by JSON-encoding raw text via: jq -Rs .
# - We then render a Jinja2 template using that JSON data.
#
# @par Inputs
# - A source code file path OR "-" for stdin (required).
# - Optional ADR path (-a). Defaults to ADR-026-documentation-first-source-code-commenting-standard.md
# - Optional template path (-t). Defaults to code_comment_prompt.j2
#
# @par Output
# - Rendered prompt written to stdout.
#
# @par Tooling
# - Requires: jq
# - Requires: jinja2-cli either locally ("jinja2") or via Docker image.
#
# @par Defaults
# - Docker image fallback: wesleydean/jinja2-cli:latest
#
# @par Safety and failure posture
# - The script is “fail-fast”: it exits on unset variables and command errors.
# - It fails closed if required tools/files are missing.
# - Temporary workspace is removed on normal exit and on common termination signals.
#
# @par Non-goals
# - This script does not validate the ADR or template content beyond file existence.
# - This script does not attempt to escape or sanitize the source/ADR beyond JSON encoding.
###############################################################################

set -eu

# ---------------- Defaults ----------------
#
# @details
# These defaults are centralized so callers can rely on stable behavior while
# still being able to override paths/commands via environment variables or flags.
#
# @var DEFAULT_ADR_FILENAME
# Default ADR file name used when ADR_PATH is not provided.
#
# @var DEFAULT_TEMPLATE_FILENAME
# Default Jinja2 template file name used when TEMPLATE_PATH is not provided.
#
# @var DEFAULT_JINJA2_DOCKER_IMAGE
# Docker image used when a local jinja2 executable is not available.
DEFAULT_ADR_FILENAME="ADR-026-documentation-first-source-code-commenting-standard.md"
DEFAULT_TEMPLATE_FILENAME="code_comment_prompt.j2"
DEFAULT_JINJA2_DOCKER_IMAGE="wesleydean/jinja2-cli:latest"

# @var ADR_PATH
# Effective ADR path. Environment variable takes precedence over DEFAULT_ADR_FILENAME.
ADR_PATH="${ADR_PATH:-$DEFAULT_ADR_FILENAME}"
# @var TEMPLATE_PATH
# Effective template path. Environment variable takes precedence over DEFAULT_TEMPLATE_FILENAME.
TEMPLATE_PATH="${TEMPLATE_PATH:-$DEFAULT_TEMPLATE_FILENAME}"

# @var JINJA2_CMD
# Command name/path to the local jinja2-cli renderer.
JINJA2_CMD="${JINJA2_CMD:-jinja2}"
# @var JINJA2_DOCKER_IMAGE
# Docker image name used as a fallback renderer when local jinja2-cli is unavailable.
JINJA2_DOCKER_IMAGE="${JINJA2_DOCKER_IMAGE:-$DEFAULT_JINJA2_DOCKER_IMAGE}"

# ---------------- Utilities ----------------

die() {
  # @brief Print an error message to stderr and exit non-zero.
  #
  # @details
  # This helper standardizes error reporting and ensures the script exits with a
  # clear, single-line message. It is used for both validation failures and
  # missing dependencies.
  #
  # @param $*
  # Message fragments to print; passed through `printf '%s\n'`.
  #
  # @retval 1
  # Always terminates the script with exit status 1.
  printf '%s\n' "$*" >&2
  exit 1
}

have() {
  # @brief Check whether a command is available on PATH.
  #
  # @details
  # This is used to probe for optional tooling (local jinja2 renderer, docker),
  # and for required tooling (jq). The implementation avoids emitting output and
  # treats any failure as “not available”.
  #
  # @param $1
  # The command name to look up.
  #
  # @retval 0
  # Command exists and is executable.
  #
  # @retval 1
  # Command is not available.
  command -v "$1" >/dev/null 2>&1
}

usage() {
  # @brief Print usage help and exit with a “bad usage” status.
  #
  # @details
  # This function writes to stderr so it is visible even when stdout is being
  # piped to another tool. It exits with status 2 to distinguish usage errors
  # from runtime failures (which generally use status 1).
  #
  # @retval 2
  # Always terminates the script with exit status 2.
  cat <<USAGE >&2
Usage:
  comment_code_prompt.sh [-a ADR.md] [-t template.j2] SOURCE_FILE
  comment_code_prompt.sh [-a ADR.md] [-t template.j2] -

Arguments:
  SOURCE_FILE   Path to source code file, or "-" to read source code from stdin.

Options:
  -a ADR.md     Path to ADR file (default: $DEFAULT_ADR_FILENAME)
  -t FILE.j2    Path to Jinja2 template (default: $DEFAULT_TEMPLATE_FILENAME)
  -h            Show help

Environment:
  ADR_PATH               Default ADR path (overrides default filename)
  TEMPLATE_PATH          Default template path (overrides default filename)
  JINJA2_CMD             Local jinja2-cli command (default: jinja2)
  JINJA2_DOCKER_IMAGE    Docker fallback image (default: $DEFAULT_JINJA2_DOCKER_IMAGE)

Output:
  Writes the rendered prompt to stdout.
USAGE
  exit 2
}

render() {
  # @brief Render a Jinja2 template using a JSON data file.
  #
  # @details
  # Rendering is attempted in the following precedence order:
  # 1) Local jinja2-cli command (JINJA2_CMD) if present on PATH.
  # 2) Docker fallback using JINJA2_DOCKER_IMAGE if docker is available.
  #
  # This ordering is intentional:
  # - Local rendering is faster and avoids container runtime dependencies.
  # - Docker fallback provides a consistent toolchain in environments where
  #   jinja2-cli is not installed.
  #
  # @param $1 template
  # Path to the Jinja2 template file.
  #
  # @param $2 data
  # Path to a JSON file containing the template variables.
  #
  # @retval 0
  # Template rendered successfully to stdout.
  #
  # @retval 1
  # No renderer was available or the underlying renderer failed.
  #
  # @par Security considerations
  # - Template execution can evaluate Jinja2 expressions. Treat templates as
  #   trusted inputs (do not run untrusted templates).
  # - The Docker invocation mounts the current working directory read-write by
  #   default via `-v "$(pwd)":/work`. In hostile directories, this can expose
  #   data to the container.
  template="$1"
  data="$2"

  if have "$JINJA2_CMD"; then
    "$JINJA2_CMD" "$template" "$data"
    return 0
  fi

  if have docker && [ -n "$JINJA2_DOCKER_IMAGE" ]; then
    # Mount the working directory so the template and data file are accessible.
    # Using a stable mount point keeps the invocation predictable.
    docker run --rm \
      -v "$(pwd)":/work \
      -w /work \
      "$JINJA2_DOCKER_IMAGE" \
      jinja2 "$template" "$data"
    return 0
  fi

  die "No jinja2 renderer available.  Install jinja2-cli as '$JINJA2_CMD' or ensure Docker is available."
}

# ---------------- Args ----------------
#
# @details
# Command-line flags override environment-derived defaults. This allows both
# “configuration via environment” (useful in CI) and explicit per-invocation
# overrides (useful for local experimentation).
adr_file="$ADR_PATH"
template_file="$TEMPLATE_PATH"

while getopts "a:t:h" opt; do
  case "$opt" in
    a) adr_file="$OPTARG" ;;
    t) template_file="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

# @details
# Exactly one positional argument is required: a file path or "-" for stdin.
[ "$#" -eq 1 ] || usage
source_input="$1"

# ---------------- Preconditions ----------------
#
# @details
# We validate early so failures happen before any partial output is produced.
# This is important because stdout is often consumed by downstream commands.
have jq || die "jq is required"

[ -f "$adr_file" ] || die "ADR file not found: $adr_file"
[ -f "$template_file" ] || die "Template file not found: $template_file"

# ---------------- Workspace ----------------
#
# @details
# Temporary files are used to:
# - support stdin input (which otherwise has no stable file path), and
# - provide file paths for tools that expect files (jq, jinja2-cli).
#
# The trap ensures cleanup on normal exit and common termination signals.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

data_json="$tmpdir/data.json"
source_tmp="$tmpdir/source.txt"

# ---------------- Read source ----------------
#
# @details
# The “source_filename” value is passed through to the template. When stdin is
# used, we preserve "-" as the filename sentinel so the rendered prompt can
# reflect that the input was streamed.
if [ "$source_input" = "-" ]; then
  source_filename="-"
  cat >"$source_tmp"
else
  [ -f "$source_input" ] || die "Source file not found: $source_input"
  source_filename="$source_input"
  cat "$source_input" >"$source_tmp"
fi

# ---------------- JSON build (safe text handling) ----------------
#
# @details
# The key robustness property of this script is that it never tries to manually
# escape multi-line or quote-heavy text in shell variables. Instead:
# - jq -Rs . reads the entire file as raw text and emits a JSON string.
# - We then assemble a JSON object with jq -n and --argjson to avoid double
#   quoting and to prevent injection via shell string concatenation.
#
# This keeps newlines, quotes, backslashes, and other characters intact.
#
# @TODO Confirm whether jq -Rs behavior differences across jq versions need to
# be documented (e.g., handling of NUL bytes) for the expected input set.
#
# Encode raw files as JSON strings (preserves newlines, quotes, slashes, etc.).
adr_content_json="$(jq -Rs . "$adr_file")"
source_code_json="$(jq -Rs . "$source_tmp")"

# Assemble the object using jq to avoid shell JSON pitfalls.
jq -n \
  --arg source_filename "$source_filename" \
  --argjson adr_content "$adr_content_json" \
  --argjson source_code "$source_code_json" \
  '{
    source_filename: $source_filename,
    adr_content: $adr_content,
    source_code: $source_code
  }' >"$data_json"

# ---------------- Render to stdout ----------------
#
# @details
# Rendering is the final step and writes directly to stdout so the caller can:
# - redirect to a file, or
# - pipe into an LLM tool, or
# - preview in a terminal.
render "$template_file" "$data_json"
