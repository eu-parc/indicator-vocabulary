DROPBOX_FOLDER ?= dropbox
UNPUBLISHED_FOLDER ?= unpublished
PUBLISHED_FOLDER ?= published
ARCHIVE_FOLDER ?= archive
REDIRECT_FOLDER ?= redirect
SCHEMA ?= schema/peh.yaml
PEH_SCHEMA_REPO ?= eu-parc/parco-hbm
PEH_SCHEMA_TAG ?= v0.7.2
PEH_SCHEMA_SOURCE_PATH ?= linkml/schema/peh.yaml
PEH_SCHEMA_DEST ?= schema/peh.yaml
PEH_SCHEMA_URL ?= https://raw.githubusercontent.com/$(PEH_SCHEMA_REPO)/$(PEH_SCHEMA_TAG)/$(PEH_SCHEMA_SOURCE_PATH)
OUT_FOLDER ?= build
ASSERTIONS_FOLDER ?= $(OUT_FOLDER)/assertions
PR_ASSERTIONS_FOLDER ?= $(OUT_FOLDER)/pr-assertions
TARGET_CLASS ?= indicator_subclasses
BASE_NAMESPACE ?= https://w3id.org/peh/terms/
TERM_PARENT_CLASS ?= https://w3id.org/peh/terms/Indicator
MINT_NAMESPACE ?= https://w3id.org/peh/indicators/
ENTITY_LIST_PREDICATE ?= https://w3id.org/peh/terms/hasIndicatorSubclass
COMBINED_DATA ?= $(OUT_FOLDER)/combined.yaml
ID_MAP_FILE ?= $(REDIRECT_FOLDER)/id-map.tsv
PUBLISH_KEY_ARGS ?= --use-testsuite-keys
MIGRATE_SUGGESTER ?= https://orcid.org/0000-0001-8327-0142
NANOPUB_TYPE ?= https://w3id.org/iadopt/ont/Variable
NANOPUB_TEMPLATE ?= https://w3id.org/np/RAYXmR56YAlwKU-8h9cITx_0Y1_9t-lqXyVcJAgeEHDjw
NANOPUB_PART_OF ?= https://w3id.org/spaces/chemical-exposome-indicator/r/vocabulary
# Vocabulary query (approved classes) behind the Nanodash vocabulary view.
VOCABULARY_QUERY_URL ?= https://query.knowledgepixels.com/api/RA5rQSjX-6t_ccwhgZhxCpWryxuRjMFeCMXelxJYfxtdw/get-approved-classes-of-an-ontology-from-space-members?ontology=https%3A%2F%2Fw3id.org%2Fspaces%2Fchemical-exposome-indicator%2Fr%2Fvocabulary
DRY ?=

BOT_NAME ?= Indicator bot
BOT_ID ?= https://w3id.org/np/RAAgRoFvRqnuCohjPVLvT80VpdM59Vgodhw7D6lHZ1pFw/indicator-bot
# Owner named in the bot's introduction: the person who sets up the bot. No
# default; pass both, e.g. make bot-identity BOT_OWNER_ORCID=https://orcid.org/...
# BOT_OWNER_NAME='...'.
BOT_OWNER_ORCID ?=
BOT_OWNER_NAME ?=
BOT_IDENTITY_DIR ?= bot-identity
CI_REPO ?= eu-parc/indicator-vocabulary
BOT_PUBLISH_ARGS ?=
_BOOTSTRAP_ARGS = --bot-name "$(BOT_NAME)" --bot-id "$(BOT_ID)" \
	--owner-orcid "$(BOT_OWNER_ORCID)" --owner-name "$(BOT_OWNER_NAME)" \
	--output-dir "$(BOT_IDENTITY_DIR)"

