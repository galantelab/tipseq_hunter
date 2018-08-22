# import config.
# You can change the default config with `make cnf="config_special.env" build`
cnf ?= config.env
-include $(cnf)
#export $(shell sed 's/=.*//' $(cnf))

# import deploy config
# You can change the default deploy config with `make cnf="deploy_special.env" release`
ROOT_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
dpl ?= $(ROOT_DIR)/deploy.env
include $(dpl)
#export $(shell sed 's/=.*//' $(dpl))

# grep the version from the mix file
VERSION=$(shell $(ROOT_DIR)/version.sh)


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

build: ## Build the image
	$(info Build $(APP_NAME) image)
	cd $(ROOT_DIR) && docker build --build-arg tipseq_hunter_data=$(TIPSEQ_HUNTER_DATA) -t $(APP_NAME) .

.PHONY: build-nc

build-nc: ## Build the image without caching
	$(info Build $(APP_NAME) image no caching)
	cd $(ROOT_DIR) && docker build --no-cache --build-arg tipseq_hunter_data=$(TIPSEQ_HUNTER_DATA) -t $(APP_NAME) .

.PHONY: remove

remove: ## Remove the image
	$(info Remove $(APP_NAME) image)
	docker rmi $(APP_NAME)

# Run the container
.PHONY: run

run: run-pipeline run-pipeline-somatic ## Run TIPseqHunter pipeline completely

.PHONY: run-pipeline

FASTQS := $(addprefix $(INPUT_DIR)/,$(FASTQ_R1) $(subst $(KEY_R1),$(KEY_R2),$(FASTQ_R1)))
RUN_PIPELINE_ARGS := $(INPUT_DIR) $(OUTPUT_DIR) $(FASTQ_R1) $(KEY_R1) $(KEY_R2) $(READ_NUM)

run-pipeline: check-env $(OUTPUT_DIR)/pipeline.stamp

$(OUTPUT_DIR)/pipeline.stamp: ## Run TIPseqHunterPipelineJar.sh
	$(info TIPseqHunterPipelineJar.sh $(RUN_PIPELINE_ARGS))
	@docker run \
		--rm \
		-u $(shell id -u):$(shell id -g) \
		-e JFLAGS=$(JFLAGS) \
		-e THREADS=$(THREADS) \
		--name=$(CONTAINER_NAME) \
		-v /etc/passwd:/etc/passwd:ro \
		-v /etc/group:/etc/group:ro \
		-v $(strip $(INPUT_DIR)):$(strip $(INPUT_DIR)) \
		-v $(strip $(OUTPUT_DIR)):$(strip $(OUTPUT_DIR)) \
		-w $(OUTPUT_DIR) \
		$(APP_NAME) TIPseqHunterPipelineJar.sh $(RUN_PIPELINE_ARGS) >&2 && touch $@

$(OUTPUT_DIR)/pipeline.stamp: $(FASTQS)

$(FASTQS):
	$(error 'Not found $@: Verify the variables INPUT_DIR, FASTQ_R1, KEY_R1, KEY_R2')

$(OUTPUT_DIR)/pipeline.stamp: | $(OUTPUT_DIR)

$(OUTPUT_DIR):
	mkdir -p $@

.PHONY: run-pipeline-somatic

REPRED_SUFFIX := fastq.wsize100.regwsize1.minreads1.clip1.clipflk5.mindis150.rmskta.uniqgs.bed.csinfo.lm.l1hs.pred.txt.repred
MINTAG_SUFFIX := fastq.cleaned.fastq.pcsort.bam.w100.minreg1.mintag1.bed
FASTQ_PREFFIX := $(firstword $(subst _, ,$(FASTQ_R1)))_
REPRED_FILE := $(FASTQ_PREFFIX).$(REPRED_SUFFIX)
MINTAG_FILE := $(FASTQ_PREFFIX).$(MINTAG_SUFFIX)
MODEL_FILES := $(addprefix $(OUTPUT_DIR)/,model/$(REPRED_FILE) TRLocator/$(MINTAG_FILE))
RUN_PIPELINE_SOMATIC_ARGS := $(OUTPUT_DIR)/model $(OUTPUT_DIR)/TRLocator $(REPRED_FILE) $(MINTAG_FILE)

