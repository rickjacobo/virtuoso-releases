#!/usr/bin/env bash
#
# upgrade.sh — Upgrade virtuOSo vm binary from GitHub Releases
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/rickjacobo/virtuoso-releases/main/upgrade.sh | bash
#
set -euo pipefail

REPO="rickjacobo/virtuoso-releases"
API_BASE="https://api.github.com"
BIN_PATH="/usr/local/bin/vm"
ASSET_NAME="vm-linux-amd64"
CHECKSUM_NAME="vm-linux-amd64.sha256"

# Auth header for private repo
AUTH_HEADER=""
if [ -n "${GITHUB_TOKEN:-}" ]; then
    AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"
fi

gh_curl() {
    if [ -n "${AUTH_HEADER}" ]; then
        curl -sSL -H "${AUTH_HEADER}" -H "Accept: application/vnd.github+json" "$@"
    else
        curl -sSL -H "Accept: application/vnd.github+json" "$@"
    fi
}

gh_download() {
    if [ -n "${AUTH_HEADER}" ]; then
        curl -sSL -H "${AUTH_HEADER}" -H "Accept: application/octet-stream" "$@"
    else
        curl -sSL -H "Accept: application/octet-stream" "$@"
    fi
}

echo "=== virtuOSo Upgrade ==="

# Get current version
CURRENT="unknown"
if [ -x "${BIN_PATH}" ]; then
    CURRENT=$("${BIN_PATH}" version 2>/dev/null | awk '{print $2}' || echo "unknown")
fi
echo "Current version: ${CURRENT}"

# Fetch latest release
echo "Checking for updates..."
RELEASE_JSON=$(gh_curl "${API_BASE}/repos/${REPO}/releases/latest")

LATEST=$(echo "${RELEASE_JSON}" | grep -oP '"tag_name"\s*:\s*"\K[^"]+')
echo "Latest version:  ${LATEST}"

CURRENT_NORM="${CURRENT#v}"
LATEST_NORM="${LATEST#v}"

if [ "${CURRENT_NORM}" = "${LATEST_NORM}" ]; then
    echo "Already on the latest version."
    exit 0
fi

# Extract asset URLs (use API URLs for token auth)
BINARY_URL=$(echo "${RELEASE_JSON}" | python3 -c "
import sys, json
r = json.load(sys.stdin)
for a in r.get('assets', []):
    if a['name'] == '${ASSET_NAME}':
        print(a['url'])
        break
" 2>/dev/null || echo "")

CHECKSUM_URL=$(echo "${RELEASE_JSON}" | python3 -c "
import sys, json
r = json.load(sys.stdin)
for a in r.get('assets', []):
    if a['name'] == '${CHECKSUM_NAME}':
        print(a['url'])
        break
" 2>/dev/null || echo "")

if [ -z "${BINARY_URL}" ]; then
    echo "ERROR: No ${ASSET_NAME} asset found in release ${LATEST}"
    exit 1
fi

# Download binary
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

echo "Downloading ${LATEST}..."
gh_download -o "${TMPDIR}/vm" "${BINARY_URL}"
chmod +x "${TMPDIR}/vm"

# Verify checksum
if [ -n "${CHECKSUM_URL}" ]; then
    echo "Verifying checksum..."
    gh_download -o "${TMPDIR}/vm.sha256" "${CHECKSUM_URL}"
    EXPECTED=$(awk '{print $1}' "${TMPDIR}/vm.sha256")
    ACTUAL=$(sha256sum "${TMPDIR}/vm" | awk '{print $1}')
    if [ "${EXPECTED}" != "${ACTUAL}" ]; then
        echo "ERROR: Checksum mismatch! Expected ${EXPECTED}, got ${ACTUAL}"
        exit 1
    fi
    echo "Checksum OK."
fi

# Smoke test
echo "Running smoke test..."
"${TMPDIR}/vm" version

# Deploy
echo "Backing up current binary..."
cp "${BIN_PATH}" "${BIN_PATH}.bak" 2>/dev/null || true

echo "Deploying..."
cp "${TMPDIR}/vm" "${BIN_PATH}.new"

if command -v vm-deploy &>/dev/null; then
    vm-deploy "${BIN_PATH}.new"
else
    # Inline deploy logic
    systemctl reset-failed vm-lab-upgrade 2>/dev/null || true
    systemd-run --unit=vm-lab-upgrade bash -c "systemctl stop vm-lab && mv ${BIN_PATH}.new ${BIN_PATH} && systemctl start vm-lab"
    echo "Waiting for service to start..."
    sleep 3
    if systemctl is-active --quiet vm-lab; then
        echo "Upgrade complete. Service is active."
    else
        echo "WARNING: Service may not be running. Check with: systemctl status vm-lab"
    fi
fi
