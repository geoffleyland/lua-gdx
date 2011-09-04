-- Copyright (c) 2011 Incremental IP Limited
-- see LICENSE for license information

local libnames =
{
  OSX     = { x86 = "libgdxdclib32.dylib",     x64 = "libgdxdclib64.dylib" },
  Windows = { x86 = "gdxdclib32.DLL",          x64 = "gdxdclib64.DLL"      },
  Linux   = { x86 = "libgdxdclib32.so",        x64 = "libgdxdclib64.so"     , arm = "libgdxdclib.so" },
  BSD     = { x86 = "libgdxdclib.so",          x64 = "libgdxdclib.so"      },
  POSIX   = { x86 = "libgdxdclib.so",          x64 = "libgdxdclib.so"      },
  Other   = { x86 = "libgdxdclib.so",          x64 = "libgdxdclib.so"      },
}


local paths =
{
  OSX     = { x86 = "/Applications/GAMS/",     x64 = "/Applications/GAMS/" },
  Windows = { x86 = "",                        x64 = ""                    },
  Linux   = { x86 = "",                        x64 = ""                     , arm = "" },
  BSD     = { x86 = "",                        x64 = ""                    },
  POSIX   = { x86 = "",                        x64 = ""                    },
  Other   = { x86 = "",                        x64 = ""                    },
}


local dirseps =
{
  OSX     = "/",
  Windows = "\\",
  Linux   = "/",
  BSD     = "/",
  POSIX   = "/",
  Other   = "/",
}


local status, ffi = pcall(require, "ffi")
if not status then
  error("FFI not present - you need to use a recent LuaJIT, rather than plain Lua\n"..ffi)
end

local libname = libnames[ffi.os][ffi.arch]
local path = paths[ffi.os][ffi.arch]
local dirsep = dirseps[ffi.os]


--------------------------------------------------------------------------------

ffi.cdef
[[
enum
{
  GMS_MAX_INDEX_DIM                             = 20,

  GMS_VAL_LEVEL                                 = 0,
  GMS_VAL_MARGINAL                              = 1,
  GMS_VAL_LOWER                                 = 2,
  GMS_VAL_UPPER                                 = 3,
  GMS_VAL_SCALE                                 = 4,
  GMS_VAL_MAX                                   = 5,

  GMS_DT_SET                                    = 0,
  GMS_DT_PAR                                    = 1,
  GMS_DT_VAR                                    = 2,  
  GMS_DT_EQU                                    = 3,
  GMS_DT_ALIAS                                  = 4,
  GMS_DT_MAX                                    = 5,
};


typedef void *gdxHandle_t;
typedef gdxHandle_t GHT;
void XCreate(GHT*)                              asm("xcreate");
int GetDLLVersion(GHT, char*)                   asm("gdxgetdllversion");
int GetLastError(GHT)                           asm("gdxgetlasterror");
int ErrorStr(GHT, int, char*)                   asm("gdxerrorstr");

int OpenWrite(GHT, const char*, const char*, int*)
                                                asm("gdxopenwrite");
int OpenRead(GHT, const char*, int*)            asm("gdxopenread");

int FileVersion(GHT, char*, char*)              asm("gdxfileversion");
int SystemInfo(GHT, int*, int*)                 asm("gdxsysteminfo");

int DataWriteStrStart(GHT, const char*, const char*, int, int, int)
                                                asm("gdxdatawritestrstart");
int DataWriteStr(GHT, const char *[], const double[])
                                                asm("gdxdatawritestr");
int DataWriteDone(GHT)                          asm("gdxdatawritedone");

int FindSymbol(GHT, const char*, int*)          asm("gdxfindsymbol");
int SymbolInfo(GHT, int, char*, int*, int*)     asm("gdxsymbolinfo");
int SymbolInfoX(GHT, int, int *, int*, char *)  asm("gdxsymbolinfox");
int SymbolGetDomain(GHT, int, int*)             asm("gdxsymbolgetdomain");
int CurrentDim(GHT)                             asm("gdxcurrentdim");

int DataReadStrStart(GHT, int, int*)            asm("gdxdatareadstrstart");
int DataReadStr(GHT, char *, double[], int*)    asm("gdxdatareadstr");
int GetElemText(GHT, int, char *, int*)         asm("gdxgetelemtext");
int DataReadDone(GHT)                           asm("gdxdatareaddone");

int Close(GHT)                                  asm("gdxclose");
int Free(GHT*)                                  asm("gdxfree");
]]


local function open(gams_path, lib_name)
  gams_path = gams_path or path
  lib_name = lib_name or libname
  if gams_path:len() > 0 and gams_path:sub(-1) ~= "/" then
    gams_path = gams_path..dirsep
  end
  return assert(ffi.load(gams_path..libname))
end


return { open=open, }


-- EOF -------------------------------------------------------------------------

