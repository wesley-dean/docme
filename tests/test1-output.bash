```bash
#!/usr/bin/env bash

set -euo pipefail

# @file test1.bash
# @brief Perform cleanup of temporary files in a directory.
#
# @details
# This script deletes all files ending with '~' in the specified directory.
# It is designed to run during tests to clean up temporary files.
#
# @var directory
# Path to the directory from which to delete temporary files. Defaults to current directory if not provided.

main() {
  directory="${1:-.}"
  find "${directory}" -maxdepth 1 -name "*~" -readable -writable -delete
}

# if we're not being sourced and there's a function named `main`, run it
[[ "$0" == "${BASH_SOURCE[0]}" ]] && [ "$(type -t "main")" = "function" ] && main "$@"
```
