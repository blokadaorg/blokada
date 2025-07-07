# Account Types and Feature Access

This document provides a reference for all account types, states, and feature access in the Blokada app ecosystem.

## Account Types

### 1. **libre** (Expired subscription or never subscribed)
- **Description**: Default free account with no active subscription
- **Active Status**: Inactive (not considered a paid subscription)
- **Available Apps**: Both Blokada 6 and Blokada Family
- **Features**: No functionality, unless freemium special case (see below). Freemium users have access to the Safari browser extension for basic filtering functionality.

### 2. **plus** 
- **Description**: Premium VPN subscription with all features enabled
- **Active Status**: Active subscription
- **Available Apps**: Blokada 6 only (rejected by Family app)
- **Features**: Full VPN access + all cloud blocking features + browser extension where applicable

### 3. **cloud**
- **Description**: Cloud-based ad blocking subscription (DNS based, no VPN)
- **Active Status**: Active subscription
- **Available Apps**: Blokada 6 only (rejected by Family app)
- **Features**: Full DNS blocking and filtering features + browser extension where applicable

### 4. **family**
- **Description**: Family protection subscription for parental controls
- **Active Status**: Active subscription
- **Available Apps**: Blokada Family only (rejected by Blokada 6)
- **Features**: Full DNS blocking with family/parental control specialized filters.

## Account States

### Active Account States
- **Active**: Account has valid subscription and `activeUntil` is in the future
- **Expired**: Account subscription has expired, reverts to libre functionality

### Special States
- **Freemium Essentials**: expired account with `freemium` attribute, access to Safari extension only
- **Freemium + YouTube Trial**: expired account with `freemium` attribute and `freemium_youtube_until` timestamp in the future, extended browser extension features (Safari for iOS)

## App Compatibility

### Blokada 6
- **Compatible**: libre, plus, cloud account types
- **Rejected**: family account type
- **Features**: VPN functionality, advanced filtering, individual user focus

### Blokada Family
- **Compatible**: family account type only
- **Rejected**: plus, cloud account types
- **Features**: Parental controls, device management, family profiles

## Key Restrictions

### Account Type Validation
- Family accounts can only be used in the Family app
- Plus and Cloud accounts can only be used in the 6 (Six) app

### Feature Gates
- **VPN features**: Exclusively available to Plus accounts
- **DNS blocking**: Requires Cloud, Family, or Plus account
- Browser extension: Available to all account types. Libre accounts require the freemium attribute for Safari extension access (basic filtering functionality).
- **Family controls**: Exclusively available to Family accounts in Family app

### Freemium Limitations
- **Browser Extension Required**: Freemium users must have active browser (Safari) extension for any blocking functionality
- **Time-based YouTube Access**: YouTube blocking (and other extras other than basic filtering) will be time-limited with `freemium_youtube_until` attribute
- **No DNS Configuration**: Freemium users cannot modify DNS settings or filter lists, they do not configure system-wide DNS or VPN profiles.
