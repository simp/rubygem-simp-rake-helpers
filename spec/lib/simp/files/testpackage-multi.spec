Name:           testpackage-multi-1
Version:        1
Release:        0
Summary:        dummy test package #2
BuildArch:      noarch

License:        Apache-2.0
URL:            http://foo.bar

%description
A dummy package used to test Simp::RPM methods

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


%package testpackage-multi-2
Summary:        dummy test package #2
License:        Apache-2.0

%description testpackage-multi-2
A dummy package used to test Simp::RPM methods


%changelog
* Wed Jun 10 2015 nobody
- some comment
