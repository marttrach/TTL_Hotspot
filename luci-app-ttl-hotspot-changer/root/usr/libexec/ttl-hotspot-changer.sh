#!/bin/sh

# ttl-hotspot-changer TTL helper
# This script can be run manually or via /etc/init.d/ttl-hotspot-changer

CONFIG="ttl-hotspot-changer.config"
LOG_FILE="/tmp/ttl-hotspot-changer.log"
TABLE_NAME="ttlfix"
CHAIN_PREROUTING="prerouting"
CHAIN_POSTROUTING="postrouting"
EFFECTIVE_MODE=""
CUSTOM_TTL=""
TTL_MODE=""
SMART=0
MODE=""
WAN_IF=""
LAN_IF=""
MWAN3_MODE=0
MWAN3_INTERFACE=""
MWAN3_CHECK_INTERVAL=30
ACTION="${1:-start}"

case "$ACTION" in
status|log)
	;;
*)
	exec >>"$LOG_FILE" 2>&1
	;;
esac

log() {
	local level="${1:-INFO}"
	shift
	local line
	line=$(printf '[%s] [%s] %s' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*")

	if [ "$ACTION" = "status" ] || [ "$ACTION" = "log" ]; then
		printf '%s\n' "$line" >>"$LOG_FILE"
		printf '%s\n' "$line"
	else
		printf '%s\n' "$line"
	fi
}

load_config() {
	MODE="$(uci -q get ${CONFIG}.mode)"
	TTL_MODE="$(uci -q get ${CONFIG}.ttl_mode)"
	CUSTOM_TTL="$(uci -q get ${CONFIG}.custom_ttl)"
	SMART="$(uci -q get ${CONFIG}.smart)"
	MWAN3_MODE="$(uci -q get ${CONFIG}.mwan3_mode)"
	MWAN3_INTERFACE="$(uci -q get ${CONFIG}.mwan3_interface)"
	MWAN3_CHECK_INTERVAL="$(uci -q get ${CONFIG}.mwan3_check_interval)"

	[ -z "$MODE" ] && MODE="sub"
	[ -z "$TTL_MODE" ] && TTL_MODE="force55"
	[ -z "$CUSTOM_TTL" ] && CUSTOM_TTL="65"
	[ "$SMART" = "1" ] && SMART=1 || SMART=0
	[ "$MWAN3_MODE" = "1" ] && MWAN3_MODE=1 || MWAN3_MODE=0
	[ -z "$MWAN3_CHECK_INTERVAL" ] && MWAN3_CHECK_INTERVAL=30
}

get_ifnames() {
	WAN_IF="$(ubus call network.interface.5g_mbim status 2>/dev/null | jsonfilter -e '@["l3_device"]' 2>/dev/null)"
	[ -z "$WAN_IF" ] && WAN_IF="$(uci -q get network.wan.device || uci -q get network.wan.ifname || echo wwan0)"
	LAN_IF="$(uci -q get network.lan.device || uci -q get network.lan.ifname || echo br-lan)"

	log INFO "Interface detection => WAN_IF=${WAN_IF}, LAN_IF=${LAN_IF}"
}

detect_topology() {
	local detect_mode="$MODE"
	local needs_auto=0

	[ "$MODE" = "auto" ] && needs_auto=1
	[ "$SMART" -eq 1 ] && needs_auto=1

	get_ifnames

	if [ "$needs_auto" -eq 1 ]; then
		if ip route | grep -q "default.*dev ${WAN_IF}"; then
			detect_mode="main"
			log INFO "Detected default route on ${WAN_IF}, using MAIN mode"
		else
			detect_mode="sub"
			log INFO "Default route not on ${WAN_IF}, using SUB mode"
		fi

		if [ "$MODE" = "auto" ]; then
			uci set ${CONFIG}.mode="$detect_mode"
			uci commit ttl-hotspot-changer
			log INFO "Stored detected mode=${detect_mode} into UCI"
		fi
	fi

	EFFECTIVE_MODE="$detect_mode"
	[ -z "$EFFECTIVE_MODE" ] && EFFECTIVE_MODE="$MODE"
}

ttl_value_from_mode() {
	case "$TTL_MODE" in
	force55)
		printf '%s' "55"
		;;
	smart|normal)
		printf '%s' "65"
		;;
	custom)
		printf '%s' "${CUSTOM_TTL}"
		;;
	*)
		printf '%s' "55"
		;;
	esac
}

