local sys = require "luci.sys"

local m = Map("ttl-hotspor-changer", translate("ttl-hotspor-changer"),
	translate("Configure TTL/Hop-Limit spoofing rules, topology detection and helper scripts."))

local s = m:section(NamedSection, "config", "ttl-hotspor-changer", translate("Service & Parameters"))
s.anonymous = false
s.addremove = false
s:tab("general", translate("Control"))
s:tab("topology", translate("Topology & Mode"))
s:tab("ttl", translate("TTL Settings"))

local enable = s:taboption("general", Flag, "enable", translate("Enable service"),
	translate("Apply TTL/Hop-Limit nftables rules when enabled, remove them when disabled."))
enable.rmempty = false
enable.default = enable.enabled

function enable.write(self, section, value)
	Flag.write(self, section, value)
	if value == "1" then
		sys.call("/etc/init.d/ttl-hotspor-changer enable >/dev/null 2>&1")
		sys.call("/etc/init.d/ttl-hotspor-changer start >/dev/null 2>&1")
	else
		sys.call("/etc/init.d/ttl-hotspor-changer stop >/dev/null 2>&1")
		sys.call("/etc/init.d/ttl-hotspor-changer disable >/dev/null 2>&1")
	end
end

local smart = s:taboption("general", Flag, "smart", translate("Smart detection"),
	translate("Automatically detect topology and adjust rules when possible."))
smart.rmempty = false
smart.default = smart.enabled

local mode = s:taboption("topology", ListValue, "mode", translate("Operation mode"),
	translate("Choose whether TTL is applied on WAN (main router) or LAN (sub router)."))
mode:value("main", translate("Main router"))
mode:value("sub", translate("Sub router"))
mode:value("auto", translate("Auto detect"))
mode.default = "sub"

local ttl_mode = s:taboption("ttl", ListValue, "ttl_mode", translate("TTL mode"))
ttl_mode:value("force55", "Force 55")
ttl_mode:value("normal", "Normal 65")
ttl_mode:value("smart", translate("Smart 65"))
ttl_mode:value("custom", translate("Custom value"))
ttl_mode.default = "custom"

local custom_ttl = s:taboption("ttl", Value, "custom_ttl", translate("Custom TTL value"))
custom_ttl.datatype = "range(1,255)"
custom_ttl.placeholder = "65"
custom_ttl.default = "65"
custom_ttl:depends("ttl_mode", "custom")

local dep_section = m:section(SimpleSection)
dep_section.template = "ttl-hotspor-changer/depctl"

return m
