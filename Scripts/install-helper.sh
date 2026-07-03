#!/bin/bash
# install-helper.sh — one-time privileged setup so TUN mode never asks for a
# password again. Run as root (via osascript admin prompt) ONCE.
#
# Arg: $1 = source resource directory (contains tun2socks, tun-up.sh, tun-down.sh)
#
# Installs the helper into a fixed root-owned location and adds a NOPASSWD
# sudoers rule scoped to ONLY the two helper scripts. Because the install dir
# and scripts are root-owned (the user cannot modify them) and tun2socks is
# resolved relative to that dir, this does not grant general root access.
set -euo pipefail

SRC_DIR="${1:-}"
INSTALL_DIR="/usr/local/libexec/beacon"
SUDOERS_FILE="/etc/sudoers.d/beacon"
CONSOLE_USER="${SUDO_USER:-$(/usr/bin/stat -f%Su /dev/console)}"

log() { echo "[install-helper] $*"; }

if [ -z "${SRC_DIR}" ] || [ ! -d "${SRC_DIR}" ]; then
  log "ERROR: source dir not provided or missing"; exit 1
fi
for f in tun2socks tun-up.sh tun-down.sh; do
  [ -f "${SRC_DIR}/${f}" ] || { log "ERROR: missing ${f} in ${SRC_DIR}"; exit 1; }
done

# 1. Install files, root-owned and not group/other-writable.
/bin/mkdir -p "${INSTALL_DIR}"
/usr/bin/install -m 0755 -o root -g wheel "${SRC_DIR}/tun2socks" "${INSTALL_DIR}/tun2socks"
/usr/bin/install -m 0755 -o root -g wheel "${SRC_DIR}/tun-up.sh"  "${INSTALL_DIR}/tun-up.sh"
/usr/bin/install -m 0755 -o root -g wheel "${SRC_DIR}/tun-down.sh" "${INSTALL_DIR}/tun-down.sh"
/usr/bin/install -m 0755 -o root -g wheel "${SRC_DIR}/tun-ping.sh" "${INSTALL_DIR}/tun-ping.sh"
/usr/sbin/chown -R root:wheel "${INSTALL_DIR}"
/bin/chmod 0755 "${INSTALL_DIR}"
log "installed helper to ${INSTALL_DIR}"

# 2. Write the NOPASSWD sudoers rule, scoped to the helper scripts only.
TMP_SUDO="$(/usr/bin/mktemp)"
cat > "${TMP_SUDO}" <<EOF
# Managed by Xray Client. Allows the console user to manage TUN mode without a
# password. Scoped to the root-owned helper scripts only.
${CONSOLE_USER} ALL=(root) NOPASSWD: ${INSTALL_DIR}/tun-up.sh, ${INSTALL_DIR}/tun-down.sh, ${INSTALL_DIR}/tun-ping.sh
EOF

# 3. Validate syntax with visudo BEFORE installing (never break sudo).
if /usr/sbin/visudo -cf "${TMP_SUDO}" >/dev/null 2>&1; then
  /usr/bin/install -m 0440 -o root -g wheel "${TMP_SUDO}" "${SUDOERS_FILE}"
  /bin/rm -f "${TMP_SUDO}"
  log "installed sudoers rule -> ${SUDOERS_FILE} for user ${CONSOLE_USER}"
else
  /bin/rm -f "${TMP_SUDO}"
  log "ERROR: sudoers validation failed; nothing changed"; exit 1
fi

log "Helper installed. TUN mode will no longer prompt for a password."
