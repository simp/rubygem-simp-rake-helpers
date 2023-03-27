PUPPERWARE_ANALYTICS_STREAM ?= dev
NAMESPACE ?= puppet
git_describe = $(shell git describe --tags)
vcs_ref := $(shell git rev-parse HEAD)
build_date := $(shell date -u +%FT%T)
hadolint_available := $(shell hadolint --help > /dev/null 2>&1; echo $$?)
hadolint_command := hadolint
hadolint_container := ghcr.io/hadolint/hadolint:latest
alpine_version := 3.14
# --load (--output=type=docker) can only be used with a single arch / platform
# https://github.com/docker/buildx/issues/59
output_type := docker
platform := linux/amd64
export BUNDLE_PATH = $(PWD)/.bundle/gems
export BUNDLE_BIN = $(PWD)/.bundle/bin
export GEMFILE = $(PWD)/Gemfile
export DOCKER_BUILDKIT ?= 1

ifeq ($(IS_RELEASE),true)
	VERSION ?= $(shell echo $(git_describe) | sed 's/-.*//')
	PUBLISHED_VERSION ?= $(shell curl --silent 'https://rubygems.org/api/v1/gems/r10k.json' | jq '."version"' | tr -d '"')
	CONTAINER_EXISTS = $(shell DOCKER_CLI_EXPERIMENTAL=enabled docker manifest inspect $(NAMESPACE)/r10k:$(VERSION) > /dev/null 2>&1; echo $$?)
ifeq ($(CONTAINER_EXISTS),0)
	SKIP_BUILD ?= true
else ifneq ($(VERSION),$(PUBLISHED_VERSION))
	SKIP_BUILD ?= true
endif

	LATEST_VERSION ?= latest
	dockerfile := release.Dockerfile
	dockerfile_context := r10k
else
	VERSION ?= edge
	IS_LATEST := false
	dockerfile := Dockerfile
	dockerfile_context := $(PWD)/..
endif

ifeq ($(IS_LATEST),true)
	latest_tag := --tag $(NAMESPACE)/r10k:$(LATEST_VERSION)
endif

prep:
	@git fetch --unshallow 2> /dev/null ||:
	@git fetch origin 'refs/tags/*:refs/tags/*'
ifeq ($(SKIP_BUILD),true)
	@echo "SKIP_BUILD is true, exiting with 1"
	@exit 1
endif

lint:
ifeq ($(hadolint_available),0)
	@$(hadolint_command) r10k/$(dockerfile)
else
	@docker pull $(hadolint_container)
	@docker run --rm -v $(PWD)/r10k/$(dockerfile):/Dockerfile -i $(hadolint_container) $(hadolint_command) Dockerfile
endif

build: prep
	docker pull alpine:$(alpine_version)
	docker buildx build \
		${DOCKER_BUILD_FLAGS} \
		--output=type=$(output_type) \
		--platform $(platform) \
		--build-arg alpine_version=$(alpine_version) \
		--build-arg vcs_ref=$(vcs_ref) \
		--build-arg build_date=$(build_date) \
		--build-arg version=$(VERSION) \
		--build-arg pupperware_analytics_stream=$(PUPPERWARE_ANALYTICS_STREAM) \
		--file r10k/$(dockerfile) \
		--tag $(NAMESPACE)/r10k:$(VERSION) $(latest_tag) $(dockerfile_context)

test: prep
	@bundle install --path $$BUNDLE_PATH --gemfile $$GEMFILE --with test
	@bundle update
	@PUPPET_TEST_DOCKER_IMAGE=$(NAMESPACE)/r10k:$(VERSION) \
		bundle exec --gemfile $$GEMFILE \
		rspec spec

# call build to produce multiple architectures
# uses cached output from amd64 build target if it exists
# registry output is equivalent to --push
push-image: platform=linux/amd64,linux/arm64
push-image: output_type=registry
push-image: prep build

push-readme:
	@docker pull sheogorath/readme-to-dockerhub
	@docker run --rm \
		-v $(PWD)/README.md:/data/README.md \
		-e DOCKERHUB_USERNAME="$(DOCKERHUB_USERNAME)" \
		-e DOCKERHUB_PASSWORD="$(DOCKERHUB_PASSWORD)" \
		-e DOCKERHUB_REPO_PREFIX=puppet \
		-e DOCKERHUB_REPO_NAME=r10k \
		sheogorath/readme-to-dockerhub

publish: push-image push-readme

.PHONY: lint build test prep publish push-image push-readme
