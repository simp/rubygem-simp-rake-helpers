cwd=$PWD  # run this from the module's root directory
nodeset=centos-7-x64.yml
sut=server

# rsync module fixtures into "server"
cd $cwd; rsync -av --no-links spec/fixtures/modules .vagrant/beaker_vagrant_files/${nodeset}/ && rsync -av --no-links --exclude=.git --exclude=.vagrant --exclude=spec ./ .vagrant/beaker_vagrant_files/${nodeset}/modules/simp_gitlab/ && cd .vagrant/beaker_vagrant_files/${nodeset}/ &&  
vagrant rsync ${sut}; vagrant ssh ${sut} -- sudo rsync -av /vagrant/modules/ /etc/puppetlabs/code/environments/production/modules/; cd $cwd
