# import config.
# You can change the default config with `make cnf="config_special.env" build`
cnf ?= config.env
include $(cnf)
export $(shell sed 's/=.*//' $(cnf))

# import deploy config
# You can change the default deploy config with `make cnf="deploy_special.env" release`
dpl ?= deploy.env
include $(dpl)
export $(shell sed 's/=.*//' $(dpl))

# grep the version from the mix file
VERSION=$(shell ./version.sh)


# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help


# DOCKER TASKS

# Build the container
.PHONY: build

build: ## Build the container
	docker build -t $(APP_NAME) .

.PHONY: build-nc

build-nc: ## Build the container without caching
	docker build --no-cache -t $(APP_NAME) .

# Run the container
.PHONY: run

run: run-pipeline run-pipeline-somatic ## Run TIPseqHunter pipeline completely

.PHONY: run-pipeline

run-pipeline: check-args ## Run TIPseqHunterPipelineJar.sh
	docker run --rm -u $(shell id -u):$(shell id -g) --env-file=$(cnf) --name=$(APP_NAME) \
		-v $(hg19_refindex):$(hg19_refindex):ro \
		-v $(hg19_fai):$(hg19_fai):ro \
		-v $(l1hs_refindex):$(l1hs_refindex):ro \
		-v $(l1hs_fai):$(l1hs_fai):ro \
		-v $(adapterfa):$(adapterfa):ro \
		-v $(positive_anno_path):$(positive_anno_path):ro \
		-v $(positive_anno_file):$(positive_anno_file):ro \
		-v $(pathezm):$(pathezm):ro \
		-v $(ezm):$(ezm):ro \
		-v $(l1hsseq):$(l1hsseq):ro \
		-v $(word 1,$(args)):$(word 1,$(args)) \
		-v $(word 2,$(args)):$(word 2,$(args)) \
		-w $(word 2,$(args)) \
		$(APP_NAME) TIPseqHunterPipelineJar.sh $(args)


.PHONY: run-pipeline-somatic

run-pipeline-somatic: check-args ## Run TIPseqHunterPipelineJarSomatic.sh
	docker run --rm --env-file=$(cnf) --name=$(APP_NAME) $(APP_NAME)

.PHONY: up

up: build run ## Run TIPseqHunter pipeline completely (Alias to run)

.PHONY: check-args

check-args: ## Check if variable `args` is defined
ifndef args
	$(error 'args' is not defined)
endif

.PHONY: stop

stop: ## Stop and remove a running container
	docker stop $(APP_NAME); docker rm $(APP_NAME)

.PHONY: release

release: build publish ## Make a release by building and publishing the `{version}` ans `latest` tagged containers to dockerhub

# Docker publish
.PHONY: publish

publish: repo-login publish-latest publish-version ## Publish the `{version}` ans `latest` tagged containers to dockerhub

.PHONY: publish-latest

publish-latest: tag-latest ## Publish the `latest` taged container to dockerhub
	@echo 'publish latest to $(DOCKER_REPO)'
	docker push $(DOCKER_REPO)/$(APP_NAME):latest

.PHONY: publish-version

publish-version: tag-version ## Publish the `{version}` taged container to dockerhub
	@echo 'publish $(VERSION) to $(DOCKER_REPO)'
	docker push $(DOCKER_REPO)/$(APP_NAME):$(VERSION)

# Docker tagging
.PHONY: tag

tag: tag-latest tag-version ## Generate container tags for the `{version}` ans `latest` tags

.PHONY: tag-latest

tag-latest: ## Generate container `{version}` tag
	@echo 'create tag latest'
	docker tag $(APP_NAME) $(DOCKER_REPO)/$(APP_NAME):latest

.PHONY: tag-version

tag-version: ## Generate container `latest` tag
	@echo 'create tag $(VERSION)'
	docker tag $(APP_NAME) $(DOCKER_REPO)/$(APP_NAME):$(VERSION)

# HELPERS

# login to dockerhub
.PHONY: repo-login

repo-login: ## Login to dockerhub registry
	@echo 'login to dockerhub registry'
	docker login -u $(USER_NAME)

.PHONY: version

version: ## Output the current version
	@echo $(VERSION)
	
