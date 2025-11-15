local sys = require "luci.sys"

local m = Map("ttl-hotspot-changer", translate("TTL Spoofing Settings"),
	translate("Configure TTL/Hop-Limit spoofing rules, topology detection and helper scripts."))

local hero = m:section(SimpleSection)
hero.template = "ttl-hotspot-changer/hero"

local s = m:section(NamedSection, "config", "ttl-hotspot-changer", translate("TTL Spoofing Settings"))
s.anonymous = false
s.addremove = false

local enable = s:option(Flag, "enable", translate("±Ò¥Î"))
enable.rmempty = false
enable.default = enable.enabled

function enable.write(self, section, value)
	Flag.write(self, section, value)
	if value == "1" then
		sys.call("/etc/init.d/ttl-hotspot-changer enable >/dev/null 2>&1")
		sys.call("/etc/init.d/ttl-hotspot-changer start >/dev/null 2>&1")
	else
		sys.call("/etc/init.d/ttl-hotspot-changer stop >/dev/null 2>&1")
		sys.call("/etc/init.d/ttl-hotspot-changer disable >/dev/null 2>&1")
	end
end

local smart = s:option(Flag, "smart", translate("Auto detect topology"))
smart.rmempty = false
smart.default = smart.enabled
smart.description = translate("Let ttl-hotspot-changer detect whether your router is acting as the main router or a sub router.")

local mode = s:option(ListValue, "mode", translate("Router Mode"))
mode:value("main", translate("Force Main Router"))
mode:value("sub", translate("Force Sub Router"))
mode:value("auto", translate("Auto detect"))
mode.default = "sub"

local ttl_mode = s:option(ListValue, "ttl_mode", translate("TTL Emulation Mode"))
ttl_mode:value("force55", "Force 55")
ttl_mode:value("normal", "Normal 65")
ttl_mode:value("smart", translate("Smart 65"))
ttl_mode:value("custom", translate("Custom TTL"))
ttl_mode.default = "custom"

local custom_ttl = s:option(Value, "custom_ttl", translate("Custom TTL Value (1~255)"))
custom_ttl.datatype = "range(1,255)"
custom_ttl.placeholder = "65"
custom_ttl.default = "65"
custom_ttl:depends("ttl_mode", "custom")

local dep_section = m:section(SimpleSection)
dep_section.template = "ttl-hotspot-changer/depctl"

return m

