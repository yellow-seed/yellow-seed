#!/bin/bash
set -u
set -o pipefail

if [[ $# -gt 0 ]]; then
	exec qlty check "$@"
else
	exec qlty check --all
fi
