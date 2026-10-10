# Makefile for Asset Conversions
# Automatically converts MP4 videos into WebM (VP9) and OGV (Theora)
# when destination files do not already exist.

SHELL := /usr/bin/env bash

# Path to converter script
CONVERTER := scripts/convert_video.sh

# Find all MP4 files in videos directory
MP4_FILES := $(sort $(wildcard videos/*.mp4))
WEBM_FILES := $(MP4_FILES:.mp4=.webm)
OGV_FILES := $(MP4_FILES:.mp4=.ogv)

.PHONY: all webm ogv clean-generated help

all: webm ogv ## Convert all MP4 files to both WebM and OGV

webm: $(WEBM_FILES) ## Convert missing WebM videos

ogv: $(OGV_FILES) ## Convert missing OGV videos

# Pattern rule for WebM
videos/%.webm: videos/%.mp4 $(CONVERTER)
	@./$(CONVERTER) "$<" webm

# Pattern rule for OGV
videos/%.ogv: videos/%.mp4 $(CONVERTER)
	@./$(CONVERTER) "$<" ogv

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'
