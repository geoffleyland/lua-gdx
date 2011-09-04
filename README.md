# lua-gdx

## 1. What?

lua-gdx is a small set of lua utilities for manipulating [GAMS](http://www.gams.com) GDX files.
It uses the [LuaJIT](http://luajit.org) [FFI library](http://luajit.org/ext_ffi.html) to directly bind to the GDX library.
lua-gdx in released under the [MIT Licence](http://www.opensource.org/licenses/mit-license.php).

At the moment, documentation of `gdx.lua` is limited to the example in `gdxdump.lua`.


## 2. Requirements

- GAMS or at least the GDX library
- LuaJIT - lua-gdx uses LuaJIT's FFI and so won't work with plain Lua


## 3. Who?

lua-gdx was developed by [Incremental](http://www.incremental.co.nz/)
with support from the [Electricity Authority](http://www.ea.govt.nz/)
You can contact us at <info@incremental.co.nz>.
