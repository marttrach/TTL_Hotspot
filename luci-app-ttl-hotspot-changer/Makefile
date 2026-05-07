include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ttl-hotspot-changer
PKG_VERSION:=3.1.0
PKG_RELEASE:=3
PKG_LICENSE:=MIT
PKG_MAINTAINER:=TTL Hotspot Maintainers

LUCI_TITLE:=LuCI support for ttl-hotspot-changer TTL spoof
LUCI_PKGARCH:=all
# Dependencies will be auto-downloaded by OpenWrt package manager
LUCI_DEPENDS:=+luci-base +nftables +jsonfilter +ubus +uci +kmod-nft-core +kmod-nft-nat +kmod-nft-offload
LUCI_DESCRIPTION:=LuCI interface for TTL spoof configuration with mwan3 failover support

define Package/$(PKG_NAME)/conffiles
/etc/config/ttl-hotspot-changer
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] && exit 0

# Fix permissions (in case package manager didn't preserve them)
chmod 755 /etc/init.d/ttl-hotspot-changer >/dev/null 2>&1
chmod 755 /usr/libexec/ttl-hotspot-changer.sh >/dev/null 2>&1
chmod 755 /etc/hotplug.d/mwan3/20-ttl-hotspot-changer >/dev/null 2>&1
chmod 755 /etc/uci-defaults/99-ttl-hotspot-changer >/dev/null 2>&1

# Strip Windows CR (cross-platform build safety)
for f in /etc/init.d/ttl-hotspot-changer \
	/usr/libexec/ttl-hotspot-changer.sh \
	/etc/hotplug.d/mwan3/20-ttl-hotspot-changer \
	/etc/uci-defaults/99-ttl-hotspot-changer; do
	[ -f "$$f" ] && sed -i 's/\r$$//' "$$f"
done

# Config initialization and service enable/start are handled by
# /etc/uci-defaults/99-ttl-hotspot-changer (runs after system is fully booted)
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] && exit 0

# Stop service and remove nftables rules
if [ -x /etc/init.d/ttl-hotspot-changer ]; then
	/etc/init.d/ttl-hotspot-changer stop >/dev/null 2>&1 || true
	if command -v ubus >/dev/null 2>&1 && ubus call service list '{ "name": "ttl-hotspot-changer" }' >/dev/null 2>&1; then
		/etc/init.d/ttl-hotspot-changer disable >/dev/null 2>&1 || true
	else
		for link in /etc/rc.d/*ttl-hotspot-changer; do
			[ -L "$$link" ] && rm -f "$$link"
		done
	fi
fi

# Clean up nftables rules
if command -v nft >/dev/null 2>&1; then
	nft flush table inet ttlfix >/dev/null 2>&1 || true
	nft delete table inet ttlfix >/dev/null 2>&1 || true
fi
exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] && exit 0

# Skip cleanup on upgrade
case "$$1" in
upgrade|abort-upgrade)
	exit 0
	;;
esac

# Remove all generated files
rm -f /etc/config/ttl-hotspot-changer
rm -f /tmp/ttl-hotspot-changer.log

# Remove any leftover rc.d symlinks
for link in /etc/rc.d/*ttl-hotspot-changer; do
	[ -L "$$link" ] && rm -f "$$link"
done

# Final cleanup of nftables (in case prerm failed)
if command -v nft >/dev/null 2>&1; then
	nft flush table inet ttlfix >/dev/null 2>&1 || true
	nft delete table inet ttlfix >/dev/null 2>&1 || true
fi
exit 0
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot will handle
