module("luci.controller.ttl-hotspot-changer", package.seeall)

local http = require "luci.http"
local util = require "luci.util"
local sys = require "luci.sys"
local fs = require "nixio.fs"

local LOG_FILE = "/tmp/ttl-hotspot-changer.log"
local DEP_HELPER = "/usr/libexec/ttl-hotspot-changer-depctl.sh"

function index()
	if not fs.access("/etc/config/ttl-hotspot-changer") then
		return
	end

	local page = entry({"admin", "network", "ttl-hotspot-changer"}, firstchild(), _("ttl-hotspot-changer"), 55)
	page.dependent = false

	entry({"admin", "network", "ttl-hotspot-changer", "settings"}, cbi("ttl-hotspot-changer"), _("Settings"), 10).leaf = true
	entry({"admin", "network", "ttl-hotspot-changer", "logs"}, template("ttl-hotspot-changer/logs"), _("Logs"), 20).leaf = true

	entry({"admin", "network", "ttl-hotspot-changer", "action", "log"}, call("action_log")).leaf = true
	entry({"admin", "network", "ttl-hotspot-changer", "action", "install_deps"}, call("action_install_deps")).leaf = true
	entry({"admin", "network", "ttl-hotspot-changer", "action", "remove_deps"}, call("action_remove_deps")).leaf = true
end

local function run_depctl(op)
	if not fs.access(DEP_HELPER, "x") then
		return 127, "Dependency helper missing"
	end

	local output = util.exec(string.format("%s %s 2>&1", DEP_HELPER, op))
	local code = tonumber(output:match("__DEPCTL_EXIT:(%d+)") or "")
	output = output:gsub("__DEPCTL_EXIT:%d+%s*", "")
	return code or 0, util.trim(output)
end

function action_install_deps()
	http.prepare_content("application/json")
	local code, output = run_depctl("install")
	http.write_json({ code = code, output = output })
end

function action_remove_deps()
	http.prepare_content("application/json")
	local code, output = run_depctl("remove")
	http.write_json({ code = code, output = output })
end

function action_log()
	local log = ""

	if fs.access(LOG_FILE) then
		log = util.trim(sys.exec("tail -n 200 " .. LOG_FILE .. " 2>/dev/null")) or ""
	end

	http.prepare_content("application/json")
	http.write_json({ log = log })
end

