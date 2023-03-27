#!/bin/bash
#
# This script record factsets for various versions of cfacter & facter into
# JSON files.  It is run as the vagrant user
#
operatingsystem=$( echo "$1" | cut -f1 -d' ' )
operatingsystemmajrelease=$( echo "$1" | cut -f2 -d' ' )

if [ -z "$operatingsystem" ] || [ -z "$operatingsystemmajrelease" ]; then
  echo "You must pass an operating system and version to $0"
  exit 1
fi

if [ "$operatingsystem" == "$operatingsystemmajrelease" ]; then
  echo "Your OS is the same as your version and this does not make sense"
  exit 1
fi

export PATH=/opt/puppetlabs/bin:$PATH
export FACTERLIB=`ls -1d /vagrant/modules/*/lib/facter | tr '\n' ':'`

which dnf > /dev/null 2>&1
if [ $? -eq 0 ]; then
  rpm_cmd='sudo dnf --best --allowerasing'
else
  rpm_cmd='sudo yum --skip-broken'
fi

if [ "${operatingsystem}" != 'fedora' ]; then
  plabs_ver='el'

  $rpm_cmd install -y --nogpgcheck https://dl.fedoraproject.org/pub/epel/epel-release-latest-${operatingsystemmajrelease}.noarch.rpm
else
  plabs_ver=$operatingsystem
fi

$rpm_cmd remove -y puppet* ||:

$rpm_cmd install -y --nogpgcheck "https://yum.puppetlabs.com/puppetlabs-release-pc1-${plabs_ver}-${operatingsystemmajrelease}.noarch.rpm"
$rpm_cmd install -y --nogpgcheck "https://yum.puppetlabs.com/puppetlabs-release-pc1-${plabs_ver}-${operatingsystemmajrelease}.noarch.rpm"
$rpm_cmd install -y https://yum.puppetlabs.com/puppet5/puppet5-release-${plabs_ver}-${operatingsystemmajrelease}.noarch.rpm

# Prereqs
$rpm_cmd install -y facter rubygem-bundler git augeas-devel \
  libicu-devel libxml2 libxml2-devel libxslt libxslt-devel \
  gcc gcc-c++ ruby-devel audit bind-utils net-tools rubygem-json

# Work around libcurl issues
$rpm_cmd update -y libcurl openssl nss

to_scrub='.to_scrub'
echo '' > $to_scrub

# Capture data for (c)facter 3.X
#                           oldLTS                   *LTS*
# PE                        2016.4  2016.5  2017.2   2018.1   2019.3
# SIMP                              6.0     6.1,6.2  6.3,6.4
# ------                    ------  ------  ------   ------   ------
# Puppet                    4.7.1   4.8.2   4.10.4   5.5.18   6.12.0
# Facter                    3.4.2   3.5.1   3.6.5    3.11.10  3.14.0
for puppet_agent_version in 1.7.2   1.8.3   1.10.4   5.5.18   6.12.0; do
  rpm -qi puppet-agent > /dev/null && $rpm_cmd remove -y puppet-agent
  $rpm_cmd install -y puppet-agent-$puppet_agent_version
  facter_version=$( facter --version | cut -c1-3 )
  output_dir="/vagrant/${facter_version}"
  echo
  echo "---------------- facter: '${facter_version}'  puppet agent version: '${puppet_agent_version}'"
  echo
  output_file="$( facter operatingsystem | tr '[:upper:]' '[:lower:]' )-$( facter operatingsystemmajrelease )-$( facter hardwaremodel ).facts"
  raw_file="${output_dir}/${output_file}.raw"
  mkdir -p $output_dir
  puppet facts --render-as=json > "${raw_file}"
  /opt/puppetlabs/puppet/bin/ruby -r json -e 'jj JSON.parse(File.read(ARGV[0]))["values"]' "${raw_file}" | tee "${output_dir}/${output_file}" && rm -f "${raw_file}"

  /opt/puppetlabs/puppet/bin/facter gce --strict |&> /dev/null
  if [ $? -eq 0 ]; then
    echo "${output_dir}/${output_file}" >> $to_scrub
  fi
done

operatingsystem=$( facter operatingsystem | tr '[:upper:]' '[:lower:]' )
operatingsystemmajrelease=$( facter operatingsystemmajrelease )
hardwaremodel=$( facter hardwaremodel )

$rpm_cmd remove -y puppet-agent ||:

export PUPPET_VERSION="~> 5.5"

# RVM Install for isolation
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable
source /usr/local/rvm/scripts/rvm
rvm install 2.4.5
rvm use 2.4.5 --default

gem install bundler --no-ri --no-rdoc --no-format-executable
bundle install --path vendor/bundler

# Capture data for ruby-based facters (2.5 only for now)
for version in 2.5.7 ; do
  FACTER_GEM_VERSION="~> ${version}" PUPPET_VERSION="~> 5.5" bundle update
  os_string="$(FACTER_GEM_VERSION="~> ${version}" PUPPET_VERSION="~> 5.5" bundle exec facter --version | cut -c1-3)/${operatingsystem}-${operatingsystemmajrelease}-${hardwaremodel}"
  echo
  echo
  echo  ============== ${os_string} ================
  echo
  echo
  output_file="/vagrant/${os_string}.facts"
  mkdir -p $( dirname $output_file )
  FACTER_GEM_VERSION="~> ${version}" PUPPET_VERSION="~> 5.5" bundle exec ruby /vagrant/scripts/get_facts.rb | tee $output_file
done

for file in `cat $to_scrub`; do
  if [ -f $file ]; then
    bundle exec ruby /vagrant/scripts/gce_scrub_data.rb $file
  fi
done
