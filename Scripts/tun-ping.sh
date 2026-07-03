#!/bin/bash
# tun-ping.sh — temporarily route a set of server IPs via the physical gateway
# (bypassing the tun) so latency probes measure the real RTT, not the local
# tun2socks accept. Run as root via the NOPASSWD sudoers rule.
#
# Usage:
#   tun-ping.sh add <comma-separated-ipv4s>
#   tun-ping.sh del <comma-separated-ipv4s>
set -uo pipefail

ACTION="${1:-}"
IPS_CSV="${2:-}"
STATE_FILE="/tmp/beacon-tun.state"
PINGPIN_FILE="/tmp/beacon-ping.pinned"

# Physical gateway from the recorded TUN state (fallback to live lookup).
GW="$(awk -F= '/^ORIG_GW=/{print $2}' "${STATE_FILE}" 2>/dev/null)"
if [ -z "${GW}" ]; then
  GW="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2; exit}')"
fi
[ -z "${GW}" ] && exit 1

# Validate each IP before touching the routing table.
IFS=',' read -ra IPS <<< "${IPS_CSV}"
for ip in "${IPS[@]}"; do
  [ -z "${ip}" ] && continue
  printf '%s' "${ip}" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' || exit 2
done

case "${ACTION}" in
  add)
    : > "${PINGPIN_FILE}"
    for ip in "${IPS[@]}"; do
      [ -z "${ip}" ] && continue
      # Skip IPs already pinned for the active connection (don't disturb them).
      if grep -qx "${ip}" /tmp/beacon-tun.pinned 2>/dev/null; then continue; fi
      route -n add -host "${ip}" "${GW}" >/dev/null 2>&1 || true
      echo "${ip}" >> "${PINGPIN_FILE}"
    done
    ;;
  del)
    if [ -f "${PINGPIN_FILE}" ]; then
      while IFS= read -r ip; do
        [ -z "${ip}" ] && continue
        route -n delete -host "${ip}" >/dev/null 2>&1 || true
      done < "${PINGPIN_FILE}"
      rm -f "${PINGPIN_FILE}"
    fi
    ;;
  *)
    exit 3
    ;;
esac
exit 0
