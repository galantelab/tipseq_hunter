# Default shell
SHELL := bash

# Release version
VERSION := 1.0

# Deploy variables
APP_NAME := tipseqhunter
CONTAINER_NAME := $(APP_NAME)
TIPSEQ_HUNTER_DATA := tipseq_hunter_data.tar.gz

# Import config
# You can change the default config with `make CONFIG="config_special.env"`
CONFIG ?= config.env
-include $(CONFIG)

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

# DOCKER TASKS

# Build the container
.PHONY: build

build: ## Build the image
	$(info Build $(APP_NAME) image)
	docker build --build-arg tipseq_hunter_data=$(TIPSEQ_HUNTER_DATA) -t $(APP_NAME) .

.PHONY: build-nc

build-nc: ## Build the image without caching
	$(info Build $(APP_NAME) image no caching)
	docker build --no-cache --build-arg tipseq_hunter_data=$(TIPSEQ_HUNTER_DATA) -t $(APP_NAME) .

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

run-pipeline: check-env $(OUTPUT_DIR)/pipeline.stamp ## Run TIPseqHunterPipelineJar.sh

$(OUTPUT_DIR)/pipeline.stamp:
	$(info TIPseqHunterPipelineJar.sh $(RUN_PIPELINE_ARGS))
	@docker run \
		--rm \
		-u $(shell id -u):$(shell id -g) \
		--env-file=$(CONFIG) \
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

REPRED_SUFFIX := wsize100.regwsize1.minreads1.clip1.clipflk5.mindis150.rmskta.uniqgs.bed.csinfo.lm.l1hs.pred.txt.repred
MINTAG_SUFFIX := cleaned.fastq.pcsort.bam.w100.minreg1.mintag1.bed
FASTQ_PREFFIX := $(subst $(KEY_R1),,$(FASTQ_R1))
REPRED_FILE := $(FASTQ_PREFFIX).$(REPRED_SUFFIX)
MINTAG_FILE := $(FASTQ_PREFFIX).$(MINTAG_SUFFIX)
MODEL_FILES := $(addprefix $(OUTPUT_DIR)/,model/$(REPRED_FILE) TRLocator/$(MINTAG_FILE))
RUN_PIPELINE_SOMATIC_ARGS := $(OUTPUT_DIR)/model $(OUTPUT_DIR)/TRLocator $(REPRED_FILE) $(MINTAG_FILE)

run-pipeline-somatic: check-env $(OUTPUT_DIR)/pipeline-somatic.stamp ## Run TIPseqHunterPipelineJarSomatic.sh

$(OUTPUT_DIR)/pipeline-somatic.stamp:
	$(info TIPseqHunterPipelineJarSomatic.sh $(RUN_PIPELINE_SOMATIC_ARGS))
	@docker run \
		--rm \
		-u $(shell id -u):$(shell id -g) \
		--env-file=$(CONFIG) \
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

# Check if INPUT_DIR/OUTPUT_DIR `args` are defined
check-env:
ifndef INPUT_DIR
	$(error 'INPUT_DIR' is not defined)
endif
ifndef OUTPUT_DIR
	$(error 'OUTPUT_DIR' is not defined)
endif

.PHONY: stop

stop: ## Stop and remove a running container
	docker stop $(CONTAINER_NAME)

.PHONY: version

version: ## Output the current version
	@echo $(VERSION)
