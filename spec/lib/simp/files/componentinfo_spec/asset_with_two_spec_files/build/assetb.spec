Summary: SIMP Utils
Name: assetb
Version: 1.1.0
Release: 0
License: Apache License, Version 2.0
Group: Applications/System
Source: %{name}-%{version}-%{release}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch: noarch

%description
AssetB

%prep
%setup -q

%build

%install

%clean

%files

%post

%postun

%changelog

* Wed Oct 18 2017 Lois Lane <lois.lane@example.com> - 1.1.0-0
- Added script A2

* Wed Oct 04 2017 Super Man <super.man@example.com> - 1.0.2-0
- Fixed an incorrect dependency

* Fri Jan 18 2013 Maintenance
1.0.1-0
- Fixed script A1

* Tue Nov 20 2012 Maintenance
1.0.0-0
- First version
