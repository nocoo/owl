#!/bin/sh
set -e
case "$(uname -s)" in
Darwin)
    exec husky
    ;;
*)
    echo "prepare: Husky skipped (unified L1 pre-commit requires macOS)." >&2
    ;;
esac
