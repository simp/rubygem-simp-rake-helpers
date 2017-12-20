Summary: SIMP Utils
Name: asset_mismatched_release
Version: 1.0.0
Release: RC1
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

* Wed Oct 18 2017 Jane Doe <jane.doe@simp.com> - 1.0.0-0
- OOPS mismatched release qualifier

* Wed Nov 04 2009 Maintenance
0.1-0
- Added the man page
