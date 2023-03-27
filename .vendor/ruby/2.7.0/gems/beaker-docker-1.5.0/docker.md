This option allows for testing against Docker containers.


### Why?

Using docker as a hypervisor significantly speeds up the provisioning process, as you don't have to spin up an entire VM to run the tests, which has significant overhead.

### How?

So first of all, install Docker using the instructions [here](https://docs.docker.com/installation/#installation).

In the real world, it's generally seen as [bad practice to have sshd running in a Docker container](http://blog.docker.com/2014/06/why-you-dont-need-to-run-sshd-in-docker/). However, for the purpose of a disposable test instance, we're not going to worry about that!

### Basic docker hosts file ###
The base image to use for the container is named by the image key.

    HOSTS:
      ubuntu-12-10:
        platform: ubuntu-12.10-x64
        image: ubuntu:12.10
        hypervisor: docker
    CONFIG:
      type: foss

### Docker hosts file, with image modification ###
You can specify extra commands to be executed in order to modify the image with the keys `docker_image_commands` and
`docker_image_first_commands`.

`docker_image_commands` is executed after initial setup. `docker_image_first_commands` is executed before any other
commands and can be used eg. to configure a proxy.

    HOSTS:
      ubuntu-12-10:
        platform: ubuntu-12.10-x64
        image: ubuntu:12.10
        hypervisor: docker
        docker_image_first_commands:
          - echo 'Acquire::http::Proxy "http://proxy.example.com:3128";'> /etc/apt/apt.conf.d/01proxy
          - echo "export http_proxy=http://proxy.example.com:3128"> /etc/profile.d/proxy.sh
          - echo "export https_proxy=http://proxy.example.com:3128">> /etc/profile.d/proxy.sh
          - echo "export no_proxy=127.0.0.1,::1">> /etc/profile.d/proxy.sh
        docker_image_commands:
          - 'apt-get install -y myapp'
          - 'myapp --setup'
    CONFIG:
      type: foss

### Docker hosts files, with modified start commands ###
By default the docker container just runs an sshd which is adequate for 'puppet apply' style testing. You can specify a different command to start with the `docker_cmd` key. This gives you scope to run something with more service supervision baked into it, but it is is important that this command starts an sshd listening on port 22 so that beaker can drive the container.

    HOSTS:
      ubuntu-12-10:
        platform: ubuntu-12.10-x64
        image: ubuntu:12.10
        hypervisor: docker
        docker_cmd: '["/sbin/init"]'
    CONFIG:
      type: foss

### Using the entrypoint of an image and not sshd ###
Instead of using ssh as the CMD for a container, beaker will use the entrypoint already defined if `use_image_entry_point` is used. Beaker will still load ssh onto the container and start it, but ssh will not be the entrypoint for the container. Below is an example of using the puppetserver image.

    HOSTS:
      puppetserver:
        platform: ubuntu-1604-x86_64
        hypervisor: docker
        image: puppet/puppetserver-standalone:6.0.1
        use_image_entry_point: true
        roles:
          - master
    CONFIG:
      type: foss

### Using dockerfiles with beaker hosts files ###
Beaker can utilize a dockerfile specified in hosts file; use the `dockerfile` attribute of a host to specify the location of the dockerfile. Beaker will use the directory it is run in to pass as the context for dockerfile DSL commands such as COPY and VOLUME, so make sure the paths are set correctly for the right context.

    HOSTS:
      ubuntu-12-10:
        platform: ubuntu-12.10-x64
        dockerfile: path/to/my/dockerfile
        hypervisor: docker
        docker_cmd: '["/sbin/init"]'
    CONFIG:
      type: foss

### Preserve Docker Image ###
Unless the image configuration changes you might want to keep the Docker image for multiple spec runs. Use `docker_preserve_image` option for a host.

    HOSTS:
      ubuntu-12-10:
        platform: ubuntu-12.10-x64
        image: ubuntu:12.10
        hypervisor: docker
        docker_preserve_image: true
    CONFIG:
      type: foss

### Tag a built Docker Image ###
Tag an image after creation; this allows for subsequent hosts to reference that image for multi-stage builds.

    HOSTS:
      ubuntu-12-10:
        platform: ubuntu-12.10-x64
        dockerfile: path/to/file
        hypervisor: docker
        tag: build_host
      mysecondhost:
        dockerfile: path/to/file # file references build_host
        platform: alpine-3.8-x86_64
        hypervisor: docker
    CONFIG:
      type: foss

### Reuse Docker Image ###
In case you want to rerun the puppet again on the docker container, you can pass BEAKER_provision=no on the command line to set the env. Add this line in you default.ml file

```
HOSTS:
  centos6-64:
    roles:
     - agent
    platform: el-6-x86_64
    image: centos:6.6
    hypervisor: docker
CONFIG:
  type: foss
  log_level: verbose
ssh:
  password: root
  auth_methods: ["password"]
```

### Mounting volumes into your docker container ###
You can mount folders into a docker container:

    HOSTS:
      ubuntu-12-10:
        platform: ubuntu-12.10-x64
        image: ubuntu:12.10
        hypervisor: docker
        mount_folders:
          name1:
            host_path: host_path1
            container_path: container_path1
          name2:
            host_path: host_path2
            container_path: container_path2
            opts: rw
    CONFIG:
      type: foss

### Example Output

For this example made a new docker nodeset file in the [puppetlabs-inifile](https://github.com/puppetlabs/puppetlabs-inifile) repo and ran the ini_setting_spec.rb spec:

```bash
$ bundle exec rspec spec/acceptance/ini_setting_spec.rb
Hypervisor for debian-7 is docker
Beaker::Hypervisor, found some docker boxes to create
Provisioning docker
provisioning debian-7
Creating image
Dockerfile is         FROM debian:7.4
          RUN apt-get update
          RUN apt-get install -y openssh-server openssh-client curl ntpdate lsb-release
        RUN mkdir -p /var/run/sshd
        RUN echo root:root | chpasswd
RUN apt-get install -yq lsb-release wget net-tools ruby rubygems ruby1.8-dev libaugeas-dev libaugeas-ruby ntpdate locales-all
RUN REALLY_GEM_UPDATE_SYSTEM=1 gem update --system --no-ri --no-rdoc
        EXPOSE 22
        CMD ["/sbin/init"]
```

This step may take a while, as Docker will have to download the image. The subsequent runs will be a lot faster (as long as `docker_preserve_image: true` has been enabled).

For example, running this took 5 minutes to download and setup the `debian:7.4` image, but runs instantly the second time.

You should then see something like:

```
Creating container from image 3a86e5aba94d
post
/v1.15/containers/create
{}
{"Image":"3a86e5aba94d","Hostname":"debian-7"}
Starting container b8b31702b34b4aedd137c8a6a72fe730560bb00533e68764ba6263405f9244e4
post
/v1.15/containers/b8b31702b34b4aedd137c8a6a72fe730560bb00533e68764ba6263405f9244e4/start
{}
{"PublishAllPorts":true,"Privileged":true}
Using docker server at 192.168.59.103
get
/v1.15/containers/b8b31702b34b4aedd137c8a6a72fe730560bb00533e68764ba6263405f9244e4/json
{}

node available as  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@192.168.59.103 -p 49155
```

The tests should then run as normal from there.


### Docker-in-Docker (dind) ###
If you are using docker in docker, set the environment variable DOCKER_IN_DOCKER=true. Beaker-docker will then not try to use the DOCKER_HOST address for the ssh connection to the containers.
