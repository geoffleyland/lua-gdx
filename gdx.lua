-- Copyright (c) 2011 Incremental IP Limited
-- see LICENSE for license information

local gdxraw = require("gdxraw")
local ffi = require("ffi")

local BUFFER_SIZE = 256

ffi.cdef
[[
char *strerror(int);
char *strncpy(char*, const char*, size_t);
]]


--------------------------------------------------------------------------------

local function pstr(s)
  return string.char(s:len())..s
end


local function lstr(s)
  return ffi.string(s+1, ffi.cast("unsigned char", s[0]))
end


--------------------------------------------------------------------------------

local enum_names =
{
  "GMS_MAX_INDEX_DIM",
  "GMS_VAL_LEVEL", "GMS_VAL_MARGINAL", "GMS_VAL_LOWER", "GMS_VAL_UPPER", "GMS_VAL_SCALE", "GMS_VAL_MAX",
  "GMS_DT_SET", "GMS_DT_PAR", "GMS_DT_VAR", "GMS_DT_EQU", "GMS_DT_ALIAS", "GMS_DT_MAX"
}
local function copy_enums(from, to)
  for _, v in ipairs(enum_names) do
    to[v] = tonumber(from[v])
  end
end


--------------------------------------------------------------------------------

local gdx = {}
local _gdx
local gdx_handle_pointer

function gdx:open(gams_path, libname)
  if not _gdx then
    _gdx = gdxraw.open(gams_path, libname)
    copy_enums(_gdx, gdx)
  end

  self.__index = self

  local o = { _H_ptr = ffi.new("gdxHandle_t[1]") }
  _gdx.XCreate(o._H_ptr)
  o._H = ffi.new("gdxHandle_t", o._H_ptr[0])
  
  return setmetatable(o, self)
end


-- Error handling --------------------------------------------------------------

local gdx_error_number = ffi.new("int[1]")
local gdx_error_string = ffi.new("char[?]", BUFFER_SIZE)
function gdx:ErrorStr(num)
  num = num or _gdx.GetLastError(self._H)
  if type(num) ~= "number" then
    num = gdx_error_number[0]
  end
  assert(_gdx.ErrorStr(self._H, num, gdx_error_string), "Call to gdx.ErrorStr failed")
  return lstr(gdx_error_string)
end


function gdx:error(num, ...)
  error(table.concat{...}..": "..self:ErrorStr(num), 1)
end


function gdx:check_error_number(...)
  if gdx_error_number[0] ~= 0 then
    self:error("", ...)
  end
end


function gdx:check(return_code, ...)
  if return_code ~= 1 then
    self:error(nil, ...)
  end
end


--------------------------------------------------------------------------------

version_string = ffi.new("char[?]", BUFFER_SIZE)
function gdx:GetDLLVersion()
  if not _gdx.GetDLLVersion(self._H, version_string) then
    self:error("GetDLLVersion failed")
  end
  return lstr(version_string)
end


--------------------------------------------------------------------------------

function gdx:OpenWrite(filename, producer)
  _gdx.OpenWrite(self._H, pstr(filename), pstr(producer), gdx_error_number)
  self:check_error_number("Failed to open ", filename)
end


function gdx:OpenRead(filename)
  _gdx.OpenRead(self._H, pstr(filename), gdx_error_number)
  self:check_error_number("Failed to open ", filename)
end


local version, producer = ffi.new("char[?]", BUFFER_SIZE), ffi.new("char[?]", BUFFER_SIZE)
function gdx:FileVersion()
  self:check(_gdx.FileVersion(self._H, version, producer), "Could not determine file version")
  return lstr(version), lstr(producer)
end


local symbol_count = ffi.new("int[1]")
local element_count = ffi.new("int[1]")
function gdx:SystemInfo()
  self:check(_gdx.SystemInfo(self._H, symbol_count, element_count), "Could not get system info")
  return symbol_count[0], element_count[0]
end


local symbol_number = ffi.new("int[1]")
function gdx:FindSymbol(name)
  self:check(_gdx.FindSymbol(self._H, pstr(name), symbol_number), "Could not find symbol ", name)
  return symbol_number[0]
end


