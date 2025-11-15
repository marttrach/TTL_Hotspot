include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ttl-hotspot-changer
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_MAINTAINER:=TTL Hotspot Maintainers

LUCI_TITLE:=LuCI support for ttl-hotspot-changer TTL spoof
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+luci-base +nftables +jsonfilter +ubus +uci +kmod-nft-core +kmod-nft-nat +kmod-nft-offload
LUCI_DESCRIPTION:=LuCI ??™åž¢?—ï—¼??æ½›æ£??TTL spoof ????¬î¼½??˜î??·æ?î¤˜è¾£??
define Package/$(PKG_NAME)/conffiles
/etc/config/ttl-hotspot-changer
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] && exit 0

chmod 755 /etc/init.d/ttl-hotspot-changer >/dev/null 2>&1
chmod 755 /usr/libexec/ttl-hotspot-changer.sh >/dev/null 2>&1
chmod 755 /usr/libexec/ttl-hotspot-changer-depctl.sh >/dev/null 2>&1

for f in /etc/init.d/ttl-hotspot-changer \
	/usr/libexec/ttl-hotspot-changer.sh \
	/usr/libexec/ttl-hotspot-changer-depctl.sh; do
	[ -f "$$f" ] && sed -i 's/\r$$//' "$$f"
done

CFG=/etc/config/ttl-hotspot-changer
if [ ! -f "$$CFG" ]; then
cat <<'EOF' > "$$CFG"
config ttl-hotspot-changer 'config'
	option enable '1'
	option mode 'sub'
	option ttl_mode 'custom'
	option smart '1'
	option custom_ttl '65'
EOF
fi

ENABLED=$$(uci -q get ttl-hotspot-changer.config.enable)
if [ "$$ENABLED" = "1" ]; then
	/etc/init.d/ttl-hotspot-changer enable >/dev/null 2>&1
	/etc/init.d/ttl-hotspot-changer start >/dev/null 2>&1
else
	/etc/init.d/ttl-hotspot-changer disable >/dev/null 2>&1
fi
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] && exit 0
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
exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] && exit 0

case "$$1" in
upgrade|abort-upgrade)
	exit 0
	;;
esac

rm -f /etc/config/ttl-hotspot-changer
rm -f /tmp/ttl-hotspot-changer.log
exit 0
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot will handle

