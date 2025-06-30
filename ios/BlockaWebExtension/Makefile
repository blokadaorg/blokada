.PHONY: test gen-rules

all: test gen-rules

test:
	cd Resources && node popup.test.js

# Generate Safari Web Extension rules from domain lists
gen-rules: $(patsubst Resources/rules/%.txt,Resources/rules/%.json,$(wildcard Resources/rules/*.txt))

Resources/rules/%.json: Resources/rules/%.txt
	@echo "Generating Safari Web Extension rules from $<..."
	cd ../../ && python3 scripts/convert-domains-to-rules.py ios/BlockaWebExtension/$< $(notdir $@)

Resources/rules/%.txt:
	@echo "Source file $@ not found. Please ensure domain list files are in Resources/rules/"
	@exit 1
