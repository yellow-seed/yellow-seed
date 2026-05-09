#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[bootstrap-gh]"

log_info() {
	local message="$1"
	echo "${LOG_PREFIX} ${message}" >&2
}

log_error() {
	local message="$1"
	echo "${LOG_PREFIX} ERROR: ${message}" >&2
}

INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "${INSTALL_DIR}"

if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
	export PATH="${INSTALL_DIR}:${PATH}"
fi

if [[ ${GH_BOOTSTRAP_FORCE_INSTALL:-false} != "true" ]] && command -v gh >/dev/null 2>&1; then
	log_info "gh already available: $(gh --version 2>&1 | head -1)"
	exit 0
fi

OS_NAME="$(uname -s)"
ARCH="$(uname -m)"
case "${OS_NAME}" in
Linux)
	OS="linux"
	EXT="tar.gz"
	;;
Darwin)
	OS="macOS"
	EXT="zip"
	;;
*)
	log_error "Unsupported OS: ${OS_NAME}"
	exit 1
	;;
esac
case "${ARCH}" in
x86_64) ARCH="amd64" ;;
aarch64 | arm64) ARCH="arm64" ;;
*)
	log_error "Unsupported architecture: ${ARCH}"
	exit 1
	;;
esac

FALLBACK_VERSION="${GH_BOOTSTRAP_FALLBACK_VERSION:-2.62.0}"
VERSION=""

log_info "Fetching latest gh CLI release..."
if RELEASE_JSON="$(curl -sfLS "https://api.github.com/repos/cli/cli/releases/latest")"; then
	VERSION="$(printf '%s\n' "${RELEASE_JSON}" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\([^"]*\)".*/\1/p' | head -1)"
fi

if [[ -z ${VERSION} ]]; then
	VERSION="${FALLBACK_VERSION}"
	log_info "Falling back to gh v${VERSION}"
fi

log_info "Downloading gh v${VERSION} (${OS}/${ARCH})..."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

ARCHIVE="gh_${VERSION}_${OS}_${ARCH}.${EXT}"
DOWNLOAD_URL="https://github.com/cli/cli/releases/download/v${VERSION}/${ARCHIVE}"

if ! curl -sfLS "${DOWNLOAD_URL}" -o "${TMP_DIR}/${ARCHIVE}"; then
	log_error "Failed to download gh from ${DOWNLOAD_URL} (startup will continue without gh)"
	exit 0
fi

if [[ ${EXT} == "zip" ]]; then
	unzip -q "${TMP_DIR}/${ARCHIVE}" -d "${TMP_DIR}"
else
	tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "${TMP_DIR}"
fi
cp "${TMP_DIR}/gh_${VERSION}_${OS}_${ARCH}/bin/gh" "${INSTALL_DIR}/gh"
chmod +x "${INSTALL_DIR}/gh"

if command -v gh >/dev/null 2>&1; then
	log_info "gh installed: $(gh --version 2>&1 | head -1)"
else
	log_error "gh not found after install (startup will continue without gh)"
	exit 0
fi
