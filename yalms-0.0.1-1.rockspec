rockspec_format = "3.0"
package = "yalms"
version = "0.0.1-1"

description = {
	summary = "Yet Another Set of Lua Modules",
	license = "GPL-3.0",
	maintainer = "Ahmad Raza",
	labels = {
		"cr",
		"env",
		"exec",
		"fs",
		"json",
		"str",
		"tbl",
		"time",
		"utils",
	},
}

dependencies = {
	"lua>=5.1",
}

source = {
	url = "https://github.com/ar-at-localhost/yamls/archive/refs/tags/449b387509469fc02c7b4b159221e9a6c1d84b8a.zip",
}

build = {
	type = "builtin",
	modules = {
		["yalms.fs_watch"] = "lua/yalms/fs_watch.lua",
		["yalms.str"] = "lua/yalms/str.lua",
		["yalms.fs"] = "lua/yalms/fs.lua",
		["yalms.json"] = "lua/yalms/json.lua",
		["yalms.events"] = "lua/yalms/events/init.lua",
		["yalms.exec"] = "lua/yalms/exec.lua",
		["yalms.env"] = "lua/yalms/env.lua",
		["yalms.tbl"] = "lua/yalms/tbl.lua",
		["yalms.time"] = "lua/yalms/time.lua",
		yalms = "lua/yalms/init.lua",
		["yalms.cr"] = "lua/yalms/cr/init.lua",
	},
}
