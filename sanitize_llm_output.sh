#!/bin/sh
#
# sanitize_llm_output.sh
#
# Provides:
#   sanitize_llm_output_helper()  # stdin -> stdout
#
# Sourced:
#   . ./sanitize_llm_output.sh
#   render | sanitize_llm_output_helper
#
# Executed:
#   ./sanitize_llm_output.sh < test.sh
#

sanitize_llm_output_helper() {
  # Read STDIN, strip a single *outer* Markdown fence:
  # - Remove the first non-empty line if it begins with ```
  # - Remove the last non-empty line if it begins with ```
  # Then refuse output if any fence lines remain (strict mode).

  tmp=""
  tmpdir="${TMPDIR:-/tmp}"

  # mktemp is not POSIX, but BSD/GNU both support the template form.
  if command -v mktemp >/dev/null 2>&1; then
    tmp=$(mktemp "${tmpdir%/}/sanitize_llm_output.XXXXXX" 2>/dev/null) || tmp=""
  fi
  if [ -z "$tmp" ]; then
    tmp="${tmpdir%/}/sanitize_llm_output.$$"
  fi

  # Transform stdin -> tmp
  awk '
    { lines[NR] = $0 }
    {
      if ($0 !~ /^[[:space:]]*$/) {
        if (first == 0) first = NR
        last = NR
      }
    }
    END {
      skip_first = 0
      skip_last  = 0

      # Strip one leading fence if it is the first non-empty line
      if (first > 0 && lines[first] ~ /^[[:space:]]*```/) skip_first = first

      # Strip one trailing fence if it is the last non-empty line
      if (last > 0 && lines[last] ~ /^[[:space:]]*```/) skip_last = last

      for (i = 1; i <= NR; i++) {
        if (i == skip_first) continue
        if (i == skip_last)  continue
        print lines[i]
      }
    }
  ' >"$tmp" || { rm -f "$tmp"; return 1; }

  # Refuse if any fences remain after trimming
  if grep '^[[:space:]]*```' "$tmp" >/dev/null 2>&1; then
    printf '%s\n' "sanitize_llm_output: refusing output containing code fences" >&2
    rm -f "$tmp"
    return 1
  fi

  cat "$tmp"
  rm -f "$tmp"
  return 0
}

# -----------------------------------------------------------------------------
# If executed: run as a filter.
# If sourced: do nothing (function is now available).
#
# Practical POSIX detection:
# - When executed, $0 is this script path/name.
# - When sourced, $0 is the parent shell (e.g., sh, bash, zsh), not this file.
# -----------------------------------------------------------------------------

case "${0##*/}" in
  sanitize_llm_output.sh) sanitize_llm_output_helper ;;
  *) : ;;
esac