local symbol_name = ffi.new("char[?]", BUFFER_SIZE)
local symbol_dims = ffi.new("int[1]")
local symbol_type = ffi.new("int[1]")
function gdx:SymbolInfo(symbol_number)
  self:check(_gdx.SymbolInfo(self._H, symbol_number, symbol_name, symbol_dims, symbol_type),
             ("Could not get info for symbol #%d"):format(symbol_number))
  return lstr(symbol_name), symbol_dims[0], symbol_type[0]
end


local symbol_records = ffi.new("int[1]")
local symbol_userinfo = ffi.new("int[1]")
local symbol_description = ffi.new("char[?]", BUFFER_SIZE)
function gdx:SymbolInfoX(symbol_number)
  self:check(_gdx.SymbolInfoX(self._H, symbol_number, symbol_records, symbol_userinfo, symbol_description),
             ("Could not get info for symbol #%d"):format(symbol_number))
  return symbol_records[0], symbol_userinfo[0], lstr(symbol_description)
end


function gdx:CurrentDim()
  return _gdx.CurrentDim(self._H)
end


function gdx:SymbolGetDomain(symbol_number)
  local symbol_domains = ffi.new("int[?]", 28)
  self:check(_gdx.SymbolGetDomain(self._H, symbol_number, symbol_domains),
             ("Could not get domains for symbol #%d"):format(symbol_number))
  return symbol_domains
end


function gdx:DataWriteStrStart(name, desc, dims, type, userdata)
  self:check(_gdx.DataWriteStrStart(self._H, pstr(name), pstr(desc), dims, type, userdata or 0),
             "Failed to start writing data")
end


function gdx:DataWriteDone()
  self:check(_gdx.DataWriteDone(self._H), "Couldn't complete writing data")
end


local record_count = ffi.new("int[1]")
function gdx:DataReadStrStart(symbol_number)
  self:check(_gdx.DataReadStrStart(self._H, symbol_number, record_count),
             ("Couldn't start reading symbol #%d"):format(symbol_number))
  return record_count[0]
end


function gdx:DataReadDone()
  self:check(_gdx.DataReadDone(self._H), "Couldn't complete reading data")
end


local names = ffi.new("char[28][256]")          -- 28 is the lowest number this works for NOT GLOBAL_MAX_INDEX_DIM (which is 20)
local Values = ffi.new("double[6]")
function gdx:DataWriteStr(s, V)
  if type(s) == "string" then
    ffi.C.strncpy(ffi.cast("char*", names), pstr(s), s:len()+1)
  else
    for i = 1, math.min(#s, gdx.GMS_MAX_INDEX_DIM)  do
      ffi.C.strncpy(names[i-1], pstr(s[i]), s[i]:len()+1)      
    end
  end

  if type(V) == "number" then
    Values[gdx.GMS_VAL_LEVEL] = V
  else
    for i = 0, 5 do
      Values[i] = V[i] or 0
    end
  end

  self:check(_gdx.DataWriteStr(self._H, ffi.cast("const char**", names), Values),
             "Failed to write data")
end


local names = ffi.new("char[28][256]")
local Values = ffi.new("double[5]")
local N = ffi.new("int[1]")
function gdx:DataReadStr()
  if _gdx.DataReadStr(self._H, ffi.cast("char*", names), Values, N) == 0 then
    return
  end

  local lnames = {}
  for i = 0, self:CurrentDim()-1 do
    lnames[i+1] = lstr(names[i])
  end
  local V = {}
  for i = 0, 5 do
    V[i] = Values[i]
  end
  return lnames, V
end


local name = ffi.new("char[256]")
local node = ffi.new("int[1]")
function gdx:GetElemText(i)
  if _gdx.GetElemText(self._H, i, name, node) ~= 0 then
    return lstr(name), node[0]
  end
end


--------------------------------------------------------------------------------

function gdx:Close()
  assert(_gdx.Close(self._H), "Failed to close gdx file")
end


function gdx:Free()
  assert(_gdx.Free(self._H_ptr), "Failed to free gdx handle")
end


--------------------------------------------------------------------------------

return gdx


-- EOF -------------------------------------------------------------------------

