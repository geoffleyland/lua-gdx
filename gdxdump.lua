-- Copyright (c) 2011 Incremental IP Limited
-- see LICENSE for license information

local gdx = require("gdx")


-- GDX utilities ---------------------------------------------------------------

local gdxx = {}


function gdxx.file_info(G)
  local info = {}
  info.version, info.producer = G:FileVersion()
  info.symbol_count, info.element_count = G:SystemInfo()
  return info
end


local symbol_type_text = { "Set", "Parameter", "Variable", "Equation", "Alias" }
local variable_type_text = { "Unknown", "Binary", "Integer", "Positive", "Negative", "Free", "Sos1", "Sos2", "Semicont", "Semiint" }
local value_type_text = { ".l", ".m", ".lo", ".ub", ".scale" }

function gdxx.symbol_info(G, num)
  local info = {}
  info.name, info.dims, info.type = G:SymbolInfo(num)
  info.records, info.userinfo, info.description = G:SymbolInfoX(num)

  if info.type == G.GMS_DT_PAR and info.dims == 0 then
    info.typename = "Scalar"
  else
    info.typename = symbol_type_text[info.type+1]
  end

  info.full_typename = ""
  if info.type == G.GMS_DT_VAR then
    info.full_typename = variable_type_text[info.userinfo+1].." "
  end
  info.full_typename = info.full_typename..info.typename
  
  local gdx_domain = G:SymbolGetDomain(num)
  info.domain = {}
  for i = 1, info.dims do
    local d = gdx_domain[i-1]
    info.domain[i] =
    {
      index = d,
      key = d == 0 and '*' or G:SymbolInfo(d)
    }
  end
  return info
end


-- Dump a GDX file to stdout ---------------------------------------------------


function dump_GDX_file(G, filename)
  local comment_me = { [G.GMS_DT_VAR] = true, [G.GMS_DT_EQU] = true }

  G:OpenRead(filename)

  info = gdxx.file_info(G)
  io.stdout:write(("*  File Version   : %s\n"):format(info.version))
  io.stdout:write(("*  Producer       : %s\n"):format(info.producer))
  io.stdout:write(("*  Symbols        : %d\n"):format(info.symbol_count))
  io.stdout:write(("*  Unique Elements: %d\n"):format(info.element_count))

  io.stdout:write("$ontext\n")
  for i = 1, info.symbol_count do
    local sinfo = gdxx.symbol_info(G, i)
    io.stdout:write(("%-15s %3d %-12s %s\n"):
      format(sinfo.name, sinfo.dims, sinfo.typename, sinfo.description))
  end
  io.stdout:write("$offtext\n$onempty onembedded\n")

  for i = 1, info.symbol_count do
    local sinfo = gdxx.symbol_info(G, i)
    if comment_me[sinfo.type] then io.stdout:write("$ontext\n") end
    io.stdout:write(sinfo.full_typename, " ", sinfo.name)
    if sinfo.dims > 0 then
      io.stdout:write("(")
      for i, d in ipairs(sinfo.domain) do
        if i > 1 then io.stdout:write(",") end
        io.stdout:write(d.key)
      end
      io.stdout:write(")")
    end
    local sm = sinfo.description:find("'") and '"' or "'"
    io.stdout:write(" ", sm, sinfo.description, sm, " /\n")

    G:DataReadStrStart(i)

    while true do
      local names, values = G:DataReadStr()
      if not names then break end
      if info.type ~= G.GMS_DT_PAR or values[G.GMS_VAL_LEVEL] ~= 0 then
        for i, n in ipairs(names) do
          io.stdout:write(("%s'%s'"):format(i == 1 and "" or ".", n))
        end
        if sinfo.type == G.GMS_DT_PAR or sinfo.type == G.GMS_DT_VAR then
          io.stdout:write((" %g"):format(values[G.GMS_VAL_LEVEL]))
        elseif sinfo.type == G.GMS_DT_SET then
          local description = G:GetElemText(values[G.GMS_VAL_LEVEL])
          if description then
            local sm = description:find("'") and '"' or "'"
            io.stdout:write(sm, description, sm)
          end
        end
        io.stdout:write("\n")
      end
    end
    io.stdout:write("/;\n")
    if comment_me[sinfo.type] then io.stdout:write("$offtext\n") end
    io.stdout:write("\n")
  end
end


-- main ------------------------------------------------------------------------

function main(_arg)
  _arg = _arg or arg
  
  if #_arg ~= 2 then
    io.stderr:write("Error: wrong number of arguments\n")
    io.stderr:write(("Usage: %s %s <GAMS system directory> <GDX file>\n"):format(arg[-1], arg[0]))
    return 2
  else
    G = gdx:open(_arg[1])
    dump_GDX_file(G, _arg[2])
  end
  return 1
end


if type(arg) == "table" and string.match(debug.getinfo(1, "S").short_src, arg[0]) then
  os.exit(main(arg))
end


-- EOF -------------------------------------------------------------------------