prepare_table() {
	nft flush table inet "${TABLE_NAME}" 2>/dev/null
	nft delete table inet "${TABLE_NAME}" 2>/dev/null

	nft add table inet "${TABLE_NAME}"
	nft add chain inet "${TABLE_NAME}" "${CHAIN_PREROUTING}" '{ type filter hook prerouting priority mangle ; }'
	nft add chain inet "${TABLE_NAME}" "${CHAIN_POSTROUTING}" '{ type filter hook postrouting priority mangle ; }'
}

apply_ttl_spoof() {
	local ttl_value

	ttl_value="$(ttl_value_from_mode)"

	log INFO "Mode=${EFFECTIVE_MODE} TTL_MODE=${TTL_MODE} TTL_VALUE=${ttl_value}"

	prepare_table

	if [ "$EFFECTIVE_MODE" = "main" ]; then
		nft add rule inet "${TABLE_NAME}" "${CHAIN_POSTROUTING}" oifname "${WAN_IF}" ip ttl set "${ttl_value}"
		nft add rule inet "${TABLE_NAME}" "${CHAIN_PREROUTING}" iifname "${WAN_IF}" ip ttl set "${ttl_value}"
		nft add rule inet "${TABLE_NAME}" "${CHAIN_POSTROUTING}" oifname "${WAN_IF}" ip6 hoplimit set "${ttl_value}"
		log INFO "TTL spoof applied on WAN (${WAN_IF}) as MAIN router"
	else
		nft add rule inet "${TABLE_NAME}" "${CHAIN_PREROUTING}" iifname "${LAN_IF}" ip ttl set "${ttl_value}"
		nft add rule inet "${TABLE_NAME}" "${CHAIN_POSTROUTING}" oifname "${LAN_IF}" ip ttl set "${ttl_value}"
		nft add rule inet "${TABLE_NAME}" "${CHAIN_PREROUTING}" iifname "${LAN_IF}" ip6 hoplimit set "${ttl_value}"
		log INFO "TTL spoof applied on LAN (${LAN_IF}) as SUB router"
	fi
}

show_rules() {
	log INFO "Dumping ${TABLE_NAME} rules"
	nft list table inet "${TABLE_NAME}" 2>/dev/null || log WARN "No nftable named ${TABLE_NAME} present"
}

clear_rules() {
	nft flush table inet "${TABLE_NAME}" 2>/dev/null
	nft delete table inet "${TABLE_NAME}" 2>/dev/null
	log INFO "TTL spoof rules removed"
}

# Check if the mwan3 target interface is currently ACTIVE in a policy
# "online" is not enough — the interface must be actively carrying traffic.
# mwan3 policy output shows active interfaces as: " interface_name (N%)"
# Returns 0 if interface is active in a policy, 1 otherwise
mwan3_check() {
	local iface="$1"

	if ! command -v mwan3 >/dev/null 2>&1; then
		log WARN "mwan3 command not found, cannot check interface status"
		return 1
	fi

	# Quick check: if interface is offline, skip the heavier policy check
	local state_file="/var/run/mwan3/iface_state/${iface}"
	if [ -f "$state_file" ]; then
		local state
		state=$(cat "$state_file" 2>/dev/null)
		if [ "$state" != "online" ]; then
			log INFO "mwan3: Interface $iface tracking state = $state (offline, skipping)"
			return 1
		fi
		log INFO "mwan3: Interface $iface is online, checking policy"
	fi

	# Parse mwan3 status to check if interface is active in any ipv4 policy
	# Active entries look like: " modem1 (100%)" or " modem1 (50%)"
	local mwan3_output
	mwan3_output=$(mwan3 status 2>/dev/null)

	if [ -z "$mwan3_output" ]; then
		log WARN "mwan3: Failed to get mwan3 status"
		return 1
	fi

	# Extract ipv4 policy section and check for active interface
	local policy_match
	policy_match=$(echo "$mwan3_output" | sed -n '/^Current ipv4 policies:/,/^Current ipv6 policies:/p' | grep -E "^[[:space:]]+${iface}[[:space:]]+\([0-9]+%\)")

	if [ -n "$policy_match" ]; then
		log INFO "mwan3: Interface $iface is ACTIVE in policy:$policy_match"
		return 0
	else
		log INFO "mwan3: Interface $iface is online but NOT active in any policy (another interface is handling traffic)"
		return 1
	fi
}


