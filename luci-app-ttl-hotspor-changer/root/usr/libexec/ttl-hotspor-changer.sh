#!/bin/sh

# ttl-hotspor-changer TTL helper
# This script can be run manually or via /etc/init.d/ttl-hotspor-changer

CONFIG="ttl-hotspor-changer.config"
LOG_FILE="/tmp/ttl-hotspor-changer.log"
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

	[ -z "$MODE" ] && MODE="sub"
	[ -z "$TTL_MODE" ] && TTL_MODE="force55"
	[ -z "$CUSTOM_TTL" ] && CUSTOM_TTL="65"
	[ "$SMART" = "1" ] && SMART=1 || SMART=0
}

get_ifnames() {
	WAN_IF="$(ubus call network.interface.5g_mbim status 2>/dev/null | jsonfilter -e '@["l3_device"]')"
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
			uci commit ttl-hotspor-changer
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

start_worker() {
	load_config
	detect_topology
	apply_ttl_spoof
	show_rules
}

stop_worker() {
	clear_rules
}

usage() {
	cat <<'EOF'
ttl-hotspor-changer helper

Usage: ttl-hotspor-changer.sh <start|stop|restart|status|log>
EOF
}

case "$ACTION" in
start)
	log INFO "Starting ttl-hotspor-changer worker"
	start_worker
	;;
stop)
	log INFO "Stopping ttl-hotspor-changer worker"
	stop_worker
	;;
restart)
	log INFO "Restarting ttl-hotspor-changer worker"
	stop_worker
	start_worker
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
