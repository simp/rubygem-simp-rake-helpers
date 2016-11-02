%{lua:

--
-- When you build you must to pass this along so that we know how
-- to get the preliminary information.
-- This directory should hold the following items:
--   * 'build/rpm_metadata/requires' <- optional list of 'Requires', 'Provides',
--      and 'Obsoletes' to supplement those auto-generated in this spec file
--   * 'build/rpm_metadata/release' <- optional RPM release number to use in
--      lieu of number hard-coded in this spec file
--   * 'CHANGELOG' <- optional RPM formatted Changelog to use in lieu of minimal,
--      changelog entry auto-generated in this spec file
--   * 'metadata.json' <- required file that must contain the following metadata:
--     - 'name' - package name
--     - 'version' - package version
--     - 'license' - package license
--     - 'summary' - package summary
--     - 'source' - package source
--
-- Example:
--   rpmbuild -D 'pup_module_info_dir /home/user/project/puppet_module' -ba SPECS/specfile.spec
--
-- If this is not found, we will look in %{_sourcedir} for the files and fall
-- back to the current directory
--

src_dir = rpm.expand('%{pup_module_info_dir}')

if string.match(src_dir, '^%%') or (posix.stat(src_dir, 'type') ~= 'directory') then
  src_dir = rpm.expand('%{_sourcedir}')

  if (posix.stat((src_dir .. "/metadata.json"), 'type') ~= 'regular') then
    src_dir = './'
  end
end

-- These UNKNOWN entries should break the build if something bad happens

package_name = "UNKNOWN"
package_version = "UNKNOWN"
module_license = "UNKNOWN"

--
-- Default to 2016
-- This was done due to the change in naming scheme across all of the modules.
-- The '.1' bump is there for the SIMP 6 path changes
--

package_release = '2016.1'

}

%{lua:
-- Pull the Relevant Metadata out of the Puppet module metadata.json.

metadata = ''
metadata_file = io.open(src_dir .. "/metadata.json","r")
if metadata_file then
  metadata = metadata_file:read("*all")

  -- Ignore the first curly brace
  metadata = metadata:gsub("{}?", '|', 1)

  -- Ignore all keys that are below the first level
  metadata = metadata:gsub("{.-}", '')
  metadata = metadata:gsub("%[.-%]", '')
else
  error("Could not open 'metadata.json'", 0)
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

Requires(pre,preun,post,postun): simp-adapter >= 0.0.1

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
rm -rf %{buildroot}/%{prefix}/%{module_name}/.git
rm -f %{buildroot}/%{prefix}/*.lock
rm -rf %{buildroot}/%{prefix}/spec/fixtures/modules
rm -rf %{buildroot}/%{prefix}/dist
rm -rf %{buildroot}/%{prefix}/junit
rm -rf %{buildroot}/%{prefix}/log

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}

%files
%defattr(0640,root,root,0750)
%{prefix}/%{module_name}

# when $1 = 1, this is an install
# when $1 = 2, this is an upgrade
%pre
/usr/local/sbin/simp_rpm_helper --rpm_dir=%{prefix}/%{module_name} --rpm_section='pre' --rpm_status=$1

# when $1 = 1, this is an install
# when $1 = 2, this is an upgrade
%post
/usr/local/sbin/simp_rpm_helper --rpm_dir=%{prefix}/%{module_name} --rpm_section='post' --rpm_status=$1

# when $1 = 1, this is the uninstall of the previous version during an upgrade
# when $1 = 0, this is the uninstall of the only version during an erase
%preun
/usr/local/sbin/simp_rpm_helper --rpm_dir=%{prefix}/%{module_name} --rpm_section='preun' --rpm_status=$1

# when $1 = 1, this is the uninstall of the previous version during an upgrade
# when $1 = 0, this is the uninstall of the only version during an erase
%postun
/usr/local/sbin/simp_rpm_helper --rpm_dir=%{prefix}/%{module_name} --rpm_section='postun' --rpm_status=$1

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
