%{lua:

--
-- When you build you must to pass this along so that we know how
-- to get the preliminary information.
-- This directory should hold the following items:
--   * 'build' directory
--   * 'CHANGELOG' <- The RPM formatted Changelog
--   * 'metadata.json'
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
--

package_release = '2016'

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
  print("Error: Could not find valid package name in 'metadata.json'")
end

}

%{lua:

-- Get the Module Version
-- This will not be processed at all

local version_match = string.match(metadata, '"version":%s+"(.-)"%s*,')

if version_match then
  package_version = version_match
end

}

%{lua:

-- Get the Module License
-- This will not be processed at all

local license_match = string.match(metadata, '"license":%s+"(.-)"%s*,')

if license_match then
  module_license = license_match
end

}

%{lua:

-- Get the Module Summary
-- This will not be processed at all

local summary_match = string.match(metadata, '"summary":%s+"(.-)"%s*,')

if summary_match then
  module_summary = summary_match
end

}

%{lua:

-- Get the Module Source line for the URL string
-- This will not be processed at all

local source_match = string.match(metadata, '"source":%s+"(.-)"%s*,')

if source_match then
  module_source = source_match
end

}

%{lua:

-- Snag the RPM-specific items out of the 'build/rpm_metadata' directory

-- First, the Release Number

local rel_file = io.open(src_dir .. "/build/rpm_metadata/release", "r")
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
local req_file = io.open(src_dir .. "/build/rpm_metadata/requires", "r")
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
%define base_name %{lua: print(package_name)}

%{lua:
-- Determine which Variant we are going to build

local variant = rpm.expand("%{_variant}")
local variant_version = nil

local foo = ""

local i = 0
for str in string.gmatch(variant,'[^-]+') do
  if i == 0 then
    variant = str
  elseif i == 1 then
    variant_version = str
  else
    break
  end

  i = i+1
end

rpm.define("variant " .. variant)

if variant == "pe" then
  rpm.define("puppet_user pe-puppet")
else
  rpm.define("puppet_user puppet")
end

if variant == "pe" then
  if variant_version and ( rpm.vercmp(variant_version,'4') >= 0 ) then
    rpm.define("_sysconfdir /etc/puppetlabs/code")
  else
    rpm.define("_sysconfdir /etc/puppetlabs/puppet")
  end
elseif variant == "p4" then
  rpm.define("_sysconfdir /etc/puppetlabs/code")
else
  rpm.define("_sysconfdir /etc/puppet")
end
}

Summary:   %{module_name} Puppet Module
%if 0%{?_variant:1}
Name:      %{base_name}-%{_variant}
%else
Name:      %{base_name}
%endif

Version:   %{lua: print(package_version)}
Release:   %{lua: print(package_release)}
License:   %{lua: print(module_license)}
Group:     Applications/System
Source0:    %{base_name}-%{version}-%{release}.tar.gz
Source1:   %{lua: print("metadata.json")}
%{lua:
  -- Include our sources as appropriate
  changelog = io.open(src_dir .. "/CHANGELOG","r")
  if changelog then
    print("Source2: " .. "CHANGELOG")
  end

  if rel_file then
    print("Source3: " .. "build/rpm_metadata/release")
  end
  if req_file then
    print("Source4: " .. "build/rpm_metadata/requires")
  end
}
URL:       %{lua: print(module_source)}
BuildRoot: %{_tmppath}/%{base_name}-%{version}-%{release}-buildroot
BuildArch: noarch

%if "%{variant}" == "pe"
Requires: pe-puppet >= 3.8.6
%else
Requires: puppet >= 3.8.6
%endif

%if ("%{base_name}" != "pupmod-simp-simplib") && ("%{base_name}" != "pupmod-puppetlabs-stdlib")
Requires: pupmod-simp-simplib >= 1.2.6
%endif

%if "%{base_name}" != "pupmod-puppetlabs-stdlib"
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

Prefix: %{_sysconfdir}/environments/simp/modules

%description
%{lua: print(module_summary)}

%prep
%setup -q -n %{base_name}-%{version}

%build

%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}

rm -rf .git
rm -f *.lock
rm -rf spec/fixtures/modules
rm -rf dist
rm -rf junit
rm -rf log

curdir=`pwd`
dirname=`basename $curdir`
cp -r ../$dirname %{buildroot}/%{prefix}/%{module_name}

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}

%files
%defattr(0640,root,%{puppet_user},0750)
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
