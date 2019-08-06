%{lua:

-- This RPM spec file can build
--
-- ## Usage
--
-- ### pup_module_info_dir
--
-- When you build, you must define the macro 'pup_module_info_dir' so that rpm
-- knows where to find preliminary information.
--
-- If 'pup_module_info_dir' isn't defined or available, rpm will look in
-- '_sourcedir' for the files, falling back to the current directory as a last
-- resort.
--
-- Example:
--
--     rpmbuild -D 'pup_module_info_dir /home/user/project/puppet_module' -ba SPECS/specfile.spec
--
-- ### relevant files
--
-- 'pup_module_info_dir' should be a directory that contains the following items:
--
--   * 'metadata.json'                  <- REQUIRED file that must contain the
--                                         following metadata:
--                                           - 'name' - package name
--                                           - 'version' - package version
--                                           - 'license' - package license
--                                           - 'summary' - package summary
--                                           - 'source' - package source
--   * 'build/rpm_metadata/requires'    <- optional list of 'Requires',
--                                         'Provides', and 'Obsoletes' to
--                                         supplement those auto-generated in
--                                         this spec file.
--   * 'build/rpm_metadata/release'     <- optional RPM release number to use in
--                                         lieu of the number '0' hard-coded in
--                                         this spec file.
--   * 'CHANGELOG'                      <- optional RPM-formatted CHANGELOG to
--                                         use in lieu of the minimal changelog
--                                         entry auto-generated in this file.
--   * 'build/rpm_metadata/custom/'     <- optional directory to place files to
--                                         add custom scriptlets and triggers.
--
--

local LUA_DEBUG = ((rpm.expand('%{lua_debug}') or '0') == '1')

-- Print debugging info to STDERR (if LUA_DEBUG is true)
function lua_stderr( msg )
  if LUA_DEBUG then
    -- io.stderr:write(tostring(msg):gsub("%f[^%z\n]","LUA #stderr#: "))
    -- io.stderr:write(tostring(msg))
    io.stderr:write(msg)
  end
end


local function get_src_dir()
  local src_dir = rpm.expand('%{pup_module_info_dir}')
  if src_dir:match('^%%') or (posix.stat(src_dir, 'type') ~= 'directory') then
    lua_stderr("WARNING: -D pup_module_info_dir ("..tostring(src_dir)..") could not be used!\n")
    lua_stderr("         falling back to src_dir = _sourcedir\n")

    -- FIXME?: rpmlint considers the use of _sourcedir to be an Error:
    --   (see: https://fedoraproject.org/wiki/Packaging:RPM_Source_Dir)
    src_dir = rpm.expand('%{_sourcedir}')

    if (posix.stat((src_dir .. "/metadata.json"), 'type') ~= 'regular') then
      lua_stderr("WARNING: couldn't find metadata.json in '"..tostring(src_dir).."'!\n")
      lua_stderr("         falling back to src_dir = posix.getcwd() ("..posix.getcwd()..")\n")

      src_dir = posix.getcwd()
    end
  end
  return src_dir
end

-- path to project directory / source files
src_dir = get_src_dir()

-- directory to look for customizations (e.g., scriptlets, triggers)
custom_content_dir = src_dir .. "/build/rpm_metadata/custom/"

-- list of custom content to inject into the spec file
custom_content_table = {}

-- list of scriptlets/triggers that have been declared (to avoid duplicates)
declared_scriptlets_table = {}

-- patterns to recognize scriptlet and trigger declarations
--
-- NOTE: Lua patterns are not regexes , and do not support alternation.
--       So, we try to stay efficient by iterating through as few patterns as
--       possible by short-ciruiting several matches.
--       (e.g. '^%%pre' matches both '%pre' and '%pretrans')
--
SCRIPTLET_PATTERNS = {
  '^%%pre',
  '^%%post',
  '^%%trigger'
}

-- These UNKNOWN entries should break the build if something bad happens

package_name = "UNKNOWN"
package_version = "UNKNOWN"
module_license = "UNKNOWN"

-- Default to 0
package_release = 0

lua_stderr("\n")
lua_stderr("--------------------------------------------------------------------------------\n")
lua_stderr("RPM/LUA build environment:\n")
lua_stderr("------:\n")
lua_stderr("LUA _VERSION       = '".._VERSION.."'\n")
lua_stderr("posix.getcwd()     = '"..posix.getcwd().."'\n")
lua_stderr("\n")
lua_stderr("macros:\n")
lua_stderr("------:\n")
lua_stderr("'%{pup_module_info_dir}' = '"..rpm.expand('%{pup_module_info_dir}').."'\n")
lua_stderr("_specdir           = '"..rpm.expand('%{_specdir}').."'\n")
lua_stderr("_buildrootdir      = '"..rpm.expand('%{_buildrootdir}').."'\n")
lua_stderr("buildroot          = '"..rpm.expand('%{buildroot}').."'\n")
lua_stderr("RPM_BUILD_ROOT     = '"..rpm.expand('%{RPM_BUILD_ROOT}').."'\n")
lua_stderr("\n")
lua_stderr("local variables:\n")
lua_stderr("------:\n")
lua_stderr("src_dir            = '".. src_dir .."'\n")
lua_stderr("custom_content_dir = '"..custom_content_dir.."'\n# ---\n")
lua_stderr("--------------------------------------------------------------------------------\n")
lua_stderr("\n")


-- Pull the Relevant Metadata out of the Puppet module metadata.json.
function read_metadata(src_dir)
  local metadata = ''
  local metadata_file = src_dir .. "/metadata.json"
  local metadata_fh   = io.open(metadata_file,'r')
  if metadata_fh then
    metadata = metadata_fh:read("*all")

    -- Ignore the first curly brace
    metadata = metadata:gsub("{}?", '|', 1)

    -- Ignore all keys that are below the first level
    metadata = metadata:gsub("{.-}", '')
    metadata = metadata:gsub("%[.-%]", '')
  else
    error("Could not open 'metadata.json': ".. metadata_file, 0)
  end
  return metadata
end


metadata = read_metadata(src_dir)

-- This starts as an empty string so that we can build it later
module_requires = ''

}

%{lua:

-- Get the Module Name and put it in the correct format

local name_match = metadata:match('"name":%s+"(.-)"%s*,')

module_author = ''
module_name = ''

if name_match then
  package_name = ('pupmod-' .. name_match)

  local i = 0
  for str in name_match:gmatch('[^-]+') do
    if i == 0 then
      module_author = str
    else
      if module_name == '' then
        module_name = str
      else
        module_name = (module_name .. '-' .. str)
      end
    end

    i = i+1
  end
else
  error("Could not find valid package name in 'metadata.json'", 0)
end

}

%{lua:

-- Get the Module Version

local version_match = metadata:match('"version":%s+"(.-)"%s*,')

if version_match then
  package_version = version_match
else
  error("Could not find valid package version in 'metadata.json'", 0)
end

}

%{lua:

-- Get the Module License

local license_match = metadata:match('"license":%s+"(.-)"%s*,')

if license_match then
  module_license = license_match
else
  error("Could not find valid package license in 'metadata.json'", 0)
end

}

%{lua:

-- Get the Module Summary

local summary_match = metadata:match('"summary":%s+"(.-)"%s*,')

if summary_match then
  module_summary = summary_match
else
  error("Could not find valid package summary in 'metadata.json'", 0)
end

}

%{lua:

-- Get the Module Source line for the URL string

local source_match = metadata:match('"source":%s+"(.-)"%s*,')

if source_match then
  module_source = source_match
else
  error("Could not find valid package source in 'metadata.json'", 0)
end

}

%{lua:

-- Snag the RPM-specific items out of the 'build/rpm_metadata' directory

-- First, the Release Number

rel_file = io.open(src_dir .. "/build/rpm_metadata/release", "r")

if not rel_file then
  -- Need this for the SRPM case
  rel_file = io.open(src_dir .. "/release", "r")
end

if rel_file then
  for line in rel_file:lines() do
    is_comment = line:match("^%s*#")
    is_blank = line:match("^%s*$")

    if not (is_comment or is_blank) then
      package_release = line
      break
    end
  end
end

}

%{lua:

-- Next, the Requirements
req_file = io.open(src_dir .. "/build/rpm_metadata/requires", "r")

if not req_file then
  -- Need this for the SRPM case
  req_file = io.open(src_dir .. "/requires", "r")
end

if req_file then
  for line in req_file:lines() do
    valid_line = (line:match("^Requires: ") or line:match("^Obsoletes: ") or line:match("^Provides: "))

    if valid_line then
      module_requires = (module_requires .. "\n" .. line)
    end
  end
end
}

%global _binaries_in_noarch_packages_terminate_build 0

%define module_name %{lua: print(module_name)}
%define package_name %{lua: print(package_name)}

Summary:   %{module_name} Puppet Module
Name:      %{package_name}

Version:   %{lua: print(package_version)}
Release:   %{lua: print(package_release)}
License:   %{lua: print(module_license)}
Group:     Applications/System
Source0:   %{package_name}-%{version}-%{release}.tar.gz
Source1:   %{lua: print("metadata.json")}
%{lua:
  -- Include our sources as appropriate
  changelog = io.open(src_dir .. "/CHANGELOG","r")
  if changelog then
    print("Source2: " .. "CHANGELOG\n")
  end

  if rel_file then
    print("Source3: " .. "release\n")
  end
  if req_file then
    print("Source4: " .. "requires\n")
  end
}
URL:       %{lua: print(module_source)}
BuildRoot: %{_tmppath}/%{package_name}-%{version}-%{release}-buildroot
BuildArch: noarch

Requires(pre): simp-adapter >= 0.1.1
Requires(preun): simp-adapter >= 0.1.1
Requires(preun): simp-adapter >= 0.1.1
Requires(posttrans): simp-adapter >= 0.1.1

%{lua: print(module_requires)}

Provides: pupmod-%{lua: print(module_name)} = %{lua: print(package_version .. "-" .. package_release)}
Obsoletes: pupmod-%{lua: print(module_name)} < %{lua: print(package_version .. "-" .. package_release)}

%{lua:

  -- This is a workaround for the 'simp-rsync' real RPM conflict but is
  -- required by some external modules.
  -- This should be removed when SIMP 6 is stable

  author_rpm_name = module_author .. "-" .. module_name

  if author_rpm_name ~= 'simp-rsync' then
    print("Provides: " .. author_rpm_name .. " = " .. package_version .. "-" .. package_release .. "\n")
    print("Obsoletes: " .. author_rpm_name .. " < " .. package_version .. "-" .. package_release ..  "\n")
  end
}

Prefix: /usr/share/simp/modules

%description
%{lua: print(module_summary)}

%prep
%setup -q -n %{package_name}-%{version}

%build

%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}

