package = "halo"
version = "1.1.4-1"
source = {
    url = "git://github.com/mah0x211/lua-halo.git",
    tag = "v1.1.4"
}
description = {
    summary = "Simple OOP Library For Lua",
    homepage = "https://github.com/mah0x211/lua-halo", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "util >= 1.3.3"
}
build = {
    type = "builtin",
    modules = {
        halo = "halo.lua"
    }
}

