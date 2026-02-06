module("luci.controller.ttl-hotspot-changer", package.seeall)

local http = require "luci.http"
local util = require "luci.util"
local sys = require "luci.sys"
local fs = require "nixio.fs"

local LOG_FILE = "/tmp/ttl-hotspot-changer.log"

function index()
	if not fs.access("/etc/config/ttl-hotspot-changer") then
		return
	end

	local page = entry({"admin", "network", "ttl-hotspot-changer"}, firstchild(), _("ttl-hotspot-changer"), 55)
	page.dependent = false

	entry({"admin", "network", "ttl-hotspot-changer", "settings"}, cbi("ttl-hotspot-changer"), _("Settings"), 10).leaf = true
	entry({"admin", "network", "ttl-hotspot-changer", "logs"}, template("ttl-hotspot-changer/logs"), _("Logs"), 20).leaf = true

	entry({"admin", "network", "ttl-hotspot-changer", "action", "log"}, call("action_log")).leaf = true
	entry({"admin", "network", "ttl-hotspot-changer", "action", "clear_log"}, call("action_clear_log")).leaf = true
end

function action_log()
	local log = ""

	if fs.access(LOG_FILE) then
		log = util.trim(sys.exec("tail -n 200 " .. LOG_FILE .. " 2>/dev/null")) or ""
	end

	http.prepare_content("application/json")
	http.write_json({ log = log })
end

function action_clear_log()
	if fs.access(LOG_FILE) then
		fs.writefile(LOG_FILE, "")
	end

	http.prepare_content("application/json")
	http.write_json({ success = true })
end

