#!/usr/bin/env bash
set -euo pipefail

CHANGES_DIR="openspec/changes"
ARCHIVE_DIR="openspec/changes/archive"
DATE="$(date +%Y-%m-%d)"

archived=0

mkdir -p "${ARCHIVE_DIR}"

# Archive completed changes (all tasks checked off)
while IFS= read -r -d '' change_dir; do
	name="$(basename "${change_dir}")"
	[[ ${name} == "archive" ]] && continue

	tasks_file="${change_dir}/tasks.md"
	[[ ! -f ${tasks_file} ]] && continue

	# Skip if any incomplete tasks remain
	if grep -q '^[[:space:]]*-[[:space:]]*\[[[:space:]]\]' "${tasks_file}"; then
		continue
	fi

	mv "${change_dir}" "${ARCHIVE_DIR}/${DATE}-${name}"
	archived=$((archived + 1))
done < <(find "${CHANGES_DIR}" -mindepth 1 -maxdepth 1 -type d -print0)

if [[ -n ${GITHUB_OUTPUT:-} ]]; then
	echo "archived=${archived}" >>"${GITHUB_OUTPUT}"
fi

echo "Archived: ${archived} change(s)"