DATA_FILES = $(sort $(wildcard $(DROPBOX_FOLDER)/*.yaml))

.PHONY: help print-data prepare fetch-peh-schema aggregate mint graph2assertions \
	validate-pipeline validate-nanopubs validate-pr process-dropbox archive-dropbox \
	publish-defining migrate pipeline assertions \
	check-bot-owner bot-identity publish-bot-introduction bot-ci-secrets \
	check-consistency test-flow clean

help:
	@echo "Targets:"
	@echo "  make fetch-peh-schema          # download schema/peh.yaml from a tagged parco-hbm release"
	@echo "  make pipeline                  # process dropbox -> unpublished + archive"
	@echo "  make validate-pipeline         # process dropbox -> build + unpublished, without archive/publish"
	@echo "  make validate-pr               # PR gate: build proposed terms + validate as defining nanopubs"
	@echo "  make assertions                # extract published/*.trig -> $(ASSERTIONS_FOLDER) for the site"
	@echo "  make publish-defining          # mint unpublished assertions -> published/*.trig + id-map"
	@echo "  make publish-defining DRY=--dry-run"
	@echo "  make migrate                   # one-time id migration of existing terms"
	@echo "  make bot-identity              # one-time: generate bot keypair + introduction"
	@echo "  make publish-bot-introduction  # one-time: publish the reviewed introduction"
	@echo "  make bot-ci-secrets            # one-time: push signing key + identity URIs to $(CI_REPO)"
	@echo "  make check-consistency         # check the vocabulary query and $(PUBLISHED_FOLDER) for duplicates, broken links, drift"
	@echo "  make test-flow                 # local end-to-end dry-run test"

print-data:
	@echo "$(DATA_FILES)"

prepare:
	mkdir -p $(OUT_FOLDER) $(UNPUBLISHED_FOLDER) $(PUBLISHED_FOLDER) $(ARCHIVE_FOLDER) $(REDIRECT_FOLDER)

fetch-peh-schema:
	@if [ -z "$(PEH_SCHEMA_TAG)" ]; then \
		echo "PEH_SCHEMA_TAG must be set to a released tag, for example v0.6.1."; \
		exit 1; \
	fi
	mkdir -p $(dir $(PEH_SCHEMA_DEST))
	curl -fsSL "$(PEH_SCHEMA_URL)" -o "$(PEH_SCHEMA_DEST)"
	@echo "Downloaded $(PEH_SCHEMA_DEST) from $(PEH_SCHEMA_REPO) tag $(PEH_SCHEMA_TAG)"

aggregate: prepare
	@set -e; \
	if [ -z "$(DATA_FILES)" ]; then \
		echo "No YAML files found in $(DROPBOX_FOLDER). Skipping aggregation."; \
	else \
		uv run pubmate-yamlconcat \
			--target $(TARGET_CLASS) \
			--inherit suggester \
			$(COMBINED_DATA) \
			$(DATA_FILES); \
	fi

mint: aggregate
	@set -e; \
	if [ ! -f "$(COMBINED_DATA)" ]; then \
		echo "No combined YAML available. Skipping mint."; \
	else \
		uv run pubmate-mint \
			--data $(COMBINED_DATA) \
			--target $(TARGET_CLASS) \
			--namespace "$(MINT_NAMESPACE)" \
			--verbose \
			--preflabel name; \
	fi

graph2assertions: mint
	@set -e; \
	if [ ! -f "$(COMBINED_DATA)" ]; then \
		echo "No combined YAML available. Skipping I-ADOPT projection."; \
	else \
		uv run python _scripts/indicator2iadopt.py \
			--data $(COMBINED_DATA) \
			--out $(UNPUBLISHED_FOLDER); \
	fi

validate-pipeline: graph2assertions

validate-nanopubs:
	@set -e; \
	uv run pubmate-validate-defining \
		--assertion-folder $(PR_ASSERTIONS_FOLDER) \
		--namespace "$(MINT_NAMESPACE)"

validate-pr:
	$(MAKE) validate-pipeline UNPUBLISHED_FOLDER=$(PR_ASSERTIONS_FOLDER)
	$(MAKE) validate-nanopubs

archive-dropbox: graph2assertions
	@set -e; \
	if [ -n "$(DRY)" ]; then \
		echo "DRY mode enabled. Keeping YAML files in $(DROPBOX_FOLDER)."; \
		exit 0; \
	fi; \
	files="$(DATA_FILES)"; \
	if [ -z "$$files" ]; then \
		echo "No YAML files found in $(DROPBOX_FOLDER). Nothing to archive."; \
		exit 0; \
	fi; \
	if [ ! -f "$(COMBINED_DATA)" ]; then \
		echo "No minted combined YAML available. Nothing to archive."; \
		exit 1; \
	fi; \
	while :; do \
		label=$$(python3 -c 'import os, time; alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"; value = (int(time.time() * 1000) << 80) | int.from_bytes(os.urandom(10), "big"); print("".join(alphabet[(value >> shift) & 31] for shift in range(125, -1, -5)))'); \
		dest="$(ARCHIVE_FOLDER)/combined_$${label}.yaml"; \
		[ ! -e "$$dest" ] && break; \
	done; \
	cp "$(COMBINED_DATA)" "$$dest"; \
	echo "Archived minted combined YAML -> $$dest"; \
	for src in $$files; do \
		rm "$$src"; \
		echo "Removed processed dropbox file $$src"; \
	done

process-dropbox: archive-dropbox

pipeline: process-dropbox

publish-defining: prepare
	@set -e; \
	uv run pubmate-mint-publish \
		--assertion-folder $(UNPUBLISHED_FOLDER) \
		--namespace "$(MINT_NAMESPACE)" \
		--output-dir $(PUBLISHED_FOLDER) \
		--id-map-file $(ID_MAP_FILE) \
		--part-of "$(NANOPUB_PART_OF)" \
		--nanopub-type "$(NANOPUB_TYPE)" \
		$(if $(NANOPUB_TEMPLATE),--template "$(NANOPUB_TEMPLATE)",) \
		$(PUBLISH_KEY_ARGS) \
		$(DRY)

migrate: prepare
	@set -e; \
	uv run pubmate-migrate \
		--assertion-folder $(UNPUBLISHED_FOLDER) \
		--namespace "$(MINT_NAMESPACE)" \
		--output-dir $(PUBLISHED_FOLDER) \
		--id-map-file $(ID_MAP_FILE) \
		--default-suggester "$(MIGRATE_SUGGESTER)" \
		--nanopub-type "$(NANOPUB_TYPE)" \
		$(if $(NANOPUB_TEMPLATE),--template "$(NANOPUB_TEMPLATE)",) \
		--part-of "$(NANOPUB_PART_OF)" \
		$(PUBLISH_KEY_ARGS) \
		$(DRY)

check-bot-owner:
	@if [ -z "$(BOT_OWNER_ORCID)" ] || [ -z "$(BOT_OWNER_NAME)" ]; then \
		echo "Set BOT_OWNER_ORCID and BOT_OWNER_NAME to the ORCID and name of the person setting up the bot."; \
		exit 1; \
	fi

bot-identity: check-bot-owner
	uv run pubmate-bootstrap-identity $(_BOOTSTRAP_ARGS) --generate-keys

publish-bot-introduction: check-bot-owner
	uv run pubmate-bootstrap-identity $(_BOOTSTRAP_ARGS) \
		--private-key $(BOT_IDENTITY_DIR)/id_rsa --public-key $(BOT_IDENTITY_DIR)/id_rsa.pub \
		--publish $(BOT_PUBLISH_ARGS)

bot-ci-secrets:
	@set -e; \
	intro=$$(grep -oP '@prefix this: <\K[^>]+' $(BOT_IDENTITY_DIR)/introduction.trig); \
	bot="$$intro/$(BOT_ID)"; \
	echo "Introduction : $$intro"; echo "Bot agent URI: $$bot"; \
	gh secret   set NANOPUB_BOT_PRIVATE_KEY --repo $(CI_REPO) < $(BOT_IDENTITY_DIR)/id_rsa; \
	gh variable set NANOPUB_BOT_PUBLIC_KEY  --repo $(CI_REPO) < $(BOT_IDENTITY_DIR)/id_rsa.pub; \
	gh variable set NANOPUB_BOT_URI         --repo $(CI_REPO) --body "$$bot"; \
	gh variable set NANOPUB_BOT_INTRO_URI   --repo $(CI_REPO) --body "$$intro"; \
	echo "Pushed signing key + identity URIs to $(CI_REPO)."

assertions: prepare
	@set -e; \
	if ! find $(PUBLISHED_FOLDER) -maxdepth 1 -name "*.trig" | grep -q .; then \
		echo "No published nanopubs found in $(PUBLISHED_FOLDER). Skipping assertion extraction."; \
	else \
		uv run pubmate-extract-assertions \
			--nanopub-folder $(PUBLISHED_FOLDER) \
			--out $(ASSERTIONS_FOLDER); \
	fi

check-consistency:
	uv run python scripts/check_consistency.py \
		--query-url "$(VOCABULARY_QUERY_URL)" \
		--namespace "$(MINT_NAMESPACE)" \
		--published-dir $(PUBLISHED_FOLDER)

test-flow:
	$(MAKE) validate-pipeline

clean:
	rm -f $(OUT_FOLDER)/* $(UNPUBLISHED_FOLDER)/*.ttl
