local assemblyName = "lua"
local programVersion = "5.2.4" -- until we find a clever way to put this into an environment variable or so ...
local publicKeyToken = "db89f19495b8f232" -- the token for the code-signing
local action = _ACTION or ""
local release = false
local slnname = ""
local pfx = ""
do
    -- Name the project files after their VS version
    local orig_getbasename = premake.project.getbasename
    premake.project.getbasename = function(prjname, pattern)
        -- The below is used to insert the .vs(8|9|10|11|12) into the file names for projects and solutions
        if _ACTION then
            name_map = {vs2005 = "vs8", vs2008 = "vs9", vs2010 = "vs10", vs2012 = "vs11", vs2013 = "vs12"}
            if name_map[_ACTION] then
                pattern = pattern:gsub("%%%%", "%%%%." .. name_map[_ACTION])
            else
                pattern = pattern:gsub("%%%%", "%%%%." .. _ACTION)
            end
        end
        return orig_getbasename(prjname, pattern)
    end
    -- Override the object directory paths ... don't make them "unique" inside premake4
    local orig_gettarget = premake.gettarget
    premake.gettarget = function(cfg, direction, pathstyle, namestyle, system)
        local r = orig_gettarget(cfg, direction, pathstyle, namestyle, system)
        if (cfg.objectsdir) and (cfg.objdir) then
            cfg.objectsdir = cfg.objdir
        end
        return r
    end
    -- Silently suppress generation of the .user files ...
    local orig_generate = premake.generate
    premake.generate = function(obj, filename, callback)
        if filename:find('.vcproj.user') or filename:find('.vcxproj.user') then
            return
        end
        orig_generate(obj, filename, callback)
    end
    -- Make sure we do not incremental linking for the resource DLLs
    local orig_config_isincrementallink = premake.config.isincrementallink
    premake.config.isincrementallink = function(cfg)
        if cfg.project.name:find(pfx..'wdsr') and cfg.flags.NoIncrementalLink then
            return false
        end
        return orig_config_isincrementallink(cfg)
    end
    -- Override the project creation to suppress unnecessary configurations
    -- these get invoked by sln2005.generate per project ...
    -- ... they depend on the values in the sln.vstudio_configs table
    local mprj = {[pfx.."wdsr%x*"] = {["Release|Win32"] = 0}, [pfx.."minilua"] = {["Release|Win32"] = 0}, [pfx.."buildvm"] = {["Release|Win32"] = 0, ["Release|x64"] = 0}, [pfx.."luajit2"] = {["Release|Win32"] = 0, ["Release|x64"] = 0}, [pfx.."lua"] = {["Release|Win32"] = 0, ["Release|x64"] = 0}}
    local function prjgen_override_factory(orig_prjgen)
        return function(prj)
            local function prjmap()
                for k,v in pairs(mprj) do
                    if prj.name:find(k) or prj.name:match(k) then
                        return v
                    end
                end
                return nil
            end
            if prjmap() and type(prj.solution.vstudio_configs) == "table" then
                local cfgs = prj.solution.vstudio_configs
                local faked_cfgs = {}
                local prjmap = prjmap()
                for k,v in pairs(cfgs) do
                    if prjmap[v['name']] then
                        faked_cfgs[#faked_cfgs+1] = v
                    end
                end
                prj.solution.vstudio_configs = faked_cfgs
                retval = orig_prjgen(prj)
                prj.solution.vstudio_configs = cfgs
                return retval
            end
            return orig_prjgen(prj)
        end
    end
    premake.vs2010_vcxproj = prjgen_override_factory(premake.vs2010_vcxproj)
    premake.vstudio.vc200x.generate = prjgen_override_factory(premake.vstudio.vc200x.generate)
    -- Allow us to set the project configuration to Release|Win32 for the resource DLL projects,
    -- no matter what the global solution project is.
    local orig_project_platforms_sln2prj_mapping = premake.vstudio.sln2005.project_platforms_sln2prj_mapping
    premake.vstudio.sln2005.project_platforms_sln2prj_mapping = function(sln, prj, cfg, mapped)
        if prj.name:find(pfx..'minilua') then
            _p('\t\t{%s}.%s.ActiveCfg = Release|Win32', prj.uuid, cfg.name)
            _p('\t\t{%s}.%s.Build.0 = Release|Win32',  prj.uuid, cfg.name)
        elseif prj.name:find(pfx..'buildvm') or prj.name:find(pfx..'luajit2') or prj.name:find(pfx..'lua') then
            _p('\t\t{%s}.%s.ActiveCfg = Release|%s', prj.uuid, cfg.name, mapped)
            _p('\t\t{%s}.%s.Build.0 = Release|%s',  prj.uuid, cfg.name, mapped)
        else
            _p('\t\t{%s}.%s.ActiveCfg = %s|%s', prj.uuid, cfg.name, cfg.buildcfg, mapped)
            if mapped == cfg.platform or cfg.platform == "Mixed Platforms" then
                _p('\t\t{%s}.%s.Build.0 = %s|%s',  prj.uuid, cfg.name, cfg.buildcfg, mapped)
            end
        end
    end
    -- Make sure to intercept the VCManifestTool element generation, we need to add to it.
    --
    local function nval(val)
        return iif(val, val, "<null>")
    end
end
local function transformMN(input) -- transform the macro names for older Visual Studio versions
    local new_map   = { vs2002 = 0, vs2003 = 0, vs2005 = 0, vs2008 = 0 }
    local replacements = { Platform = "PlatformName", Configuration = "ConfigurationName" }
    if new_map[action] ~= nil then
        for k,v in pairs(replacements) do
            if input:find(k) then
                input = input:gsub(k, v)
            end
        end
    end
    return input
end
local function inc(inc_dir)
    include(inc_dir)
    create_luajit_projects(inc_dir)
end

solution (iif(release, slnname, "lua"))
    configurations  (iif(release, {"Release"}, {"Debug", "Release"}))
    platforms       {"x32", "x64"}
    location        ('.')

    -- Main WinDirStat project
    project (iif(release, slnname, "lua"))
        local int_dir   = pfx.."intermediate/" .. action .. "_$(" .. transformMN("Platform") .. ")_$(" .. transformMN("Configuration") .. ")\\$(ProjectName)"
        uuid            ("2C87BA15-DCDE-D04A-8E04-9E91DAD172D6")
        language        ("C++")
        kind            ("ConsoleApp")
        location        (".")
        targetname      ("lua")
        flags           {"StaticRuntime", "NativeWChar", "ExtraWarnings", "NoRTTI", "NoMinimalRebuild", "NoIncrementalLink", "NoEditAndContinue"} -- "Unicode", "MFC", "WinMain",
        targetdir       (iif(release, slnname, "build"))
        includedirs     {".", "src"}
        objdir          (int_dir)
        libdirs         {"$(IntDir)"}
        links           {"psapi"}
        resoptions      {"/nologo", "/l409"}
        resincludedirs  {".", "$(IntDir)"}
        linkoptions     {"/delayload:psapi.dll", "/pdbaltpath:%_PDB%"}
        if release then
            postbuildcommands
            {
                "ollisign \"$(TargetPath)\""
            }
        end
        files
        {
            "src/*.h",
            "src/*.c",
            "premake4.lua",
        }
        excludes
        {
            "src/luac.c",
        }

        vpaths
        {
            ["Header Files/*"] = { "src/*.h" },
            ["Source Files/*"] = { "src/*.c" },
            ["Special Files/*"] = { "premake4.lua", "*.cmd" },
            ["*"] = { "*.txt", "*.md" },
        }

        configuration {"Debug", "x32"}
            targetsuffix    ("32D")

        configuration {"Debug", "x64"}
            targetsuffix    ("64D")

        configuration {"Release", "x32"}
            targetsuffix    ("32")

        configuration {"Release", "x64"}
            targetsuffix    ("64")

        configuration {"Debug"}
            defines         {"_DEBUG", "VTRACE_TO_CONSOLE=1", "VTRACE_DETAIL=2"}
            flags           {"Symbols"}

        configuration {"Release"}
            defines         ("NDEBUG")
            flags           {"Optimize", "Symbols"}
            linkoptions     {"/release"}
            buildoptions    {"/Oi", "/Ot"}

        configuration {"vs2005"}
            defines         ("_CRT_SECURE_NO_WARNINGS") -- _CRT_SECURE_NO_DEPRECATE, _SCL_SECURE_NO_WARNINGS, _AFX_SECURE_NO_WARNINGS and _ATL_SECURE_NO_WARNINGS???

        configuration {"vs2013"}
            defines         {"WINVER=0x0501"}

        configuration {"vs2002 or vs2003 or vs2005 or vs2008 or vs2010 or vs2012"}
            defines         {"WINVER=0x0500"}
