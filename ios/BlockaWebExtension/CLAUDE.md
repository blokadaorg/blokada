# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **BlockaWeb Safari Extension** component of the Blokada iOS app - a Safari Web Extension that provides ad blocking capabilities directly in Safari on iOS. The extension runs independently from the main Blokada app and communicates with it via native messaging.

## Architecture

### Core Components
- **Safari Web Extension** - Standard Safari extension with popup UI and background scripts
- **Native Messaging** - Communication between extension and main iOS app via `SafariWebExtensionHandler.swift`
- **Content Blocking** - Uses Safari's declarative net request API with domain-based rules
- **Popup Interface** - HTML/CSS/JavaScript UI showing subscription status and blocking state

### Key Files
- `Resources/manifest.json` - Extension manifest defining permissions and structure
- `Resources/popup.html` - Main extension popup interface
- `Resources/popup.js` - Popup UI logic and state management
- `Resources/popup-logic.js` - Core business logic for status determination
- `Resources/background.js` - Background script for extension lifecycle
- `Resources/content.js` - Content script for YouTube ad blocking
- `SafariWebExtensionHandler.swift` - Swift handler for native messaging
- `Resources/oisd-small.json` - Generated Safari content blocking rules

### Status States
The extension popup displays different states based on subscription status:
- **Inactive** - App not active or extension disabled
- **Active** - Valid subscription with blocking active
- **Expired** - Subscription has expired
- **Freemium Trial** - Time-limited trial period active

## Development Commands

### Testing
```bash
# Run unit tests for popup logic
make test

# Run end-to-end UI tests with screenshots
make e2e

# Run E2E tests in watch mode (development)
make e2e-watch

# Clean test artifacts
make e2e-clean
```

### Rule Generation
```bash
# Generate Safari blocking rules from domain lists
make gen-rules

# This converts .txt domain lists to .json Safari rules using:
# python3 ../../scripts/convert-domains-to-rules.py
```

### E2E Testing Setup
```bash
# Setup test dependencies (runs automatically)
make e2e-setup
```

## Testing Architecture

### Unit Tests
- `Resources/popup.test.js` - Node.js unit tests for popup logic
- Tests status state determination and date validation functions
- Run with `make test` or `cd Resources && node popup.test.js`

### E2E Tests
- `tests/` directory contains Playwright-based UI tests
- Tests actual HTML popup rendering and user interactions
- Generates screenshots for visual verification
- Uses local HTTP server to serve extension files with ES6 module support
- Simulates different subscription states via mocked browser API responses

### Test Configuration
- `tests/playwright.config.js` - Main test configuration
- `tests/playwright.html.config.js` - HTML report configuration
- Uses WebKit engine to match Safari behavior
- iPhone 14 Pro viewport simulation for realistic popup sizing

## File Structure

```
Resources/
├── manifest.json          # Extension manifest
├── popup.html            # Main popup interface
├── popup.js             # Popup UI controller
├── popup-logic.js       # Business logic (testable)
├── popup.test.js        # Unit tests
├── background.js        # Background script
├── content.js           # Content scripts
├── ping.js             # Activity ping script
├── oisd-small.json     # Generated blocking rules
├── _locales/           # Internationalization
└── images/             # Extension icons and assets

tests/
├── ui/popup.spec.js    # E2E test scenarios
├── ui/screenshots/     # Generated screenshots
└── playwright.config.js # Test configuration
```

## Native Messaging Protocol

The extension communicates with the main iOS app through Safari's native messaging:

- **Status Request** - Extension requests current subscription status
- **Status Response** - App provides `JsonBlockaweb` with timestamp, active state, and trial info
- **Ping Message** - Extension sends activity ping to indicate it's running

The `SafariWebExtensionHandler.swift` handles these message exchanges and maintains the connection between the extension and main app.

## Development Workflow

1. **Make changes** to popup HTML/CSS/JS or Swift handler
2. **Run unit tests** with `make test` for logic verification
3. **Run E2E tests** with `make e2e` for UI verification
4. **Check screenshots** in `tests/ui/screenshots/` for visual confirmation
5. **Generate new rules** with `make gen-rules` if domain lists change

## Translations

The extension uses Safari Web Extension internationalization through the `_locales/` directory:

- **English** - `_locales/en/messages.json` (source of truth)
- **All Languages** - When adding or modifying message keys, update ALL language files
- **Unused Keys** - Remove unused translation keys to keep files clean
- **Key Format** - Use descriptive, hierarchical key names (e.g., `popup_status_active`)

### Translation Workflow
1. Modify `_locales/en/messages.json` with new/updated keys
2. Update corresponding keys in ALL other language files
3. Remove any unused keys from ALL language files
4. Test popup display with different language settings

## Important Notes

- Extension popup uses ES6 modules requiring HTTP server for local testing
- Safari Web Extension API restrictions apply (no eval, limited DOM access)
- Content blocking rules are generated from domain lists, not manually maintained
- Extension state persists independently from main app installation
- Native messaging requires proper entitlements and app group configuration