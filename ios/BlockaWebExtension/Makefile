.PHONY: test gen-rules

all: test gen-rules

test:
	cd Resources && node popup.test.js

# Generate Safari Web Extension rules from domain lists
gen-rules: $(patsubst Resources/%.txt,Resources/%.json,$(wildcard Resources/*.txt))

Resources/%.json: Resources/%.txt
	@echo "Generating Safari Web Extension rules from $<..."
	cd ../../ && python3 scripts/convert-domains-to-rules.py ios/BlockaWebExtension/$< $(notdir $@) --output-dir ios/BlockaWebExtension/Resources

Resources/%.txt:
	@echo "Source file $@ not found. Please ensure domain list files are in Resources/"
	@exit 1
