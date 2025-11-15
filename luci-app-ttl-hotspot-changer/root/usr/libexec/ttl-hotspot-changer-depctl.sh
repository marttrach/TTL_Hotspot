#!/bin/sh

PKG_LIST="kmod-nft-core kmod-nft-offload kmod-nft-nat nftables jsonfilter"
LOG_FILE="/tmp/ttl-hotspot-changer-depctl.log"

log() {
	local level="${1:-INFO}"
	shift
	printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" | tee -a "$LOG_FILE"
}

ensure_logfile() {
	[ -f "$LOG_FILE" ] || : >"$LOG_FILE"
}

opkg_present() {
	opkg status "$1" >/dev/null 2>&1
}

install_packages() {
	local failed=0

	log INFO "Updating package lists"
	if ! opkg update >>"$LOG_FILE" 2>&1; then
		log ERROR "opkg update failed, continuing anyway"
	fi

	for pkg in $PKG_LIST; do
		if opkg_present "$pkg"; then
			log INFO "Package $pkg already installed"
			continue
		fi
		log INFO "Installing $pkg"
		if ! opkg install "$pkg" >>"$LOG_FILE" 2>&1; then
			failed=1
			log ERROR "Failed to install $pkg"
		else
			log INFO "Installed $pkg"
		fi
	done

	return $failed
}

remove_packages() {
	local failed=0

	for pkg in $PKG_LIST; do
		if ! opkg_present "$pkg"; then
			log INFO "Package $pkg not found, skipping"
			continue
		fi
		log INFO "Removing $pkg"
		if ! opkg remove "$pkg" >>"$LOG_FILE" 2>&1; then
			failed=1
			log ERROR "Failed to remove $pkg"
		else
			log INFO "Removed $pkg"
		fi
	done

	return $failed
}

ensure_logfile

ACTION="${1:-install}"
EXIT_CODE=0

case "$ACTION" in
install)
	install_packages || EXIT_CODE=$?
	;;
remove)
	remove_packages || EXIT_CODE=$?
	;;
*)
	log ERROR "Unknown action: $ACTION"
	EXIT_CODE=1
	;;
esac

log INFO "Dependency helper finished with code $EXIT_CODE"
printf '__DEPCTL_EXIT:%s\n' "$EXIT_CODE"
exit "$EXIT_CODE"

