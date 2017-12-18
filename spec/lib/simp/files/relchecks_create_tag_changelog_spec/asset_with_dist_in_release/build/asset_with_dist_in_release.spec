Summary: SIMP Utils
Name: asset_with_dist_in_release
Version: 1.0.0
Release: 0%{?dist}
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
- Package with distribution in release tag
