Name:           asset-multi-macro
Version:        1.0.0
Release:        0%{?dist}
Group:          Applications/System
Source:         %{name}-%{version}-%{release}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Summary:        dummy test package
BuildArch:      noarch

License:        Apache-2.0
URL:            http://foo.bar

%{?el6:Requires: procps}
%{?el7:Requires: procps-ng}

%if 0%{?rhel} > 6
Requires: hostname
%endif

%description
A dummy package used to test Simp::Rpm::Builder methods

%prep
%setup -q

%build


%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/local/bin
cp -p scripts/* %{buildroot}/usr/local

mkdir -p %{buildroot}/usr/local/share/asset-multi-macros
cp -p docs/README  %{buildroot}/usr/local/share/asset-multi-macros

%clean

%files
%defattr(-,root,root)
%attr(0755,-,-) /usr/local/bin/helloworld.sh

%files doc
%doc /usr/local/share/asset-multi-macros/README


%package doc
Summary:        Documentation for dummy test package #2
License:        Apache-2.0

%description doc
Documentation for the dummy package used to test Simp::Rpm::Builder


%changelog
* Wed Jun 10 2015 nobody <nobody@someplace.com> - 1.0.0
- some comment
