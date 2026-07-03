#!/bin/bash
# tun-up.sh — bring up TUN mode. Run as root (via sudo -n or osascript).
#
# Args (data only — no executable paths, so a NOPASSWD sudoers rule is safe):
#   $1 = SOCKS proxy address, e.g. 127.0.0.1:10808
#   $2 = comma-separated VPN server IPv4s to keep off the tunnel (may be empty)
#
# The tun2socks binary is taken from THIS script's own directory (root-owned
# when installed), never from an argument, to prevent arbitrary-binary execution.
set -euo pipefail

SOCKS_ADDR="${1:-}"
SERVER_IPS="${2:-}"

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
T2S_BIN="${SELF_DIR}/tun2socks"
PID_FILE="/tmp/beacon-tun2socks.pid"
STATE_FILE="/tmp/beacon-tun.state"

TUN_DEV="utun123"
TUN_GW="198.18.0.1"
TUN_ADDR="198.18.0.1"
TUN_PEER="198.18.0.2"
DNS_IP="1.1.1.1"

log() { echo "[tun-up] $*"; }

# --- Input validation (defends the NOPASSWD entry) ---
if ! printf '%s' "${SOCKS_ADDR}" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}:[0-9]{1,5}$'; then
  log "ERROR: invalid SOCKS address"; exit 2
fi
if [ -n "${SERVER_IPS}" ]; then
  IFS=',' read -ra _IPS <<< "${SERVER_IPS}"
  for _ip in "${_IPS[@]}"; do
    [ -z "${_ip}" ] && continue
    printf '%s' "${_ip}" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' \
      || { log "ERROR: invalid server IP: ${_ip}"; exit 2; }
  done
fi
if [ ! -x "${T2S_BIN}" ]; then
  log "ERROR: tun2socks not found at ${T2S_BIN}"; exit 3
fi

PINNED_FILE="/tmp/beacon-tun.pinned"

# --- Fast path: tunnel already up → only (re)pin the new server IP(s) ---
# Used when switching servers without tearing down tun2socks (sub-second).
if [ -f "${PID_FILE}" ] && kill -0 "$(cat "${PID_FILE}" 2>/dev/null)" 2>/dev/null \
   && ifconfig "${TUN_DEV}" >/dev/null 2>&1; then
  GW="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2; exit}')"
  # Fall back to the recorded gateway if the default now points at the tun.
  if [ -z "${GW}" ] || [ "${GW}" = "${TUN_GW}" ]; then
    GW="$(awk -F= '/^ORIG_GW=/{print $2}' "${STATE_FILE}" 2>/dev/null)"
  fi
  IFS=',' read -ra IPS <<< "${SERVER_IPS}"
  for ip in "${IPS[@]}"; do
    [ -z "${ip}" ] && continue
    route -n add -host "${ip}" "${GW}" >/dev/null 2>&1 || route -n change -host "${ip}" "${GW}" >/dev/null 2>&1 || true
    grep -qx "${ip}" "${PINNED_FILE}" 2>/dev/null || echo "${ip}" >> "${PINNED_FILE}"
  done
  # Make sure split-default routes are still present.
  route -n add -net 0.0.0.0/1   "${TUN_GW}" >/dev/null 2>&1 || true
  route -n add -net 128.0.0.0/1 "${TUN_GW}" >/dev/null 2>&1 || true
  log "fast re-pin: ${SERVER_IPS} via ${GW}"
  exit 0
fi

# Discover current default gateway / physical interface BEFORE changing routes.
ORIG_GW="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2; exit}')"
ORIG_IF="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
if [ -z "${ORIG_GW}" ]; then
  log "ERROR: could not determine current default gateway"; exit 1
fi
log "physical gateway=${ORIG_GW} iface=${ORIG_IF}"

{
  echo "ORIG_GW=${ORIG_GW}"
  echo "ORIG_IF=${ORIG_IF}"
  echo "SERVER_IPS=${SERVER_IPS}"
  echo "TUN_DEV=${TUN_DEV}"
} > "${STATE_FILE}"

# 1. Start tun2socks (creates the utun device).
log "starting tun2socks on ${TUN_DEV} -> socks ${SOCKS_ADDR}"
"${T2S_BIN}" \
  -device "${TUN_DEV}" \
  -proxy "socks5://${SOCKS_ADDR}" \
  -interface "${ORIG_IF}" \
  >/tmp/tun2socks.log 2>&1 &
echo "$!" > "${PID_FILE}"

for _ in $(seq 1 25); do
  ifconfig "${TUN_DEV}" >/dev/null 2>&1 && break
  sleep 0.2
done
if ! ifconfig "${TUN_DEV}" >/dev/null 2>&1; then
  log "ERROR: ${TUN_DEV} did not come up"
  kill "$(cat "${PID_FILE}" 2>/dev/null)" 2>/dev/null || true
  exit 1
fi

# 2. Configure tun address.
ifconfig "${TUN_DEV}" "${TUN_ADDR}" "${TUN_PEER}" up
ifconfig "${TUN_DEV}" mtu 1500 || true

# 3. Pin VPN server IP(s) to the physical gateway (bypass tunnel, avoid loop).
: > "${PINNED_FILE}"
IFS=',' read -ra IPS <<< "${SERVER_IPS}"
for ip in "${IPS[@]}"; do
  [ -z "${ip}" ] && continue
  route -n delete "${ip}" >/dev/null 2>&1 || true
  route -n add -host "${ip}" "${ORIG_GW}" >/dev/null 2>&1 || true
  echo "${ip}" >> "${PINNED_FILE}"
  log "pinned server ${ip} via ${ORIG_GW}"
done

# 4. Override default with two /1 routes through the tun (reversible, safe).
route -n add -net 0.0.0.0/1   "${TUN_GW}" >/dev/null 2>&1 || true
route -n add -net 128.0.0.0/1 "${TUN_GW}" >/dev/null 2>&1 || true
log "added split-default routes via ${TUN_GW}"

# 5. DNS through the tunnel; save current resolvers for restore.
networksetup -listallnetworkservices 2>/dev/null | tail -n +2 | while read -r svc; do
  case "${svc}" in \** ) continue ;; esac
  cur="$(networksetup -getdnsservers "${svc}" 2>/dev/null | tr '\n' ' ')"
  echo "DNS::${svc}::${cur}" >> "${STATE_FILE}"
  networksetup -setdnsservers "${svc}" "${DNS_IP}" 2>/dev/null || true
done
log "DNS set to ${DNS_IP}"
log "TUN mode is up."
