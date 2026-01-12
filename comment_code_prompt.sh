#!/bin/sh
###############################################################################
# @file comment_code_prompt.sh
# @brief Render a “comment-only” documentation prompt from ADR + source code.
#
# @details
# This script produces a single prompt on stdout.  It does not call any LLM.
# The prompt is intended to be piped into a tool like `llm`.
#
# The design prioritizes correctness under “messy text” conditions:
# - ADR Markdown and source code can include quotes, backslashes, and newlines.
# - We avoid shell escaping by JSON-encoding raw text via: jq -Rs .
# - We then render a Jinja2 template using that JSON data.
#
# @par Inputs
# - A source code file path OR "-" for stdin (required).
# - Optional ADR path (-a).  Defaults to ADR-026-documentation-first-source-code-commenting-standard.md
# - Optional template path (-t).  Defaults to code_comment_prompt.j2
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
###############################################################################

set -eu

# ---------------- Defaults ----------------

DEFAULT_ADR_FILENAME="ADR-026-documentation-first-source-code-commenting-standard.md"
DEFAULT_TEMPLATE_FILENAME="code_comment_prompt.j2"
DEFAULT_JINJA2_DOCKER_IMAGE="wesleydean/jinja2-cli:latest"

ADR_PATH="${ADR_PATH:-$DEFAULT_ADR_FILENAME}"
TEMPLATE_PATH="${TEMPLATE_PATH:-$DEFAULT_TEMPLATE_FILENAME}"

JINJA2_CMD="${JINJA2_CMD:-jinja2}"
JINJA2_DOCKER_IMAGE="${JINJA2_DOCKER_IMAGE:-$DEFAULT_JINJA2_DOCKER_IMAGE}"

# ---------------- Utilities ----------------

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

usage() {
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

[ "$#" -eq 1 ] || usage
source_input="$1"

# ---------------- Preconditions ----------------

have jq || die "jq is required"

[ -f "$adr_file" ] || die "ADR file not found: $adr_file"
[ -f "$template_file" ] || die "Template file not found: $template_file"

# ---------------- Workspace ----------------

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

data_json="$tmpdir/data.json"
source_tmp="$tmpdir/source.txt"

# ---------------- Read source ----------------

if [ "$source_input" = "-" ]; then
  source_filename="-"
  cat >"$source_tmp"
else
  [ -f "$source_input" ] || die "Source file not found: $source_input"
  source_filename="$source_input"
  cat "$source_input" >"$source_tmp"
fi

# ---------------- JSON build (safe text handling) ----------------

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

render "$template_file" "$data_json"
