#!/bin/bash
# uninstall-helper.sh — removes the privileged helper and sudoers rule.
# Run as root (via osascript admin prompt).
set -uo pipefail
INSTALL_DIR="/usr/local/libexec/beacon"
SUDOERS_FILE="/etc/sudoers.d/beacon"
/bin/rm -f "${SUDOERS_FILE}"
/bin/rm -rf "${INSTALL_DIR}"
echo "[uninstall-helper] removed helper and sudoers rule"