curdir=`pwd`
dirname=`basename $curdir`
cp -r ../$dirname %{buildroot}/%{prefix}/%{module_name}

# Modules should *never* contain symlinks
find %{buildroot} -type l -delete

# Remove unnecessary assets
rm -rf %{buildroot}/%{prefix}/%{module_name}/.git
rm -f %{buildroot}/%{prefix}/%{module_name}/*.lock
rm -rf %{buildroot}/%{prefix}/%{module_name}/spec/fixtures/modules
rm -rf %{buildroot}/%{prefix}/%{module_name}/dist
rm -rf %{buildroot}/%{prefix}/%{module_name}/junit
rm -rf %{buildroot}/%{prefix}/%{module_name}/log

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}

%{lua:

  -- returns true if 'scriptlet_name' has already been declared
  function is_scriplet_declared(scriptlet_name, declared_scriptlets_table)
    for _,name in ipairs(declared_scriptlets_table) do
      if (name == scriptlet_name) then
        return true
      end
    end
    return false
  end

  -- returns true if 'line' is a scriptlet or trigger header
  function is_valid_scriptlet_header(line)
    local match = false
    for _, patt in ipairs(SCRIPTLET_PATTERNS) do
      if line:match(patt) then
        match = true
        break
      end
    end
    return match
  end

  --
  -- adds content to the custom_content_table
  --
  function define_custom_content(
     content,
     custom_content_table,
     declared_scriptlets_table
  )
    lua_stderr("# evaluating extra content: \n".. (content:gsub("%f[^%z\n]","  | ")) .."\n")

    if content then
      local _content = ''
      local recording = true

      for line in content:gmatch("([^\n]*)\n?") do

        -- skip duplicate scriptlets
        if is_valid_scriptlet_header(line) then
          local _line = line:gsub("^%s+",""):gsub("%s+$","")
          if is_scriplet_declared(_line, declared_scriptlets_table) then
            lua_stderr("WARNING: scriptlet '".._line..
                       "' has already been declared (skipping scriptlet).\n")
            recording = false
          else
            lua_stderr('+ "'.._line..'" is recognized as a scriptlet/trigger.\n')
            recording = true
            table.insert(declared_scriptlets_table, _line)
          end
        end

        if recording then
           _content = _content .. line .. "\n"
        else
           lua_stderr("  skipping line '"..line.."'\n")
        end
      end
      table.insert(custom_content_table, _content )
    end
  end


  function load_custom_content_files(custom_content_dir, custom_content_table, declared_scriptlets_table)
    if (posix.stat(custom_content_dir, 'type') == 'directory') then
      for i,basename in pairs(posix.dir(custom_content_dir)) do
        local file = custom_content_dir .. basename
        -- only accept files that are not dot files (".filename")
        if (basename:match('^[^%.]') and (posix.stat(file, 'type') == 'regular')) then
          lua_stderr("INFO: found custom RPM spec file snippet: '" .. file .. "'\n")
          local file_handle = io.open(file,'r')
          if file_handle then
            local _content = file_handle:read("*all")
            define_custom_content(_content, custom_content_table, declared_scriptlets_table)
          else
            lua_stderr("WARNING: could not read '"..file.."'\n")
          end
          file_handle:close()
        else
          lua_stderr("WARNING: skipping invalid filename '"..basename.."'\n")
        end
      end
    else
      lua_stderr("WARNING: not found: " .. custom_content_dir .. "\n")
    end
  end

  -- Declares default scriptlets for SIMP 6.X (referenced from 6.1.0)
  --
  --   In order to keep the package-maintained pupmod-*-* packages.
  --   Packages notify /usr/local/sbin/simp_rpm_helper.
  --   See: https://github.com/simp/simp-adapter/blob/master/src/sbin/simp_rpm_helper
  --
  -- This function should be called last
  --
  function declare_default_scriptlets(custom_content_table, declared_scriptlets_table)
    local marker_dir = rpm.expand('%{_localstatedir}/lib/rpm-state/simp-adapter')
    local marker_file = marker_dir..'/rpm_status$1.'..module_name

    local pre_comment = (
      '# when $1 = 1, this is an install\n'..
      '# when $1 = 2, this is an upgrade\n'
    )

    local preun_comment = (
      '# when $1 = 1, this is the uninstall of the previous version during an upgrade\n'..
      '# when $1 = 0, this is the uninstall of the only version during an erase\n'
    )

    local postun_comment = (
      '# when $1 = 1, this is the uninstall of the previous version during an upgrade\n'..
      '# when $1 = 0, this is the uninstall of the only version during an erase\n'
    )


    local DEFAULT_SCRIPTLETS = {
      ['pre']    = {comment = pre_comment, custom='mkdir -p '..marker_dir..'\ntouch '..marker_file..'\n'},
      ['preun']  = {comment = preun_comment, custom=''},
      ['postun'] = {comment = postun_comment, custom=''}
    }

    local rpm_dir = rpm.expand('%{prefix}/' .. module_name)

    for name,data in pairs(DEFAULT_SCRIPTLETS) do
      local content = ('%'..name.."\n"..
        '# (default scriptlet for SIMP 6.x)\n'..
        data.comment ..
        data.custom ..
        'if [ -x /usr/local/sbin/simp_rpm_helper ] ; then\n'..
        '  /usr/local/sbin/simp_rpm_helper --rpm_dir='..
        rpm_dir.." --rpm_section='"..name.."' --rpm_status=$1\n"..
        'fi\n\n'
      )

      define_custom_content(content, custom_content_table, declared_scriptlets_table)
    end

    local install_marker_file = marker_dir..'/rpm_status1.'..module_name
    local upgrade_marker_file = marker_dir..'/rpm_status2.'..module_name
    local posttrans_content = ('%posttrans\n'..
      '# (default scriptlet for SIMP 6.x)\n'..
      '# Marker file is created in %pre and only exists for installs or upgrades\n'..
      "# when marker file is prepended with 'rpm_status1.', this is an install\n"..
      "# when marker file is prepended with 'rpm_status2.', this is an upgrade\n"..
      'if [ -e '..install_marker_file..' ] ; then\n'..
      '  rm '..install_marker_file..'\n'..
      '  if [ -x /usr/local/sbin/simp_rpm_helper ] ; then\n'..
      '    /usr/local/sbin/simp_rpm_helper --rpm_dir='..
      rpm_dir.." --rpm_section='posttrans' --rpm_status=1\n"..
      '  fi\n'..
      'elif [ -e '..upgrade_marker_file..' ] ; then\n'..
      '  rm '..upgrade_marker_file..'\n'..
      '  if [ -x /usr/local/sbin/simp_rpm_helper ] ; then\n'..
      '    /usr/local/sbin/simp_rpm_helper --rpm_dir='..
      rpm_dir.." --rpm_section='posttrans' --rpm_status=2\n"..
      '  fi\n'..
      'fi\n\n'
    )

    define_custom_content(posttrans_content, custom_content_table, declared_scriptlets_table)
  end


  -- insert custom content (e.g., rpm_metadata/custom/*, scriptlets)
  function print_extra_content( custom_content_table )
    local extra_content = table.concat(custom_content_table, "\n") .. "\n"
    lua_stderr("\n========== DYNAMIC CONTENT SUMMARY ========== (begin)\n" ..
                rpm.expand( extra_content ) ..
                "\n========== DYNAMIC CONTENT SUMMARY ========== (end)\n")
    print(extra_content)
  end


  load_custom_content_files(
    custom_content_dir,
    custom_content_table,
    declared_scriptlets_table
  )
  declare_default_scriptlets(custom_content_table, declared_scriptlets_table)
  print_extra_content(custom_content_table)
}


%files
%defattr(0640,root,root,0750)
%{prefix}/%{module_name}

%changelog
%{lua:
-- Finally, the CHANGELOG

-- A default CHANGELOG in case we cannot find a real one

default_changelog = [===[
* $date Auto Changelog <auto@no.body> - $version-$release
- Latest release of $name
]===]

default_lookup_table = {
  date = os.date("%a %b %d %Y"),
  version = package_version,
  release = package_release,
  name = package_name
}

changelog = io.open(src_dir .. "/CHANGELOG","r")
if changelog then
  first_line = changelog:read()
  if first_line:match("^*%s+%a%a%a%s+%a%a%a%s+%d%d?%s+%d%d%d%d%s+.+") then
    changelog:seek("set",0)
    print(changelog:read("*all"))
  else
    print((default_changelog:gsub('$(%w+)', default_lookup_table)))
  end
else
  print((default_changelog:gsub('$(%w+)', default_lookup_table)))
end
}
