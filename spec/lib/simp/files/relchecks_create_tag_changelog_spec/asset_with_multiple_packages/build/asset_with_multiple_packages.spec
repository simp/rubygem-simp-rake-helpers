%global gemname main

%global gemdir /usr/share/simp/ruby
%global geminstdir %{gemdir}/gems/%{gemname}-%{version}
%global main_version 4.0.3
%global sub_version 1.7.8

Summary: a main package
Name: main
Version: %{main_version}
Release: 0
Group: Development/Languages
License: Apache-2.0
Source0: %{name}-%{main_version}-%{release}.tar.gz
Source1: %{gemname}-%{main_version}.gem
BuildArch: noarch
Provides: rubygem(%{gemname}) = %{main_version}

%description
main package

%package doc
Summary: Documentation for %{name}
Group: Documentation
BuildArch: noarch

%description doc
Documentation for %{name}

%package sub
Summary: A sub package
Version: %{sub_version}
Release: 0
License: GPL-2.0
Source11: sub-%{sub_version}.gem
BuildArch: noarch
Provides: rubygem(%{gemname}-sub) = %{sub_version}

%description sub
sub is required for the proper functionality of main

%prep

%build

%install

%files

%files sub

%files doc

%changelog
* Thu Aug 31 2017 Jane Doe <jane.doe@simp.com> - 4.0.3
- Fix bug Z
  - Thanks to Lilia Smith for the PR!

* Mon Jun 12 2017 Jane Doe <jane.doe@simp.com> - 4.0.3
- Prompt user for new input

* Fri Jun 02 2017 Jim Jones <jim.jones@simp.com> - 4.0.2
- Expand X
- Fix Y
