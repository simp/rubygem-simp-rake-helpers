Name:           simp-adapter
Version:        0.9.9
Release:        9
Summary:        mock simplib test package
BuildArch:      noarch

License:        Apache-2.0
URL:            http://foo.bar

Source0: files.tar.gz

%description
A mock RPM package used for acceptance tests

%prep
echo ================ PWD: $PWD
%setup -c

%build


%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}
mkdir -p %{buildroot}/opt/test/puppet/code
cp -r $PWD/* %{buildroot}/
rm -rf %{buildroot}/**/.*.swp
rm -rf %{buildroot}/opt/puppetlabs

%clean

%files
%defattr(0640,root,root,0755)

%attr(0750,root,root)/usr/local/sbin/simp_rpm_helper
#%attr(0755,root,root)/opt/puppetlabs/puppet/bin/ruby
#%attr(0755,root,root)/opt/puppetlabs/bin/puppet
%attr(0644,root,root)/etc/simp/adapter_config.yaml
%dir  /opt/test/puppet/code


%changelog
* Fri Feb 23 2018 nobody
- some comment
