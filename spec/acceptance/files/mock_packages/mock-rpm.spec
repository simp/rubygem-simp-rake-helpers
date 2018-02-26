%{lua:
  package_name = rpm.expand('%{name}')
  package_version = rpm.expand('%{version}')
}
Name:           %{name}
Version:        %{version}
Release:        99
Summary:        test package to mock %{name}
BuildArch:      noarch

License:        Apache-2.0
URL:            http://foo.bar

%{lua:
  function lua_stderr( msg )
    io.stderr:write(msg)
  end
  local src_dir = rpm.expand('%{_sourcedir}')
  local src_file = src_dir .. '/files.tar.gz'
  if posix.stat(src_file , 'type') ~= 'regular' then
    lua_stderr( tostring(posix.stat(src_file , 'type') ) .. "\n" )
    error("\n\nERROR: "..tostring(src_file).." could not be used!\n\n")
  else
    lua_stderr("\n\nHOORAY HOORAY HOORAY: "..tostring(src_file).." could be used!\n\n")
  end
  print( "Source0: files.tar.gz\n" )
}


%description
A mock %{name} RPM package used for acceptance tests


%prep
%setup -q -n %{name}


%build


%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/
curdir=`pwd`
dirname=`basename $curdir`
cp -r ../$dirname %{buildroot}//%{name}

# Remove unnecessary assets
rm -rf %{buildroot}//%{name}/.git
rm -f %{buildroot}//%{name}/*.lock
rm -rf %{buildroot}//%{name}/spec/fixtures/modules
rm -rf %{buildroot}//%{name}/dist
rm -rf %{buildroot}//%{name}/junit
rm -rf %{buildroot}//%{name}/log


%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/

%files
%defattr(0640,root,root,0750)
/%{name}
%doc


%changelog
%{lua:

default_changelog = [===[
* $date Auto Changelog <auto@no.body> - $version-$release
- Latest mock release of $name
]===]

default_lookup_table = {
  date = os.date("%a %b %d %Y"),
  version = package_version,
  release = package_release,
  name = package_name
}

print((default_changelog:gsub('$(%w+)', default_lookup_table)))
}
