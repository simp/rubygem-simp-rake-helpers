Name:           testpackage
Version:        1.0.0
Release:        0%{?dist}
Summary:        dummy test package #2
BuildArch:      noarch

License:        Apache-2.0
URL:            http://foo.bar

%{?el6:Requires: procps}
%{?el7:Requires: procps-ng}

%if 0%{?rhel} > 6
Requires: hostname
%endif

%description
A dummy package used to test Simp::Rpm::SpecFileInfo methods

%prep
exit 0

%build
exit 0


%install
exit 0

%clean
exit 0

%files
%doc

%changelog
* Wed Jun 10 2015 nobody <nobody@someplace.com> - 1.0.0
- The el6 macro has a value of '%{el6}'.
- The el7 macro has a value of '%{el7}'.
- The rhel macro has a value of '%{rhel}'.
