package = "lua-schema"
version = "scm-1"
source = {
   url = "git://github.com/sschoener/lua-schema"
}
description = {
   summary = "A simple package to check Lua-data against schemata.",
   detailed = [[
      A simple package to check Lua-data against schemata. The package is written
      entirely in Lua (5.2) and has no further dependencies. It is designed to be
      easily extensible.
   ]],
   homepage = "http://github.com/sschoener/lua-schema",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.2",
}
build = {
   type = "builtin",
   modules = {
      schema = "schema.lua"
   }
}
