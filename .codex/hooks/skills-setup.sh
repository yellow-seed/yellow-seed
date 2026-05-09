#!/bin/bash
#
# Skills Directory Setup Script
#
# This script provides a fallback for environments where symlinks are not supported
# (e.g., Windows without admin privileges, Git with core.symlinks=false).
#
# If .claude/skills is not a directory (e.g., a text file containing the symlink path),
# this script will copy .agents/skills to that directory.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CLAUDE_SKILLS="${REPO_ROOT}/.claude/skills"
GITHUB_SKILLS="${REPO_ROOT}/.agents/skills"

# Check if .agents/skills exists
if [ ! -d "${GITHUB_SKILLS}" ]; then
	echo "✗ Error: .agents/skills directory not found"
	exit 1
fi

setup_skills_dir() {
	local target_dir="$1"
	local dir_name="$2"

	echo "Checking ${dir_name} setup..."

	# Check if target directory exists and is a directory
	if [ -d "${target_dir}" ]; then
		echo "✓ ${dir_name} is already a directory (symlink or real directory)"
		return 0
	fi

	# Remove the file if it exists (e.g., text file from failed symlink)
	if [ -e "${target_dir}" ]; then
		echo "⚠ Removing non-directory ${dir_name}..."
		rm -f "${target_dir}"
	fi

	# Copy .agents/skills to target directory
	echo "Copying .agents/skills to ${dir_name}..."
	cp -r "${GITHUB_SKILLS}" "${target_dir}"

	echo "✓ Successfully set up ${dir_name}"
}

# Set up .claude/skills
setup_skills_dir "${CLAUDE_SKILLS}" ".claude/skills"

echo ""
echo "Note: In environments with symlink support, .claude/skills is a symlink to .agents/skills."
echo "In this environment, they have been created as copies."
echo "Please ensure to manually sync changes between .agents/skills and these directories if needed."
