#!/usr/bin/env bash

set -euo pipefail

main() {
  directory="${1:-.}"
  find "${directory}" -maxdepth 1 -name "*~" -readable -writable -delete
}

# if we're not being sourced and there's a function named `main`, run it
[[ "$0" == "${BASH_SOURCE[0]}" ]] && [ "$(type -t "main")" = "function" ] && main "$@"
