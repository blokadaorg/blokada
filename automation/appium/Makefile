.PHONY: test

test:
	@set -euo pipefail; \
	cd wdio && \
	npm install >/dev/null 2>&1 && \
	npm run test:unit
	node --test ../device/tests/*.test.mjs