run-pipeline-somatic: check-env $(OUTPUT_DIR)/pipeline-somatic.stamp

$(OUTPUT_DIR)/pipeline-somatic.stamp: ## Run TIPseqHunterPipelineJarSomatic.sh
	$(info TIPseqHunterPipelineJarSomatic.sh $(RUN_PIPELINE_SOMATIC_ARGS))
	@docker run \
		--rm \
		-u $(shell id -u):$(shell id -g) \
		-e JFLAGS=$(JFLAGS) \
		-e THREADS=$(THREADS) \
		--name=$(CONTAINER_NAME) \
		-v /etc/passwd:/etc/passwd:ro \
		-v /etc/group:/etc/group:ro \
		-v $(strip $(INPUT_DIR)):$(strip $(INPUT_DIR)) \
		-v $(strip $(OUTPUT_DIR)):$(strip $(OUTPUT_DIR)) \
		-w $(OUTPUT_DIR) \
		$(APP_NAME) TIPseqHunterPipelineJarSomatic.sh $(RUN_PIPELINE_SOMATIC_ARGS) >&2 && touch $@

$(OUTPUT_DIR)/pipeline-somatic.stamp: $(OUTPUT_DIR)/pipeline.stamp $(MODEL_FILES)

$(MODEL_FILES):
	$(error 'Not found $@: An error may have occurred in the step run-pipeline')

.PHONY: up

up: build run ## Build and run TIPseqHunter pipeline completely

.PHONY: check-env

check-env: ## Check if INPUT_DIR/OUTPUT_DIR `args` are defined
ifndef INPUT_DIR
	$(error 'INPUT_DIR' is not defined)
endif
ifndef OUTPUT_DIR
	$(error 'OUTPUT_DIR' is not defined)
endif

.PHONY: stop

stop: ## Stop and remove a running container
	docker stop $(CONTAINER_NAME)

.PHONY: release

release: build publish ## Make a release by building and publishing the `{version}` ans `latest` tagged containers to dockerhub

# Docker publish
.PHONY: publish

publish: repo-login publish-latest publish-version repo-logout ## Publish the `{version}` ans `latest` tagged containers to dockerhub

.PHONY: publish-latest

publish-latest: tag-latest ## Publish the `latest` taged container to dockerhub
	$(info publish latest to $(DOCKER_REPO))
	docker push $(DOCKER_REPO)/$(APP_NAME):latest

.PHONY: publish-version

publish-version: tag-version ## Publish the `{version}` taged container to dockerhub
	$(info publish $(VERSION) to $(DOCKER_REPO))
	docker push $(DOCKER_REPO)/$(APP_NAME):$(VERSION)

# Docker tagging
.PHONY: tag

tag: tag-latest tag-version ## Generate container tags for the `{version}` ans `latest` tags

.PHONY: tag-latest

tag-latest: ## Generate container `{version}` tag
	$(info create tag latest)
	docker tag $(APP_NAME) $(DOCKER_REPO)/$(APP_NAME):latest

.PHONY: tag-version

tag-version: ## Generate container `latest` tag
	$(info create tag $(VERSION))
	docker tag $(APP_NAME) $(DOCKER_REPO)/$(APP_NAME):$(VERSION)

# HELPERS

# login to dockerhub
.PHONY: repo-login

repo-login: ## Login to dockerhub registry
	$(info login to dockerhub registry)
	docker login -u $(DOCKER_REPO)

repo-logout: ## Logout from dockerhub registry
	$(info logout from dockerhub registry)
	docker logout

.PHONY: version

version: ## Output the current version
	$(info $(VERSION)

