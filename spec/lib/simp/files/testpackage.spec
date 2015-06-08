Name:           testpackage
Version:        1
Release:        0%{?dist}
Summary:        a test package

License:        Apache-2.0
URL:
Source0:

BuildRequires:
Requires:

%description


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
