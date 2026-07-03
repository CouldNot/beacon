#!/bin/bash
# tun-down.sh — tear down TUN mode. Run as root (via sudo -n or osascript).
# No arguments. State/PID come from fixed /tmp paths written by tun-up.sh.
set -uo pipefail

PID_FILE="/tmp/beacon-tun2socks.pid"
STATE_FILE="/tmp/beacon-tun.state"

log() { echo "[tun-down] $*"; }

ORIG_GW=""
SERVER_IPS=""
if [ -f "${STATE_FILE}" ]; then
  while IFS= read -r line; do
    case "${line}" in
      ORIG_GW=*)    ORIG_GW="${line#ORIG_GW=}" ;;
      SERVER_IPS=*) SERVER_IPS="${line#SERVER_IPS=}" ;;
    esac
  done < "${STATE_FILE}"
fi

# 1. Remove split-default routes.
route -n delete -net 0.0.0.0/1   >/dev/null 2>&1 || true
route -n delete -net 128.0.0.0/1 >/dev/null 2>&1 || true
log "removed split-default routes"

# 2. Remove pinned server host routes (from state + the running pinned file).
IFS=',' read -ra IPS <<< "${SERVER_IPS}"
for ip in "${IPS[@]}"; do
  [ -z "${ip}" ] && continue
  route -n delete -host "${ip}" >/dev/null 2>&1 || true
done
if [ -f /tmp/beacon-tun.pinned ]; then
  while IFS= read -r ip; do
    [ -z "${ip}" ] && continue
    route -n delete -host "${ip}" >/dev/null 2>&1 || true
  done < /tmp/beacon-tun.pinned
  rm -f /tmp/beacon-tun.pinned
fi

# 3. Restore DNS per service.
if [ -f "${STATE_FILE}" ]; then
  grep '^DNS::' "${STATE_FILE}" | while IFS= read -r line; do
    rest="${line#DNS::}"
    svc="${rest%%::*}"
    saved="${rest#*::}"
    saved_trimmed="$(echo "${saved}" | xargs)"
    if [ -z "${saved_trimmed}" ] || echo "${saved_trimmed}" | grep -qi "aren't\|there aren"; then
      networksetup -setdnsservers "${svc}" "Empty" 2>/dev/null || true
    else
      # shellcheck disable=SC2086
      networksetup -setdnsservers "${svc}" ${saved_trimmed} 2>/dev/null || true
    fi
  done
  log "restored DNS"
fi

# 4. Stop tun2socks.
if [ -f "${PID_FILE}" ]; then
  PID="$(cat "${PID_FILE}" 2>/dev/null || true)"
  [ -n "${PID}" ] && kill "${PID}" 2>/dev/null || true
  rm -f "${PID_FILE}"
fi
pkill -f "${0%/*}/tun2socks" 2>/dev/null || true
pkill -x tun2socks 2>/dev/null || true

rm -f "${STATE_FILE}"
log "TUN mode is down."
