local sys = require "luci.sys"

local m = Map("ttl-hotspot-changer", translate("TTL Spoofing Settings"),
	translate("Configure TTL/Hop-Limit spoofing rules, topology detection and helper scripts."))

local hero = m:section(SimpleSection)
hero.template = "ttl-hotspot-changer/hero"

local s = m:section(NamedSection, "config", "ttl-hotspot-changer", translate("TTL Spoofing Settings"))
s.anonymous = false
s.addremove = false

local enable = s:option(Flag, "enable", translate("Enable"))
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

-- mwan3 Integration Section
local mwan3_section = m:section(NamedSection, "config", "ttl-hotspot-changer", translate("mwan3 Integration"))
mwan3_section.anonymous = true
mwan3_section.addremove = false

local mwan3_mode = mwan3_section:option(Flag, "mwan3_mode", translate("Enable mwan3 Mode"))
mwan3_mode.rmempty = false
mwan3_mode.default = mwan3_mode.disabled
mwan3_mode.description = translate("Only apply TTL rules when the specified interface is connected via mwan3 failover. Requires mwan3 package.")

local mwan3_interface = mwan3_section:option(Value, "mwan3_interface", translate("Target Interface"))
mwan3_interface.placeholder = "modem1"
mwan3_interface.default = "modem1"
mwan3_interface:depends("mwan3_mode", "1")
mwan3_interface.description = translate("The mwan3 interface name that requires TTL spoofing. TTL rules will only be applied when this interface becomes active.")

-- Dynamically populate mwan3 interfaces if available
local uci = require "luci.model.uci".cursor()
uci:foreach("mwan3", "interface", function(s)
	if s[".name"] then
		mwan3_interface:value(s[".name"], s[".name"])
	end
end)

return m

