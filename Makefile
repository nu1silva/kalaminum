SHELL := /bin/bash
APP := build/Kalaminum.app

.PHONY: app run install test clean

app:            ## Build build/Kalaminum.app
	@scripts/build-app.sh release

run: app        ## Build and launch (quits any running copy first)
	@pkill -x Kalaminum || true
	@open $(APP)

install: app    ## Copy into /Applications and launch
	@pkill -x Kalaminum || true
	@rm -rf /Applications/Kalaminum.app
	@cp -R $(APP) /Applications/
	@open /Applications/Kalaminum.app
	@echo "Installed /Applications/Kalaminum.app"

test:           ## Run unit tests
	@source scripts/env.sh && swift test $$TEST_FLAGS 2>&1 | grep -v "ld: warning: search path"; exit $${PIPESTATUS[0]}

clean:
	rm -rf .build build
