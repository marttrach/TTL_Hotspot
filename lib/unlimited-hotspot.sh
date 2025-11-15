#!/bin/sh

LOG_FILE="/tmp/unlimited-hotspot.log"
exec >> "$LOG_FILE" 2>&1
echo "[#] $(date '+%Y-%m-%d %H:%M:%S') Unlimited-Hotspot 啟動"

get_ifnames() {
    WAN_IF=$(ubus call network.interface.5g_mbim status 2>/dev/null | jsonfilter -e '@["l3_device"]')
    [ -z "$WAN_IF" ] && WAN_IF=$(uci -q get network.wan.device || uci -q get network.wan.ifname || echo wwan0)
    LAN_IF=$(uci -q get network.lan.device || uci -q get network.lan.ifname || echo br-lan)
    echo "[+] WAN_IF=$WAN_IF LAN_IF=$LAN_IF"
}

detect_topology() {
    MODE=$(uci -q get unlimited-hotspot.config.mode)
    TTL_MODE=$(uci -q get unlimited-hotspot.config.ttl_mode)
    CUSTOM_TTL=$(uci -q get unlimited-hotspot.config.custom_ttl)
    get_ifnames

    if [ "$MODE" = "auto" ] || [ -z "$MODE" ]; then
        if ip route | grep -q "default.*dev $WAN_IF"; then
            echo "[+] 偵測到 $WAN_IF 為 default route，設定為主路由"
            MODE="main"
        else
            echo "[+] 未偵測到 $WAN_IF 為 default route，設定為子路由"
            MODE="sub"
        fi
        uci set unlimited-hotspot.config.mode="$MODE"
        uci commit unlimited-hotspot
    fi

    if [ -z "$TTL_MODE" ]; then
        TTL_MODE="force55"
        uci set unlimited-hotspot.config.ttl_mode="$TTL_MODE"
        uci commit unlimited-hotspot
        echo "[+] 未設定 TTL_MODE，自動套用 TTL_MODE=force55"
    fi

    export MODE
    export TTL_MODE
    export WAN_IF
    export LAN_IF
    export CUSTOM_TTL
}

apply_ttl_spoof() {
    echo "[+] 模式: $MODE"
    echo "[+] TTL 模式: ${TTL_MODE:-normal}"

    nft flush table inet ttlfix 2>/dev/null
    nft delete table inet ttlfix 2>/dev/null
    nft add table inet ttlfix
    nft add chain inet ttlfix prerouting { type filter hook prerouting priority mangle \; }
    nft add chain inet ttlfix postrouting { type filter hook postrouting priority mangle \; }

    case "$TTL_MODE" in
        force55)
            TTL_VALUE=55
            ;;
        smart|normal)
            TTL_VALUE=65
            ;;
        custom)
            TTL_VALUE="${CUSTOM_TTL}"
            echo "[+] 使用自訂 TTL 值: $TTL_VALUE"
            ;;
        *)
            TTL_VALUE=55
            ;;
    esac

    if [ "$MODE" = "main" ]; then
        nft add rule inet ttlfix postrouting oifname "$WAN_IF" ip ttl set "$TTL_VALUE"
        nft add rule inet ttlfix prerouting iifname "$WAN_IF" ip ttl set "$TTL_VALUE"
        nft add rule inet ttlfix postrouting oifname "$WAN_IF" ip6 hoplimit set "$TTL_VALUE"
        echo "[+] TTL: 主路由 套用 TTL+=2"
    else
        nft add rule inet ttlfix prerouting iifname "$LAN_IF" ip ttl set "$TTL_VALUE"
        nft add rule inet ttlfix postrouting oifname "$LAN_IF" ip ttl set "$TTL_VALUE"
        nft add rule inet ttlfix prerouting iifname "$LAN_IF" ip6 hoplimit set "$TTL_VALUE"
        echo "[+] TTL: 子路由 套用 TTL=$TTL_VALUE"
    fi
}

show_rules() {
    echo "[+] 當前 ttlfix 規則如下："
    nft list table inet ttlfix 2>/dev/null || echo "[!] 無 ttlfix 規則"
}

clear_rules() {
    nft flush table inet ttlfix 2>/dev/null
    nft delete table inet ttlfix 2>/dev/null
    echo "[+] TTL spoof 規則已清除"
}
