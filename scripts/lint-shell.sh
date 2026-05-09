#!/bin/bash
set -u
set -o pipefail

exec qlty check --filter shellcheck "$@"
