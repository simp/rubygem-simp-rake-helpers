Summary: SIMP Utils
Name: asset_with_single_package
Version: 1.0.0
Release: 1
License: Apache License, Version 2.0
Group: Applications/System
Source: %{name}-%{version}-%{release}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch: noarch

%description
Asset with single entry

%prep

%build

%install

%clean

%files

%post

%postun

%changelog
* Wed Oct 18 2017 Jane Doe <jane.doe@simp.com> - 1.0.0-1
- Fix installed file permissions

* Wed Oct 18 2017 Jane Doe <jane.doe@simp.com> - 1.0.0-0
- Single package

* Wed Nov 04 2009 Maintenance
0.1-0
- Added the man page
