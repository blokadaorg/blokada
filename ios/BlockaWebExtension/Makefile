.PHONY: test gen-rules e2e e2e-setup

all: test gen-rules

test:
	cd Resources && node popup.test.js

e2e: e2e-setup
	@echo "Running E2E tests with screenshots..."
	cd tests && npm test
	@echo "✅ E2E tests complete!"
	@echo "📸 Screenshots saved to: tests/ui/screenshots/"

e2e-setup:
	@echo "Setting up E2E tests..."
	@if [ ! -d "tests/node_modules" ]; then \
		echo "Installing dependencies..."; \
		cd tests && npm install; \
	fi
	@if [ ! -f "tests/node_modules/.bin/playwright" ] || [ ! -d "tests/node_modules/@playwright/test/lib/server/chromium" ]; then \
		echo "Installing Playwright browsers..."; \
		cd tests && npm run install-playwright; \
	fi

# Generate Safari Web Extension rules from domain lists
gen-rules: $(patsubst Resources/%.txt,Resources/%.json,$(wildcard Resources/*.txt))

Resources/%.json: Resources/%.txt
	@echo "Generating Safari Web Extension rules from $<..."
	cd ../../ && python3 scripts/convert-domains-to-rules.py ios/BlockaWebExtension/$< $(notdir $@) --output-dir ios/BlockaWebExtension/Resources

Resources/%.txt:
	@echo "Source file $@ not found. Please ensure domain list files are in Resources/"
	@exit 1
