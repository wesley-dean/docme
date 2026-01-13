#!/bin/sh

set -eu

  # Read all input once so we can safely drop a leading and trailing fence
  # without losing streaming correctness.
  tmpdir=$(mktemp -d) || return 1
  in="$tmpdir/in"
  out="$tmpdir/out"
  trap 'rm -rf "$tmpdir"' EXIT INT TERM

  cat >"$in" || { rm -rf "$tmpdir"; return 1; }

  # Drop the first line if it is a code fence (``` or ```lang)
  # Drop the last line if it is a code fence (```)
  sed '1{/^```/d;}' "$in" | sed '${/^```/d;}' >"$out" || { rm -rf "$tmpdir"; return 1; }

  # Refuse output if any fences remain (indicates commentary or nested blocks)
  if grep -q '^```' "$out"; then
    printf '%s\n' "sanitize_llm_output: refusing output containing code fences" >&2
    rm -rf "$tmpdir"
    return 1
  fi

  cat "$out"

  rm -rf "$tmpdir"
  trap - EXIT INT TERM
  return 0
