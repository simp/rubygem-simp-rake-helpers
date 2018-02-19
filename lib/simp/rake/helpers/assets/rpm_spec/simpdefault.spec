%{lua:

--
-- When you build, you must define the macro 'pup_module_info_dir' so that we
-- know where to get preliminary information.
--
-- Example:
--
--   rpmbuild -D 'pup_module_info_dir /home/user/project/puppet_module' -ba SPECS/specfile.spec
--
-- 'pup_module_info_dir' should be a directory that holds the following items:
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
--   * 'build/rpm_metadata/custom/' <- optional directory to place files to
--                                         add custom scriptlets and triggers.
--
-- If this is not found in 'pup_module_info_dir', we will look in '_sourcedir'
-- for the files, and fall back to the current directory
--

lua_debug = ((rpm.expand('%{lua_debug}') or '0') == '1')
function lua_stderr( msg )
  if lua_debug then io.stderr:write(msg) end
end

src_dir = rpm.expand('%{pup_module_info_dir}')

if string.match(src_dir, '^%%') or (posix.stat(src_dir, 'type') ~= 'directory') then
  -- NOTE: rpmlint considers this an E:
  src_dir = rpm.expand('%{_sourcedir}')

  if (posix.stat((src_dir .. "/metadata.json"), 'type') ~= 'regular') then
    src_dir = posix.getcwd()
  end
  lua_stderr("  #stderr# LUA: WARNING: pup_module_info_dir ("..(src_dir or "NIL")..") could not be used!\n")
  lua_stderr("  #stderr# LUA:          falling back to src_dir = _sourcedir\n")

  -- FIXME: rpmlint considers the use of _sourcedir to be an Error:
  src_dir = rpm.expand('%{_sourcedir}')

  if (posix.stat((src_dir .. "/metadata.json"), 'type') ~= 'regular') then
    lua_stderr("  #stderr# LUA: WARNING: couldn't find metadata.json in '"..(src_dir or "NIL").."'!\n")
    lua_stderr("  #stderr# LUA:          falling back to src_dir = posix.getcwd() ("..posix.getcwd()..")\n")

    src_dir = posix.getcwd()
  end

end

custom_content_dir = src_dir .. "/build/rpm_metadata/custom/" -- location (relative to
custom_content_table = {}                  -- text to add to the spec file
defined_scriptlets_table = {}              -- list of scriptlets seen so far

-- These UNKNOWN entries should break the build if something bad happens

package_name = "UNKNOWN"
package_version = "UNKNOWN"
module_license = "UNKNOWN"

-- Default to 0
package_release = 0



-- Pull the Relevant Metadata out of the Puppet module metadata.json.

metadata = ''
metadata_file = src_dir .. "/metadata.json"
metadata_fh   = io.open(metadata_file,'r')
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

-- This starts as an empty string so that we can build it later
module_requires = ''

}

%{lua:

-- Get the Module Name and put it in the correct format

local name_match = string.match(metadata, '"name":%s+"(.-)"%s*,')

module_author = ''
module_name = ''

if name_match then
  package_name = ('pupmod-' .. name_match)

  local i = 0
  for str in string.gmatch(name_match,'[^-]+') do
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

local version_match = string.match(metadata, '"version":%s+"(.-)"%s*,')

if version_match then
  package_version = version_match
else
  error("Could not find valid package version in 'metadata.json'", 0)
end

}

%{lua:

-- Get the Module License

local license_match = string.match(metadata, '"license":%s+"(.-)"%s*,')

if license_match then
  module_license = license_match
else
  error("Could not find valid package license in 'metadata.json'", 0)
end

}

%{lua:

-- Get the Module Summary

local summary_match = string.match(metadata, '"summary":%s+"(.-)"%s*,')

if summary_match then
  module_summary = summary_match
else
  error("Could not find valid package summary in 'metadata.json'", 0)
end

}

%{lua:

-- Get the Module Source line for the URL string

local source_match = string.match(metadata, '"source":%s+"(.-)"%s*,')

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
    is_comment = string.match(line, "^%s*#")
    is_blank = string.match(line, "^%s*$")

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
    valid_line = (string.match(line, "^Requires: ") or string.match(line, "^Obsoletes: ") or string.match(line, "^Provides: "))

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

Requires(pre): simp-adapter >= 0.0.1
Requires(preun): simp-adapter >= 0.0.1
Requires(preun): simp-adapter >= 0.0.1
Requires(postun): simp-adapter >= 0.0.1

%if ("%{package_name}" != "pupmod-simp-simplib") && ("%{package_name}" != "pupmod-puppetlabs-stdlib")
Requires: pupmod-simp-simplib >= 1.2.6
%endif

%if "%{package_name}" != "pupmod-puppetlabs-stdlib"
Requires: pupmod-puppetlabs-stdlib >= 4.9.0
Requires: pupmod-puppetlabs-stdlib < 6.0.0
%endif

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
-- ----------------------------------------------------------------
-- function: define_custom_content
--
-- arguments:
--   content:              content to insert
--   custom_content_table: collection of custom content to insert
-- ----------
function define_custom_content(content, custom_content_table)
-- TODO: check for duplcate scriptlets!
  table.insert( custom_content_table, content )
end
}


%{lua:
-- ----------------------------------------------------------------
-- function: define_scriptlet
--
-- arguments:
--   scriptlet_name:    name of scriptlet or trigger section
--                      (e.g., '%pre', '%triggerin -- foo')
--   scriptlet_content: normal content of scriptlet
-- ----------
function define_scriptlet (scriptlet_name, scriptlet_content, defined_scriptlets_table, custom_content_table)
  local scriptlet_content = scriptlet_content or ''
  local scriptlet_pattern = "%f[^\n%z]" .. scriptlet_name .. "%f[^%w]"

  if ( not string.match(scriptlet_name, '^%%%l') ) then
    lua_stderr("  #stderr# LUA: WARNING: invalid scriptlet name '"..scriptlet_name.."'\n")
    do return end
  end
  if defined_scriptlets_table then
    for i,n in ipairs(defined_scriptlets_table) do
      if (n == scriptlet_name) then
        lua_stderr("  #stderr# LUA: WARNING: skipping duplicate scriptlet '"..scriptlet_name.."'\n")
        do return end
      end
    end
  end

  local expanded_content = rpm.expand(scriptlet_content) .. "\n\n"

  if not scriptlet_content:match(scriptlet_pattern) then
    expanded_content = scriptlet_name:match "^%s*(.-)%s*$" .. "\n" .. scriptlet_content
  end
  define_custom_content(expanded_content, custom_content_table)

  -- add name to list of scriplets (also triggers) we have seen
  table.insert(defined_scriptlets_table,scriptlet_name)
end

lua_stderr("   #stderr# LUA _specdir = '"..rpm.expand('%{_specdir}').."'\n")
lua_stderr("   #stderr# LUA _buildrootdir = '"..rpm.expand('%{_buildrootdir}').."'\n")
lua_stderr("   #stderr# LUA buildroot = '"..rpm.expand('%{buildroot}').."'\n")
lua_stderr("   #stderr# LUA RPM_BUILD_ROOT = '"..rpm.expand('%{RPM_BUILD_ROOT}').."'\n")
lua_stderr("   #stderr# LUA custom_content_dir = '"..custom_content_dir.."'\n# ---\n")


if (posix.stat(custom_content_dir, 'type') == 'directory') then
  for i,p in pairs(posix.dir(custom_content_dir)) do
    local scriptlet_path = custom_content_dir .. p
    if (string.match(p, '^[^.]') and (posix.stat(scriptlet_path, 'type') == 'regular')) then
      lua_stderr("   #stderr# LUA: WARNING: custom file found: " .. scriptlet_path .. "\n")
      local scriptlet_file = io.open(scriptlet_path)
      if scriptlet_file then
        local custom_content = scriptlet_file:read("*all")
        define_custom_content(custom_content, custom_content_table)
      else
        lua_stderr("   #stderr# LUA: WARNING: could not read "..scriptlet_path.."\n")
      end
    else
      lua_stderr("   #stderr# LUA: WARNING: rejected "..scriptlet_path.."\n")
    end
  end
else
  lua_stderr("   #stderr# LUA: WARNING: not found: " .. custom_content_dir .. "\n")
end

-- These are default scriptlets for SIMP 6.1.0
default_scriptlet_content = rpm.expand("/usr/local/sbin/simp_rpm_helper --rpm_dir=%{prefix}/%{module_name} --rpm_section='SECTION' --rpm_status=$1\n\n")

define_scriptlet('%pre', [[
# (default scriptlet for SIMP 6.x)
# when $1 = 1, this is an install
# when $1 = 2, this is an upgrade
]] .. default_scriptlet_content:gsub('SECTION','pre'),
  defined_scriptlets_table,
  custom_content_table
)

define_scriptlet('%post', [[
# (default scriptlet for SIMP 6.x)
# when $1 = 1, this is an install
# when $1 = 2, this is an upgrade
]] ..  default_scriptlet_content:gsub('SECTION','post'),
defined_scriptlets_table,
custom_content_table)

define_scriptlet('%preun', [[
# (default scriptlet for SIMP 6.x)
# when $1 = 1, this is an install
# when $1 = 0, this is an upgrade
]] ..  default_scriptlet_content:gsub('SECTION','preun'),
defined_scriptlets_table,
custom_content_table)

define_scriptlet('%postun', [[
# (default scriptlet for SIMP 6.x)
# when $1 = 1, this is an install
# when $1 = 0, this is an upgrade
]] ..  default_scriptlet_content:gsub('SECTION','postun'),
defined_scriptlets_table,
custom_content_table)

}

%{lua:
  -- insert custom content (e.g., rpm_metadata/custom/*, scriptlets)
  s = table.concat(custom_content_table, "\n") .. "\n"
  print(s)

  lua_stderr("  #stderr# LUA: WARNING: custom_content_table:\n----------------\n"..(s or "NIL").."\n-------------------------\n")
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
  if string.match(first_line, "^*%s+%a%a%a%s+%a%a%a%s+%d%d?%s+%d%d%d%d%s+.+") then
    changelog:seek("set",0)
    print(changelog:read("*all"))
  else
    print((default_changelog:gsub('$(%w+)', default_lookup_table)))
  end
else
  print((default_changelog:gsub('$(%w+)', default_lookup_table)))
end
}
