package = "halo"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-halo.git"
}
description = {
    summary = "",
    detailed = [[]],
    homepage = "https://github.com/mah0x211/lua-halo", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "util"
}
build = {
    type = "builtin",
    modules = {
        halo = "halo.lua"
    }
}

