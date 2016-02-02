Name:           testpackage
Version:        1
Release:        0%{?dist}
Summary:        a test package

License:        Apache-2.0
URL:            http://this.is.a.test
Source0:        %{name}-%{version}-%{release}.tar.gz

BuildRequires:  nothing
Requires:       something

%description

A test package!

%prep
%setup -q


%build
%configure
make %{?_smp_mflags}


%install
rm -rf $RPM_BUILD_ROOT
%make_install


%files
%doc


%changelog
* Wed Jun 10 2015 nobody
- some comment