start_worker() {
	load_config

	# mwan3 mode: only apply TTL when target interface is connected
	if [ "$MWAN3_MODE" -eq 1 ]; then
		if [ -z "$MWAN3_INTERFACE" ]; then
			log WARN "mwan3_mode enabled but mwan3_interface not set, falling back to normal mode"
		elif ! mwan3_check "$MWAN3_INTERFACE"; then
			log INFO "mwan3: Target interface $MWAN3_INTERFACE not connected, TTL rules not applied"
			clear_rules
			return 0
		else
			log INFO "mwan3: Target interface $MWAN3_INTERFACE is connected, applying TTL rules"
		fi
	fi

	detect_topology
	apply_ttl_spoof
	show_rules
}

stop_worker() {
	clear_rules
}

watch_worker() {
	load_config

	if [ "$MWAN3_MODE" -ne 1 ]; then
		log WARN "watch: mwan3_mode is not enabled, nothing to watch"
		return 1
	fi

	if [ -z "$MWAN3_INTERFACE" ]; then
		log WARN "watch: mwan3_interface not set, nothing to watch"
		return 1
	fi

	log INFO "watch: Starting mwan3 policy watcher for interface=$MWAN3_INTERFACE interval=${MWAN3_CHECK_INTERVAL}s"

	local ttl_applied=0

	# Check if TTL rules are already present
	if nft list table inet "${TABLE_NAME}" >/dev/null 2>&1; then
		ttl_applied=1
	fi

	while true; do
		if mwan3_check "$MWAN3_INTERFACE"; then
			# Interface is active in policy — apply TTL if not yet applied
			if [ "$ttl_applied" -eq 0 ]; then
				log INFO "watch: Interface $MWAN3_INTERFACE became active, applying TTL rules"
				detect_topology
				apply_ttl_spoof
				show_rules
				ttl_applied=1
			fi
		else
			# Interface is NOT active — remove TTL if applied
			if [ "$ttl_applied" -eq 1 ]; then
				log INFO "watch: Interface $MWAN3_INTERFACE no longer active, removing TTL rules"
				clear_rules
				ttl_applied=0
			fi
		fi

		sleep "$MWAN3_CHECK_INTERVAL"
	done
}

usage() {
	cat <<'EOF'
ttl-hotspot-changer helper

Usage: ttl-hotspot-changer.sh <start|stop|restart|watch|status|log>
EOF
}

case "$ACTION" in
start)
	log INFO "Starting ttl-hotspot-changer worker"
	start_worker
	;;
stop)
	log INFO "Stopping ttl-hotspot-changer worker"
	stop_worker
	;;
restart)
	log INFO "Restarting ttl-hotspot-changer worker"
	stop_worker
	start_worker
	;;
watch)
	log INFO "Starting ttl-hotspot-changer mwan3 watcher"
	watch_worker
	;;
status)
	show_rules
	;;
log)
	tail -n 200 "$LOG_FILE" 2>/dev/null
	;;
*)
	usage
	exit 1
	;;
esac

