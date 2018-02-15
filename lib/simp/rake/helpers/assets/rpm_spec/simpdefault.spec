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
--   * 'build/rpm_metadata/scriptlets/' <- optional directory to place files to
--                                         add custom scriptlets and triggers.
--
-- If this is not found in 'pup_module_info_dir', we will look in '_sourcedir'
-- for the files, and fall back to the current directory
--

src_dir = rpm.expand('%{pup_module_info_dir}')

if string.match(src_dir, '^%%') or (posix.stat(src_dir, 'type') ~= 'directory') then
  -- NOTE: rpmlint considers this an E:
  src_dir = rpm.expand('%{_sourcedir}')

  if (posix.stat((src_dir .. "/metadata.json"), 'type') ~= 'regular') then
    src_dir = posix.getcwd()
  end
  io.stderr:write("  #stderr# LUA: WARNING: pup_module_info_dir ("..(src_dir or "NIL")..") could not be used!\n")
  io.stderr:write("  #stderr# LUA:          falling back to src_dir = _sourcedir\n")

  -- FIXME: rpmlint considers the use of _sourcedir to be an Error:
  src_dir = rpm.expand('%{_sourcedir}')

  if (posix.stat((src_dir .. "/metadata.json"), 'type') ~= 'regular') then
    io.stderr:write("  #stderr# LUA: WARNING: couldn't find metadata.json in '"..(src_dir or "NIL").."'!\n")
    io.stderr:write("  #stderr# LUA:          falling back to src_dir = posix.getcwd() ("..posix.getcwd()..")\n")

    src_dir = posix.getcwd()
  end

end

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

custom_content_lines = {}
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
-- function: define_scriptlet
--
-- arguments:
--
--   scriptlet_name:    name of scriptlet or trigger section
--                      (e.g., 'pre', 'triggerin -- foo')
--   scriptlet_content: normal content of scriptlet
-- ----------------------------------------------------------------
function define_scriptlet (scriptlet_name, scriptlet_content, defined_scriptlets)
  local scriptlet_content = scriptlet_content or ''
  local scriptlet_pattern = "%f[^\n%z]%%" .. scriptlet_name .. "%f[^%w]"

  if ( not string.match(scriptlet_name, '^%l') ) then
    io.stderr:write("  #stderr# LUA: WARNING: invalid scriptlet name '"..scriptlet_name.."'\n")
    do return end
  end
  if defined_scriptlets then
    for i,n in ipairs(defined_scriptlets) do
      if (n == scriptlet_name) then
        io.stderr:write("  #stderr# LUA: WARNING: skipped duplicate scriptlet '"..scriptlet_name.."'\n")
        do return end
      end
    end
  end

  scriptlet_content = scriptlet_content:gsub('%%{scriptlet_name}',scriptlet_name)
  scriptlet_content = rpm.expand(scriptlet_content)

  if not scriptlet_content:match(scriptlet_pattern) then
    table.insert( custom_content_lines, "%" .. scriptlet_name:match "^%s*(.-)%s*$" )
  end
  -- print the content into the spec
  table.insert( custom_content_lines, scriptlet_content.. "\n\n")


  -- add scriptlet name to things we have already defined
  table.insert(defined_scriptlets,scriptlet_name)
end

------------------------------------------------------------------------------
------------------------------------------------------------------------------
-------------------- TODO:                                                  --
---------------------   custom/ directory instead of scriptlets             --
---------------------   scan for known scriptlets in order to override them --
------------------------------------------------------------------------------
------------------------------------------------------------------------------

default_scriptlet_content = "/usr/local/sbin/simp_rpm_helper --rpm_dir=%{prefix}/%{module_name} --rpm_section='%{scriptlet_name}' --rpm_status=$1\n\n"

scriptlets_dir = src_dir .. "/scriptlets/"

io.stderr:write("   #stderr# LUA _specdir = '"..rpm.expand('%{_specdir}').."'\n")
io.stderr:write("   #stderr# LUA _buildrootdir = '"..rpm.expand('%{_buildrootdir}').."'\n")
io.stderr:write("   #stderr# LUA buildroot = '"..rpm.expand('%{buildroot}').."'\n")
io.stderr:write("   #stderr# LUA RPM_BUILD_ROOT = '"..rpm.expand('%{RPM_BUILD_ROOT}').."'\n")
io.stderr:write("   #stderr# LUA scriptlets_dir = '"..scriptlets_dir.."'\n# ---\n")

defined_scriptlets = {}
if (posix.stat(scriptlets_dir, 'type') == 'directory') then
  for i,p in pairs(posix.dir(scriptlets_dir)) do
    local scriptlet_path = scriptlets_dir .. p
    if (posix.stat(scriptlet_path, 'type') == 'regular') then
      local scriptlet_file = io.open(scriptlet_path)
      if scriptlet_file then
        local scriptlet_content = scriptlet_file:read("*all")
        define_scriptlet(p,scriptlet_content, defined_scriptlets)
      else
        io.stderr:write("   #stderr# LUA: WARNING: could not read "..scriptlet_path.."\n")
      end
    end
  end
else
  io.stderr:write("   #stderr# LUA: WARNING: not found: " .. scriptlets_dir .. "\n")
end

-- These are default scriptlets for SIMP 6.1.0
define_scriptlet('pre',
"# (default scriptlet for SIMP 6.x)\n" ..
"# when $1 = 1, this is an install\n" ..
"# when $1 = 2, this is an upgrade\n" ..
default_scriptlet_content,
defined_scriptlets )

define_scriptlet('post',
"# (default scriptlet for SIMP 6.x)\n" ..
"# when $1 = 1, this is an install\n" ..
"# when $1 = 2, this is an upgrade\n" ..
default_scriptlet_content,
defined_scriptlets )

define_scriptlet('preun',
"# (default scriptlet for SIMP 6.x)\n" ..
"# when $1 = 1, this is an install\n" ..
"# when $1 = 0, this is an upgrade\n" ..
default_scriptlet_content,
defined_scriptlets )

define_scriptlet('postun',
"# when $1 = 1, this is an install\n" ..
"# when $1 = 0, this is an upgrade\n" ..
default_scriptlet_content,
defined_scriptlets )

}

%{lua:
  s = table.concat(custom_content_lines, "\n") .. "\n"
  print(s)
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
