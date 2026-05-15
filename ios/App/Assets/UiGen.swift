// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  /// About
  internal static let accountActionAbout = L10n.tr("Ui", "account action about", fallback: "About")
  /// Generate new account
  internal static let accountActionCreate = L10n.tr("Ui", "account action create", fallback: "Generate new account")
  /// Devices
  internal static let accountActionDevices = L10n.tr("Ui", "account action devices", fallback: "Devices")
  /// Encryption & DNS
  internal static let accountActionEncryption = L10n.tr("Ui", "account action encryption", fallback: "Encryption & DNS")
  /// How do I restore my old account?
  internal static let accountActionHowToRestore = L10n.tr("Ui", "account action how to restore", fallback: "How do I restore my old account?")
  /// Inbox
  internal static let accountActionInbox = L10n.tr("Ui", "account action inbox", fallback: "Inbox")
  /// Restore purchase
  internal static let accountActionLogout = L10n.tr("Ui", "account action logout", fallback: "Restore purchase")
  /// Restore Account ID
  internal static let accountActionLogoutNew = L10n.tr("Ui", "account action logout new", fallback: "Restore Account ID")
  /// Log out
  internal static let accountActionLogoutOnly = L10n.tr("Ui", "account action logout only", fallback: "Log out")
  /// Manage subscription
  internal static let accountActionManageSubscription = L10n.tr("Ui", "account action manage subscription", fallback: "Manage subscription")
  /// My account
  internal static let accountActionMyAccount = L10n.tr("Ui", "account action my account", fallback: "My account")
  /// New device
  internal static let accountActionNewDevice = L10n.tr("Ui", "account action new device", fallback: "New device")
  /// Restoring account: %@
  internal static func accountActionRestoring(_ p1: Any) -> String {
    return L10n.tr("Ui", "account action restoring", String(describing: p1), fallback: "Restoring account: %@")
  }
  /// Tap to show
  internal static let accountActionTapToShow = L10n.tr("Ui", "account action tap to show", fallback: "Tap to show")
  /// Why should I upgrade?
  internal static let accountActionWhyUpgrade = L10n.tr("Ui", "account action why upgrade", fallback: "Why should I upgrade?")
  /// I wrote it down
  internal static let accountCreateConfirm = L10n.tr("Ui", "account create confirm", fallback: "I wrote it down")
  /// This is your account ID. Write it down and keep it private. It’s the only way to access your subscription.
  internal static let accountCreateDescription = L10n.tr("Ui", "account create description", fallback: "This is your account ID. Write it down and keep it private. It’s the only way to access your subscription.")
  /// Not available
  internal static let accountDevicesNotAvailable = L10n.tr("Ui", "account devices not available", fallback: "Not available")
  /// %@ out of %@
  internal static func accountDevicesOutOf(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "account devices out of", String(describing: p1), String(describing: p2), fallback: "%@ out of %@")
  }
  /// Devices remaining: %@
  internal static func accountDevicesRemaining(_ p1: Any) -> String {
    return L10n.tr("Ui", "account devices remaining", String(describing: p1), fallback: "Devices remaining: %@")
  }
  /// Restore purchase
  internal static let accountHeaderLogout = L10n.tr("Ui", "account header logout", fallback: "Restore purchase")
  /// (unchanged)
  internal static let accountIdStatusUnchanged = L10n.tr("Ui", "account id status unchanged", fallback: "(unchanged)")
  /// Active until
  internal static let accountLabelActiveUntil = L10n.tr("Ui", "account label active until", fallback: "Active until")
  /// Enter your account ID to continue
  internal static let accountLabelEnterToContinue = L10n.tr("Ui", "account label enter to continue", fallback: "Enter your account ID to continue")
  /// Account ID
  internal static let accountLabelId = L10n.tr("Ui", "account label id", fallback: "Account ID")
  /// Subscription plan
  internal static let accountLabelType = L10n.tr("Ui", "account label type", fallback: "Subscription plan")
  /// Choose a DNS
  internal static let accountLeaseActionDns = L10n.tr("Ui", "account lease action dns", fallback: "Choose a DNS")
  /// Download Config
  internal static let accountLeaseActionDownload = L10n.tr("Ui", "account lease action download", fallback: "Download Config")
  /// Generate Config
  internal static let accountLeaseActionGenerate = L10n.tr("Ui", "account lease action generate", fallback: "Generate Config")
  /// Device added! Download the configuration to use it on any device supported by WireGuard.
  internal static let accountLeaseGenerated = L10n.tr("Ui", "account lease generated", fallback: "Device added! Download the configuration to use it on any device supported by WireGuard.")
  /// Devices
  internal static let accountLeaseLabelDevices = L10n.tr("Ui", "account lease label devices", fallback: "Devices")
  /// These devices are connected to your account.
  internal static let accountLeaseLabelDevicesList = L10n.tr("Ui", "account lease label devices list", fallback: "These devices are connected to your account.")
  /// DNS
  internal static let accountLeaseLabelDns = L10n.tr("Ui", "account lease label dns", fallback: "DNS")
  /// Selecting a location here will generate a config file that you can use in any VPN app that supports WireGuard. This is useful for platforms where we don't have our apps yet. Otherwise, we recommend using our native apps instead.
  internal static let accountLeaseLabelGenerate = L10n.tr("Ui", "account lease label generate", fallback: "Selecting a location here will generate a config file that you can use in any VPN app that supports WireGuard. This is useful for platforms where we don't have our apps yet. Otherwise, we recommend using our native apps instead.")
  /// Location
  internal static let accountLeaseLabelLocation = L10n.tr("Ui", "account lease label location", fallback: "Location")
  /// Name of device
  internal static let accountLeaseLabelName = L10n.tr("Ui", "account lease label name", fallback: "Name of device")
  /// Public Key
  internal static let accountLeaseLabelPublicKey = L10n.tr("Ui", "account lease label public key", fallback: "Public Key")
  ///  (this device)
  internal static let accountLeaseLabelThisDevice = L10n.tr("Ui", "account lease label this device", fallback: " (this device)")
  /// Blokada uses WireGuard. Configurations can be downloaded when creating new devices.
  internal static let accountLeaseWireguardDesc = L10n.tr("Ui", "account lease wireguard desc", fallback: "Blokada uses WireGuard. Configurations can be downloaded when creating new devices.")
  /// Please enter another account ID, or go back to keep using your existing account (this app cannot be used without one).
  internal static let accountLogoutDescription = L10n.tr("Ui", "account logout description", fallback: "Please enter another account ID, or go back to keep using your existing account (this app cannot be used without one).")
  /// No active plan
  internal static let accountPlanNone = L10n.tr("Ui", "account plan none", fallback: "No active plan")
  /// Don't worry, if you lost or forgot your account ID, we can recover it. Please contact our support, and provide us information that will allow us to identify your purchase (eg. last 4 digits of your credit card, or PayPal email).
  internal static let accountRestoreDescription = L10n.tr("Ui", "account restore description", fallback: "Don't worry, if you lost or forgot your account ID, we can recover it. Please contact our support, and provide us information that will allow us to identify your purchase (eg. last 4 digits of your credit card, or PayPal email).")
  /// General
  internal static let accountSectionHeaderGeneral = L10n.tr("Ui", "account section header general", fallback: "General")
  /// My Subscription
  internal static let accountSectionHeaderMySubscription = L10n.tr("Ui", "account section header my subscription", fallback: "My Subscription")
  /// Other
  internal static let accountSectionHeaderOther = L10n.tr("Ui", "account section header other", fallback: "Other")
  /// Primary
  internal static let accountSectionHeaderPrimary = L10n.tr("Ui", "account section header primary", fallback: "Primary")
  /// Settings
  internal static let accountSectionHeaderSettings = L10n.tr("Ui", "account section header settings", fallback: "Settings")
  /// Subscription
  internal static let accountSectionHeaderSubscription = L10n.tr("Ui", "account section header subscription", fallback: "Subscription")
  /// Your BLOKADA %@ account is active until %@.
  internal static func accountStatusText(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "account status text", String(describing: p1), String(describing: p2), fallback: "Your BLOKADA %@ account is active until %@.")
  }
  /// Your BLOKADA subscription is inactive.
  internal static let accountStatusTextInactive = L10n.tr("Ui", "account status text inactive", fallback: "Your BLOKADA subscription is inactive.")
  /// Days remaining: %@
  internal static func accountSubscriptionDaysRemaining(_ p1: Any) -> String {
    return L10n.tr("Ui", "account subscription days remaining", String(describing: p1), fallback: "Days remaining: %@")
  }
  /// Payment method
  internal static let accountSubscriptionHeaderPaymentMethod = L10n.tr("Ui", "account subscription header payment method", fallback: "Payment method")
  /// Renew automatically
  internal static let accountSubscriptionHeaderRenew = L10n.tr("Ui", "account subscription header renew", fallback: "Renew automatically")
  /// Your payment method does not allow to control the auto renewal setting here.
  internal static let accountSubscriptionRenewUnsupported = L10n.tr("Ui", "account subscription renew unsupported", fallback: "Your payment method does not allow to control the auto renewal setting here.")
  /// How can we help you?
  internal static let accountSupportActionHowHelp = L10n.tr("Ui", "account support action how help", fallback: "How can we help you?")
  /// Open Knowledge Base
  internal static let accountSupportActionKb = L10n.tr("Ui", "account support action kb", fallback: "Open Knowledge Base")
  /// Unlock to show your account ID
  internal static let accountUnlockToShow = L10n.tr("Ui", "account unlock to show", fallback: "Unlock to show your account ID")
  /// This feature is a part of Blokada Plus. To upgrade, please contact our Customer Support.
  internal static let accountUpgradeCloudDescription = L10n.tr("Ui", "account upgrade cloud description", fallback: "This feature is a part of Blokada Plus. To upgrade, please contact our Customer Support.")
  /// The following is necessary for Blokada to work as expected:
  internal static let activatedDesc = L10n.tr("Ui", "activated desc", fallback: "The following is necessary for Blokada to work as expected:")
  /// Your device is all set up and good to go:
  internal static let activatedDescAllOk = L10n.tr("Ui", "activated desc all ok", fallback: "Your device is all set up and good to go:")
  /// Almost there!
  internal static let activatedHeader = L10n.tr("Ui", "activated header", fallback: "Almost there!")
  /// Account is active (%@)
  internal static func activatedLabelAccount(_ p1: Any) -> String {
    return L10n.tr("Ui", "activated label account", String(describing: p1), fallback: "Account is active (%@)")
  }
  /// Activate DNS profile
  internal static let activatedLabelDnsNo = L10n.tr("Ui", "activated label dns no", fallback: "Activate DNS profile")
  /// DNS profile is activated
  internal static let activatedLabelDnsYes = L10n.tr("Ui", "activated label dns yes", fallback: "DNS profile is activated")
  /// Allow notifications
  internal static let activatedLabelNotifNo = L10n.tr("Ui", "activated label notif no", fallback: "Allow notifications")
  /// Notifications are allowed
  internal static let activatedLabelNotifYes = L10n.tr("Ui", "activated label notif yes", fallback: "Notifications are allowed")
  /// Allow VPN (Plus only)
  internal static let activatedLabelVpnCloud = L10n.tr("Ui", "activated label vpn cloud", fallback: "Allow VPN (Plus only)")
  /// Allow VPN
  internal static let activatedLabelVpnNo = L10n.tr("Ui", "activated label vpn no", fallback: "Allow VPN")
  /// VPN is allowed
  internal static let activatedLabelVpnYes = L10n.tr("Ui", "activated label vpn yes", fallback: "VPN is allowed")
  /// Add to Blocked
  internal static let activityActionAddToBlacklist = L10n.tr("Ui", "activity action add to blacklist", fallback: "Add to Blocked")
  /// Add to Allowed
  internal static let activityActionAddToWhitelist = L10n.tr("Ui", "activity action add to whitelist", fallback: "Add to Allowed")
  /// Added to Blocked
  internal static let activityActionAddedToBlacklist = L10n.tr("Ui", "activity action added to blacklist", fallback: "Added to Blocked")
  /// Added to Allowed
  internal static let activityActionAddedToWhitelist = L10n.tr("Ui", "activity action added to whitelist", fallback: "Added to Allowed")
  /// Copy name to Clipboard
  internal static let activityActionCopyToClipboard = L10n.tr("Ui", "activity action copy to clipboard", fallback: "Copy name to Clipboard")
  /// Remove from Blocked
  internal static let activityActionRemoveFromBlacklist = L10n.tr("Ui", "activity action remove from blacklist", fallback: "Remove from Blocked")
  /// Remove from Allowed
  internal static let activityActionRemoveFromWhitelist = L10n.tr("Ui", "activity action remove from whitelist", fallback: "Remove from Allowed")
  /// Actions
  internal static let activityActionsHeader = L10n.tr("Ui", "activity actions header", fallback: "Actions")
  /// Recent
  internal static let activityCategoryRecent = L10n.tr("Ui", "activity category recent", fallback: "Recent")
  /// Top
  internal static let activityCategoryTop = L10n.tr("Ui", "activity category top", fallback: "Top")
  /// Top Allowed
  internal static let activityCategoryTopAllowed = L10n.tr("Ui", "activity category top allowed", fallback: "Top Allowed")
  /// Top Blocked
  internal static let activityCategoryTopBlocked = L10n.tr("Ui", "activity category top blocked", fallback: "Top Blocked")
  /// All devices
  internal static let activityDeviceFilterShowAll = L10n.tr("Ui", "activity device filter show all", fallback: "All devices")
  /// Full name
  internal static let activityDomainName = L10n.tr("Ui", "activity domain name", fallback: "Full name")
  /// Try using your device, and come back here later, to see where your device connects to.
  internal static let activityEmptyText = L10n.tr("Ui", "activity empty text", fallback: "Try using your device, and come back here later, to see where your device connects to.")
  /// Exact Match Only
  internal static let activityFilterExactMatch = L10n.tr("Ui", "activity filter exact match", fallback: "Exact Match Only")
  /// Which entries would you like to see?
  internal static let activityFilterHeader = L10n.tr("Ui", "activity filter header", fallback: "Which entries would you like to see?")
  /// All entries
  internal static let activityFilterShowAll = L10n.tr("Ui", "activity filter show all", fallback: "All entries")
  /// Allowed only
  internal static let activityFilterShowAllowed = L10n.tr("Ui", "activity filter show allowed", fallback: "Allowed only")
  /// Blocked only
  internal static let activityFilterShowBlocked = L10n.tr("Ui", "activity filter show blocked", fallback: "Blocked only")
  /// Showing for: %@
  internal static func activityFilterShowingFor(_ p1: Any) -> String {
    return L10n.tr("Ui", "activity filter showing for", String(describing: p1), fallback: "Showing for: %@")
  }
  /// %@ times
  internal static func activityHappenedManyTimes(_ p1: Any) -> String {
    return L10n.tr("Ui", "activity happened many times", String(describing: p1), fallback: "%@ times")
  }
  /// 1 time
  internal static let activityHappenedOneTime = L10n.tr("Ui", "activity happened one time", fallback: "1 time")
  /// Information
  internal static let activityInformationHeader = L10n.tr("Ui", "activity information header", fallback: "Information")
  /// Number of occurrences
  internal static let activityNumberOfOccurrences = L10n.tr("Ui", "activity number of occurrences", fallback: "Number of occurrences")
  /// This request has been allowed.
  internal static let activityRequestAllowed = L10n.tr("Ui", "activity request allowed", fallback: "This request has been allowed.")
  /// This request has been allowed, because it's present on the *%@* allowlist.
  internal static func activityRequestAllowedList(_ p1: Any) -> String {
    return L10n.tr("Ui", "activity request allowed list", String(describing: p1), fallback: "This request has been allowed, because it's present on the *%@* allowlist.")
  }
  /// This request has been allowed, as it's not present on any of your configured blocklists.
  internal static let activityRequestAllowedNoList = L10n.tr("Ui", "activity request allowed no list", fallback: "This request has been allowed, as it's not present on any of your configured blocklists.")
  /// This request has been allowed, because it is on your Allowed list
  internal static let activityRequestAllowedWhitelisted = L10n.tr("Ui", "activity request allowed whitelisted", fallback: "This request has been allowed, because it is on your Allowed list")
  /// This request has been blocked.
  internal static let activityRequestBlocked = L10n.tr("Ui", "activity request blocked", fallback: "This request has been blocked.")
  /// This request has been blocked, because it is on your Blocked list
  internal static let activityRequestBlockedBlacklisted = L10n.tr("Ui", "activity request blocked blacklisted", fallback: "This request has been blocked, because it is on your Blocked list")
  /// This request has been blocked, because it's present on the *%@* blocklist.
  internal static func activityRequestBlockedList(_ p1: Any) -> String {
    return L10n.tr("Ui", "activity request blocked list", String(describing: p1), fallback: "This request has been blocked, because it's present on the *%@* blocklist.")
  }
  /// This request has been blocked, as it's not present on any of your configured allowlists.
  internal static let activityRequestBlockedNoList = L10n.tr("Ui", "activity request blocked no list", fallback: "This request has been blocked, as it's not present on any of your configured allowlists.")
  /// Blokada Cloud is not logging anything by default. If you wish to see the aggregated stats and activity from all of your devices, enable activity logging below.
  internal static let activityRetentionDesc = L10n.tr("Ui", "activity retention desc", fallback: "Blokada Cloud is not logging anything by default. If you wish to see the aggregated stats and activity from all of your devices, enable activity logging below.")
  /// Should we store your activity?
  internal static let activityRetentionHeader = L10n.tr("Ui", "activity retention header", fallback: "Should we store your activity?")
  /// Yes, store my activity
  internal static let activityRetentionOption24h = L10n.tr("Ui", "activity retention option 24h", fallback: "Yes, store my activity")
  /// Do not store my activity
  internal static let activityRetentionOptionNone = L10n.tr("Ui", "activity retention option none", fallback: "Do not store my activity")
  /// By enabling activity logging you accept the privacy policy.
  internal static let activityRetentionPolicy = L10n.tr("Ui", "activity retention policy", fallback: "By enabling activity logging you accept the privacy policy.")
  /// Activity
  internal static let activitySectionHeader = L10n.tr("Ui", "activity section header", fallback: "Activity")
  /// Activity Details
  internal static let activitySectionHeaderDetails = L10n.tr("Ui", "activity section header details", fallback: "Activity Details")
  /// allowed
  internal static let activityStateAllowed = L10n.tr("Ui", "activity state allowed", fallback: "allowed")
  /// blocked
  internal static let activityStateBlocked = L10n.tr("Ui", "activity state blocked", fallback: "blocked")
  /// modified
  internal static let activityStateModified = L10n.tr("Ui", "activity state modified", fallback: "modified")
  /// Time
  internal static let activityTimeOfOccurrence = L10n.tr("Ui", "activity time of occurrence", fallback: "Time")
  /// Blocklists
  internal static let advancedSectionHeaderPacks = L10n.tr("Ui", "advanced section header packs", fallback: "Blocklists")
  /// For security reasons, to download a file, we need to open this website in your browser. Then, please tap the download link again.
  internal static let alertDownloadLinkBody = L10n.tr("Ui", "alert download link body", fallback: "For security reasons, to download a file, we need to open this website in your browser. Then, please tap the download link again.")
  /// Ooops!
  internal static let alertErrorHeader = L10n.tr("Ui", "alert error header", fallback: "Ooops!")
  /// Blokada %@ is now available for download. We recommend keeping the app up to date, and downloading it only from our official sources.
  internal static func alertUpdateBody(_ p1: Any) -> String {
    return L10n.tr("Ui", "alert update body", String(describing: p1), fallback: "Blokada %@ is now available for download. We recommend keeping the app up to date, and downloading it only from our official sources.")
  }
  /// BLOKADA+ expired
  internal static let alertVpnExpiredHeader = L10n.tr("Ui", "alert vpn expired header", fallback: "BLOKADA+ expired")
  /// This device
  internal static let appSettingsSectionHeader = L10n.tr("Ui", "app settings section header", fallback: "This device")
  /// Add app
  internal static let bypassActionAdd = L10n.tr("Ui", "bypass action add", fallback: "Add app")
  /// Start typing to search apps.
  internal static let bypassDialogAddBrief = L10n.tr("Ui", "bypass dialog add brief", fallback: "Start typing to search apps.")
  /// Some apps may not work properly with the VPN. You can add them to the bypass list to send their traffic outside the VPN tunnel, which may help with connectivity but reduces privacy. The app also includes a few built-in bypass entries for compatibility. Note: if your device has the 'Block connections without VPN' setting enabled, bypassed apps will not have internet access.
  internal static let bypassInfo = L10n.tr("Ui", "bypass info", fallback: "Some apps may not work properly with the VPN. You can add them to the bypass list to send their traffic outside the VPN tunnel, which may help with connectivity but reduces privacy. The app also includes a few built-in bypass entries for compatibility. Note: if your device has the 'Block connections without VPN' setting enabled, bypassed apps will not have internet access.")
  /// No apps added. Use the Add button at the top to add new apps to this list.
  internal static let bypassNone = L10n.tr("Ui", "bypass none", fallback: "No apps added. Use the Add button at the top to add new apps to this list.")
  /// VPN Bypass
  internal static let bypassSectionHeader = L10n.tr("Ui", "bypass section header", fallback: "VPN Bypass")
  /// Child
  internal static let child = L10n.tr("Ui", "Child", fallback: "Child")
  /// - Check your Internet connection
  /// - Use only one Blokada app
  /// - Deactivate other VPNs
  internal static let connIsssuesDetails = L10n.tr("Ui", "conn isssues details", fallback: "- Check your Internet connection\n- Use only one Blokada app\n- Deactivate other VPNs")
  /// Connectivity issues
  internal static let connIsssuesHeader = L10n.tr("Ui", "conn isssues header", fallback: "Connectivity issues")
  /// Connectivity issues. Please check your configuration. Tap for details.
  internal static let connIsssuesSlug = L10n.tr("Ui", "conn isssues slug", fallback: "Connectivity issues. Please check your configuration. Tap for details.")
  /// Blokada has unexpectedly stopped, and we're sorry for the inconvenience. By sharing the log file with us, you're enhancing the experience for all users. Please help us identify and fix this issue promptly.
  internal static let crashBody = L10n.tr("Ui", "crash body", fallback: "Blokada has unexpectedly stopped, and we're sorry for the inconvenience. By sharing the log file with us, you're enhancing the experience for all users. Please help us identify and fix this issue promptly.")
  /// Custom
  internal static let custom = L10n.tr("Ui", "Custom", fallback: "Custom")
  /// Enter a hostname to add to your exceptions. You can use * as a wildcard, for example *.example.com.
  internal static let dialogExceptionAddText = L10n.tr("Ui", "dialog exception add text", fallback: "Enter a hostname to add to your exceptions. You can use * as a wildcard, for example *.example.com.")
  /// Add an Exception
  internal static let dialogExceptionAddTitle = L10n.tr("Ui", "dialog exception add title", fallback: "Add an Exception")
  /// Use Automatic Protection
  internal static let dialogRuleAuto = L10n.tr("Ui", "dialog rule auto", fallback: "Use Automatic Protection")
  /// Block or allow this domain according to your selected filters.
  /// (Default setting)
  internal static let dialogRuleAutoDesc = L10n.tr("Ui", "dialog rule auto desc", fallback: "Block or allow this domain according to your selected filters.\n(Default setting)")
  /// Always Allow This Domain
  internal static let dialogRuleDomainAllow = L10n.tr("Ui", "dialog rule domain allow", fallback: "Always Allow This Domain")
  /// Always Block This Domain
  internal static let dialogRuleDomainBlock = L10n.tr("Ui", "dialog rule domain block", fallback: "Always Block This Domain")
  /// Ignore filters and always allow traffic to %@.
  internal static func dialogRuleDomainDescAllow(_ p1: Any) -> String {
    return L10n.tr("Ui", "dialog rule domain desc allow", String(describing: p1), fallback: "Ignore filters and always allow traffic to %@.")
  }
  /// Ignore filters and always block traffic to %@.
  internal static func dialogRuleDomainDescBlock(_ p1: Any) -> String {
    return L10n.tr("Ui", "dialog rule domain desc block", String(describing: p1), fallback: "Ignore filters and always block traffic to %@.")
  }
  /// Always Allow This Domain and Its Subdomains
  internal static let dialogRuleSubdomainsAllow = L10n.tr("Ui", "dialog rule subdomains allow", fallback: "Always Allow This Domain and Its Subdomains")
  /// Always Block This Domain and Its Subdomains
  internal static let dialogRuleSubdomainsBlock = L10n.tr("Ui", "dialog rule subdomains block", fallback: "Always Block This Domain and Its Subdomains")
  /// Allow traffic to %@ and every subdomain beneath it.
  internal static func dialogRuleSubdomainsDescAllow(_ p1: Any) -> String {
    return L10n.tr("Ui", "dialog rule subdomains desc allow", String(describing: p1), fallback: "Allow traffic to %@ and every subdomain beneath it.")
  }
  /// Block traffic to %@ and every subdomain beneath it.
  internal static func dialogRuleSubdomainsDescBlock(_ p1: Any) -> String {
    return L10n.tr("Ui", "dialog rule subdomains desc block", String(describing: p1), fallback: "Block traffic to %@ and every subdomain beneath it.")
  }
  /// How Should Blokada Handle Traffic to %@?
  internal static func dialogTitleActivityRule(_ p1: Any) -> String {
    return L10n.tr("Ui", "dialog title activity rule", String(describing: p1), fallback: "How Should Blokada Handle Traffic to %@?")
  }
  /// Open Settings
  internal static let dnsprofileActionOpenSettings = L10n.tr("Ui", "dnsprofile action open settings", fallback: "Open Settings")
  /// In the Settings app, navigate to General → VPN, DNS & Device Management → DNS and select Blokada.
  internal static let dnsprofileDesc = L10n.tr("Ui", "dnsprofile desc", fallback: "In the Settings app, navigate to General → VPN, DNS & Device Management → DNS and select Blokada.")
  /// In the Settings app, find the Private DNS section, and then paste your hostname (long tap).
  internal static let dnsprofileDescAndroid = L10n.tr("Ui", "dnsprofile desc android", fallback: "In the Settings app, find the Private DNS section, and then paste your hostname (long tap).")
  /// Copy your Blokada Cloud hostname to paste it in Settings.
  internal static let dnsprofileDescAndroidCopy = L10n.tr("Ui", "dnsprofile desc android copy", fallback: "Copy your Blokada Cloud hostname to paste it in Settings.")
  /// Enable Blokada in Settings
  internal static let dnsprofileHeader = L10n.tr("Ui", "dnsprofile header", fallback: "Enable Blokada in Settings")
  /// General → VPN, DNS & Device Management → DNS and select Blokada.
  internal static let dnsprofileNotificationBody = L10n.tr("Ui", "dnsprofile notification body", fallback: "General → VPN, DNS & Device Management → DNS and select Blokada.")
  /// In the Settings app, navigate to:
  internal static let dnsprofileNotificationSubtitle = L10n.tr("Ui", "dnsprofile notification subtitle", fallback: "In the Settings app, navigate to:")
  /// Search Subdomains
  internal static let domainDetailsActionSearchSubdomains = L10n.tr("Ui", "domain details action search subdomains", fallback: "Search Subdomains")
  /// Add a Rule
  internal static let domainDetailsAddRuleAction = L10n.tr("Ui", "domain details add rule action", fallback: "Add a Rule")
  /// Create a rule for this domain.
  internal static let domainDetailsAddRuleBrief = L10n.tr("Ui", "domain details add rule brief", fallback: "Create a rule for this domain.")
  /// Edit Matching Rule
  internal static let domainDetailsEditRuleAction = L10n.tr("Ui", "domain details edit rule action", fallback: "Edit Matching Rule")
  /// Applies to %@.
  internal static func domainDetailsEditRuleBrief(_ p1: Any) -> String {
    return L10n.tr("Ui", "domain details edit rule brief", String(describing: p1), fallback: "Applies to %@.")
  }
  /// Subdomains
  internal static let domainDetailsHeaderSubdomains = L10n.tr("Ui", "domain details header subdomains", fallback: "Subdomains")
  /// Your Custom Rules
  internal static let domainDetailsRulesSectionHeader = L10n.tr("Ui", "domain details rules section header", fallback: "Your Custom Rules")
  /// Domain Details
  internal static let domainDetailsSectionHeader = L10n.tr("Ui", "domain details section header", fallback: "Domain Details")
  /// Allowed %@ request(s) to %@.
  internal static func domainDetailsSummaryAllowedBasic(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "domain details summary allowed basic", String(describing: p1), String(describing: p2), fallback: "Allowed %@ request(s) to %@.")
  }
  /// Your rules allowed %@ request(s) to %@.
  internal static func domainDetailsSummaryAllowedBasicCustomlist(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "domain details summary allowed basic customlist", String(describing: p1), String(describing: p2), fallback: "Your rules allowed %@ request(s) to %@.")
  }
  /// Allowed %@ request(s) to %@ using %@.
  internal static func domainDetailsSummaryAllowedBasicList(_ p1: Any, _ p2: Any, _ p3: Any) -> String {
    return L10n.tr("Ui", "domain details summary allowed basic list", String(describing: p1), String(describing: p2), String(describing: p3), fallback: "Allowed %@ request(s) to %@ using %@.")
  }
  /// Allowed %@ request(s) to %@ and %@ request(s) to its subdomains.
  internal static func domainDetailsSummaryAllowedBoth(_ p1: Any, _ p2: Any, _ p3: Any) -> String {
    return L10n.tr("Ui", "domain details summary allowed both", String(describing: p1), String(describing: p2), String(describing: p3), fallback: "Allowed %@ request(s) to %@ and %@ request(s) to its subdomains.")
  }
  /// Your rules allowed %@ request(s) to %@ and %@ request(s) to its subdomains.
  internal static func domainDetailsSummaryAllowedBothCustomlist(_ p1: Any, _ p2: Any, _ p3: Any) -> String {
    return L10n.tr("Ui", "domain details summary allowed both customlist", String(describing: p1), String(describing: p2), String(describing: p3), fallback: "Your rules allowed %@ request(s) to %@ and %@ request(s) to its subdomains.")
  }
  /// Allowed %@ request(s) to %@ and %@ request(s) to its subdomains using %@.
  internal static func domainDetailsSummaryAllowedBothList(_ p1: Any, _ p2: Any, _ p3: Any, _ p4: Any) -> String {
    return L10n.tr("Ui", "domain details summary allowed both list", String(describing: p1), String(describing: p2), String(describing: p3), String(describing: p4), fallback: "Allowed %@ request(s) to %@ and %@ request(s) to its subdomains using %@.")
  }
  /// Allowed %@ request(s) to subdomains of %@.
  internal static func domainDetailsSummaryAllowedSubdomain(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "domain details summary allowed subdomain", String(describing: p1), String(describing: p2), fallback: "Allowed %@ request(s) to subdomains of %@.")
  }
  /// Your rules allowed %@ request(s) to subdomains of %@.
  internal static func domainDetailsSummaryAllowedSubdomainCustomlist(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "domain details summary allowed subdomain customlist", String(describing: p1), String(describing: p2), fallback: "Your rules allowed %@ request(s) to subdomains of %@.")
  }
  /// Allowed %@ request(s) to subdomains of %@ using %@.
  internal static func domainDetailsSummaryAllowedSubdomainList(_ p1: Any, _ p2: Any, _ p3: Any) -> String {
    return L10n.tr("Ui", "domain details summary allowed subdomain list", String(describing: p1), String(describing: p2), String(describing: p3), fallback: "Allowed %@ request(s) to subdomains of %@ using %@.")
  }
  /// Blocked %@ request(s) to %@.
  internal static func domainDetailsSummaryBlockedBasic(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "domain details summary blocked basic", String(describing: p1), String(describing: p2), fallback: "Blocked %@ request(s) to %@.")
  }
  /// Your rules blocked %@ request(s) to %@.
  internal static func domainDetailsSummaryBlockedBasicCustomlist(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "domain details summary blocked basic customlist", String(describing: p1), String(describing: p2), fallback: "Your rules blocked %@ request(s) to %@.")
  }
  /// Blocked %@ request(s) to %@ using %@.
  internal static func domainDetailsSummaryBlockedBasicList(_ p1: Any, _ p2: Any, _ p3: Any) -> String {
    return L10n.tr("Ui", "domain details summary blocked basic list", String(describing: p1), String(describing: p2), String(describing: p3), fallback: "Blocked %@ request(s) to %@ using %@.")
  }
  /// Blocked %@ request(s) to %@ and %@ request(s) to its subdomains.
  internal static func domainDetailsSummaryBlockedBoth(_ p1: Any, _ p2: Any, _ p3: Any) -> String {
    return L10n.tr("Ui", "domain details summary blocked both", String(describing: p1), String(describing: p2), String(describing: p3), fallback: "Blocked %@ request(s) to %@ and %@ request(s) to its subdomains.")
  }
  /// Your rules blocked %@ request(s) to %@ and %@ request(s) to its subdomains.
  internal static func domainDetailsSummaryBlockedBothCustomlist(_ p1: Any, _ p2: Any, _ p3: Any) -> String {
    return L10n.tr("Ui", "domain details summary blocked both customlist", String(describing: p1), String(describing: p2), String(describing: p3), fallback: "Your rules blocked %@ request(s) to %@ and %@ request(s) to its subdomains.")
  }
  /// Blocked %@ request(s) to %@ and %@ request(s) to its subdomains using %@.
  internal static func domainDetailsSummaryBlockedBothList(_ p1: Any, _ p2: Any, _ p3: Any, _ p4: Any) -> String {
    return L10n.tr("Ui", "domain details summary blocked both list", String(describing: p1), String(describing: p2), String(describing: p3), String(describing: p4), fallback: "Blocked %@ request(s) to %@ and %@ request(s) to its subdomains using %@.")
  }
  /// Blocked %@ request(s) to subdomains of %@.
  internal static func domainDetailsSummaryBlockedSubdomain(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "domain details summary blocked subdomain", String(describing: p1), String(describing: p2), fallback: "Blocked %@ request(s) to subdomains of %@.")
  }
  /// Your rules blocked %@ request(s) to subdomains of %@.
  internal static func domainDetailsSummaryBlockedSubdomainCustomlist(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "domain details summary blocked subdomain customlist", String(describing: p1), String(describing: p2), fallback: "Your rules blocked %@ request(s) to subdomains of %@.")
  }
  /// Blocked %@ request(s) to subdomains of %@ using %@.
  internal static func domainDetailsSummaryBlockedSubdomainList(_ p1: Any, _ p2: Any, _ p3: Any) -> String {
    return L10n.tr("Ui", "domain details summary blocked subdomain list", String(describing: p1), String(describing: p2), String(describing: p3), fallback: "Blocked %@ request(s) to subdomains of %@ using %@.")
  }
  /// No requests to %@ or its subdomains.
  internal static func domainDetailsSummaryNone(_ p1: Any) -> String {
    return L10n.tr("Ui", "domain details summary none", String(describing: p1), fallback: "No requests to %@ or its subdomains.")
  }
  /// Your account is inactive. Please activate your account in order to continue using BLOKADA+.
  internal static let errorAccountInactive = L10n.tr("Ui", "error account inactive", fallback: "Your account is inactive. Please activate your account in order to continue using BLOKADA+.")
  /// This does not seem to be a valid active account. If you believe this is a mistake, please contact us.
  internal static let errorAccountInactiveAfterRestore = L10n.tr("Ui", "error account inactive after restore", fallback: "This does not seem to be a valid active account. If you believe this is a mistake, please contact us.")
  /// Your account is inactive. Please activate your account in order to continue using Blokada.
  internal static let errorAccountInactiveGeneric = L10n.tr("Ui", "error account inactive generic", fallback: "Your account is inactive. Please activate your account in order to continue using Blokada.")
  /// This account ID seems invalid.
  internal static let errorAccountInvalid = L10n.tr("Ui", "error account invalid", fallback: "This account ID seems invalid.")
  /// Could not create a new account. Please try again later.
  internal static let errorCreatingAccount = L10n.tr("Ui", "error creating account", fallback: "Could not create a new account. Please try again later.")
  /// Your device is offline
  internal static let errorDeviceOffline = L10n.tr("Ui", "error device offline", fallback: "Your device is offline")
  /// This action could not be completed. Make sure you are online, and try again later. If the problem persists, please contact us by tapping the help icon at the top.
  internal static let errorFetchingData = L10n.tr("Ui", "error fetching data", fallback: "This action could not be completed. Make sure you are online, and try again later. If the problem persists, please contact us by tapping the help icon at the top.")
  /// Could not fetch locations.
  internal static let errorLocationFailedFetching = L10n.tr("Ui", "error location failed fetching", fallback: "Could not fetch locations.")
  /// A valid PIN must be exactly 4 digits. Please try again.
  internal static let errorLockInvalid = L10n.tr("Ui", "error lock invalid", fallback: "A valid PIN must be exactly 4 digits. Please try again.")
  /// This action is unavailable when the app is in a locked state. Please unlock the app to proceed.
  internal static let errorLocked = L10n.tr("Ui", "error locked", fallback: "This action is unavailable when the app is in a locked state. Please unlock the app to proceed.")
  /// There is more than one Blokada app on your device. This may cause connectivity issues. Do you wish to fix it now?
  internal static let errorMultipleApps = L10n.tr("Ui", "error multiple apps", fallback: "There is more than one Blokada app on your device. This may cause connectivity issues. Do you wish to fix it now?")
  /// Could not install (or uninstall) this feature. Please try again later.
  internal static let errorPackInstall = L10n.tr("Ui", "error pack install", fallback: "Could not install (or uninstall) this feature. Please try again later.")
  /// The payment has been canceled. You have not been charged.
  internal static let errorPaymentCanceled = L10n.tr("Ui", "error payment canceled", fallback: "The payment has been canceled. You have not been charged.")
  /// Payments are unavailable at this moment. Make sure you are online, and try again later. If the problem persists, please contact us by tapping the help icon at the top.
  internal static let errorPaymentFailed = L10n.tr("Ui", "error payment failed", fallback: "Payments are unavailable at this moment. Make sure you are online, and try again later. If the problem persists, please contact us by tapping the help icon at the top.")
  /// Could not complete your payment. Please make sure your data is correct, and try again. If the problem persists, please contact us by tapping the help icon at the top.
  internal static let errorPaymentFailedAlternative = L10n.tr("Ui", "error payment failed alternative", fallback: "Could not complete your payment. Please make sure your data is correct, and try again. If the problem persists, please contact us by tapping the help icon at the top.")
  /// Your previous payment was restored, but the subscription has already expired. If you believe this is a mistake, please contact us by tapping the help icon at the top.
  internal static let errorPaymentInactiveAfterRestore = L10n.tr("Ui", "error payment inactive after restore", fallback: "Your previous payment was restored, but the subscription has already expired. If you believe this is a mistake, please contact us by tapping the help icon at the top.")
  /// Payments are unavailable for this device. Either this device is not updated, or we do not handle purchases in your country yet.
  internal static let errorPaymentNotAvailable = L10n.tr("Ui", "error payment not available", fallback: "Payments are unavailable for this device. Either this device is not updated, or we do not handle purchases in your country yet.")
  /// Could not establish the VPN. Please restart your device, or remove Blokada VPN profile in system settings, and try again.
  internal static let errorTunnel = L10n.tr("Ui", "error tunnel", fallback: "Could not establish the VPN. Please restart your device, or remove Blokada VPN profile in system settings, and try again.")
  /// A problem occurred. Make sure you are online, and try again later. If the problem persists, please contact us by tapping the help icon at the top.
  internal static let errorUnknown = L10n.tr("Ui", "error unknown", fallback: "A problem occurred. Make sure you are online, and try again later. If the problem persists, please contact us by tapping the help icon at the top.")
  /// Could not establish the VPN. Please restart your device, or remove Blokada VPN profile in system settings, and try again.
  internal static let errorVpn = L10n.tr("Ui", "error vpn", fallback: "Could not establish the VPN. Please restart your device, or remove Blokada VPN profile in system settings, and try again.")
  /// The VPN is disabled. Please update your subscription to continue using BLOKADA+
  internal static let errorVpnExpired = L10n.tr("Ui", "error vpn expired", fallback: "The VPN is disabled. Please update your subscription to continue using BLOKADA+")
  /// Please select a location first.
  internal static let errorVpnNoCurrentLease = L10n.tr("Ui", "error vpn no current lease", fallback: "Please select a location first.")
  /// Blokada Plus is now disabled on this device. Please select a location to reactivate it.
  internal static let errorVpnNoCurrentLeaseNew = L10n.tr("Ui", "error vpn no current lease new", fallback: "Blokada Plus is now disabled on this device. Please select a location to reactivate it.")
  /// No permissions granted to create a VPN profile.
  internal static let errorVpnPerms = L10n.tr("Ui", "error vpn perms", fallback: "No permissions granted to create a VPN profile.")
  /// You reached your devices limit. Please remove one of your devices and try again.
  internal static let errorVpnTooManyLeases = L10n.tr("Ui", "error vpn too many leases", fallback: "You reached your devices limit. Please remove one of your devices and try again.")
  /// To link this device to the parent device, complete the setup process. Once linked, this device will be locked, allowing you to configure and monitor it from the parent device.
  internal static let familyAccountAttachBody = L10n.tr("Ui", "family account attach body", fallback: "To link this device to the parent device, complete the setup process. Once linked, this device will be locked, allowing you to configure and monitor it from the parent device.")
  /// Attach device
  internal static let familyAccountAttachHeader = L10n.tr("Ui", "family account attach header", fallback: "Attach device")
  /// Unlink
  internal static let familyAccountCtaUnlink = L10n.tr("Ui", "family account cta unlink", fallback: "Unlink")
  /// Add device
  internal static let familyAccountDecideHeader = L10n.tr("Ui", "family account decide header", fallback: "Add device")
  /// In Blokada, you simply scan a QR code to link and manage another device.
  internal static let familyAccountDecideLinkBody = L10n.tr("Ui", "family account decide link body", fallback: "In Blokada, you simply scan a QR code to link and manage another device.")
  /// Link a device
  internal static let familyAccountDecideLinkHeader = L10n.tr("Ui", "family account decide link header", fallback: "Link a device")
  /// - or -
  internal static let familyAccountDecideSeparator = L10n.tr("Ui", "family account decide separator", fallback: "- or -")
  /// Alternatively, you may simply configure Blokada to work on this device, and set the pin to lock the app.
  internal static let familyAccountDecideThisBody = L10n.tr("Ui", "family account decide this body", fallback: "Alternatively, you may simply configure Blokada to work on this device, and set the pin to lock the app.")
  /// Use this device
  internal static let familyAccountDecideThisHeader = L10n.tr("Ui", "family account decide this header", fallback: "Use this device")
  /// Link device
  internal static let familyAccountLinkHeader = L10n.tr("Ui", "family account link header", fallback: "Link device")
  /// Set device name
  internal static let familyAccountLinkName = L10n.tr("Ui", "family account link name", fallback: "Set device name")
  /// This screen will close automatically once the new device has been detected.
  internal static let familyAccountLinkQrBody = L10n.tr("Ui", "family account link qr body", fallback: "This screen will close automatically once the new device has been detected.")
  /// Scan this QR code
  internal static let familyAccountLinkQrHeader = L10n.tr("Ui", "family account link qr header", fallback: "Scan this QR code")
  /// Scan
  internal static let familyAccountQrActionButton = L10n.tr("Ui", "family account qr action button", fallback: "Scan")
  /// Scan the QR code from the parent device, in order to initiate the linking process.
  internal static let familyAccountQrBody = L10n.tr("Ui", "family account qr body", fallback: "Scan the QR code from the parent device, in order to initiate the linking process.")
  /// Scan QR code
  internal static let familyAccountQrHeader = L10n.tr("Ui", "family account qr header", fallback: "Scan QR code")
  /// Enter your account ID to restore your purchases.
  internal static let familyAccountRestoreDesc = L10n.tr("Ui", "family account restore desc", fallback: "Enter your account ID to restore your purchases.")
  /// allowed %@ times
  internal static func familyActivityAllowedTimes(_ p1: Any) -> String {
    return L10n.tr("Ui", "family activity allowed times", String(describing: p1), fallback: "allowed %@ times")
  }
  /// blocked %@ times
  internal static func familyActivityBlockedTimes(_ p1: Any) -> String {
    return L10n.tr("Ui", "family activity blocked times", String(describing: p1), fallback: "blocked %@ times")
  }
  /// Activate
  internal static let familyCtaActionActivate = L10n.tr("Ui", "family cta action activate", fallback: "Activate")
  /// Add a device
  internal static let familyCtaActionAddDevice = L10n.tr("Ui", "family cta action add device", fallback: "Add a device")
  /// Finish setup
  internal static let familyCtaActionFinishSetup = L10n.tr("Ui", "family cta action finish setup", fallback: "Finish setup")
  /// Link
  internal static let familyCtaActionLink = L10n.tr("Ui", "family cta action link", fallback: "Link")
  /// Unlock
  internal static let familyCtaActionUnlock = L10n.tr("Ui", "family cta action unlock", fallback: "Unlock")
  /// Delete this device
  internal static let familyDeviceActionDelete = L10n.tr("Ui", "family device action delete", fallback: "Delete this device")
  /// Link this device again
  internal static let familyDeviceActionLink = L10n.tr("Ui", "family device action link", fallback: "Link this device again")
  /// Manage Internet access for this device.
  internal static let familyDeviceBriefInternet = L10n.tr("Ui", "family device brief internet", fallback: "Manage Internet access for this device.")
  /// Stops all Internet access on the device.
  internal static let familyDeviceBriefInternetBlock = L10n.tr("Ui", "family device brief internet block", fallback: "Stops all Internet access on the device.")
  /// No content is blocked. The Internet is fully open.
  internal static let familyDeviceBriefInternetOff = L10n.tr("Ui", "family device brief internet off", fallback: "No content is blocked. The Internet is fully open.")
  /// Blocks harmful and inappropriate sites according to your filters and blocklists.
  internal static let familyDeviceBriefInternetOn = L10n.tr("Ui", "family device brief internet on", fallback: "Blocks harmful and inappropriate sites according to your filters and blocklists.")
  /// Manage blocking settings for this device.
  internal static let familyDeviceBriefSettingsAlt = L10n.tr("Ui", "family device brief settings alt", fallback: "Manage blocking settings for this device.")
  /// See the recent activity of this device.
  internal static let familyDeviceBriefStatistics = L10n.tr("Ui", "family device brief statistics", fallback: "See the recent activity of this device.")
  /// Are you sure you want to delete %@? This will unlink the device from your account.
  internal static func familyDeviceDeleteConfirm(_ p1: Any) -> String {
    return L10n.tr("Ui", "family device delete confirm", String(describing: p1), fallback: "Are you sure you want to delete %@? This will unlink the device from your account.")
  }
  /// Add a device
  internal static let familyDeviceHeaderAdd = L10n.tr("Ui", "family device header add", fallback: "Add a device")
  /// Link a device
  internal static let familyDeviceHeaderLink = L10n.tr("Ui", "family device header link", fallback: "Link a device")
  /// INTERNET CONTROL
  internal static let familyDeviceLabelInternet = L10n.tr("Ui", "family device label internet", fallback: "INTERNET CONTROL")
  /// Block All
  internal static let familyDeviceLabelInternetBlock = L10n.tr("Ui", "family device label internet block", fallback: "Block All")
  /// Allow All
  internal static let familyDeviceLabelInternetOff = L10n.tr("Ui", "family device label internet off", fallback: "Allow All")
  /// Filter Content
  internal static let familyDeviceLabelInternetOn = L10n.tr("Ui", "family device label internet on", fallback: "Filter Content")
  /// DEVICE SETTINGS
  internal static let familyDeviceLabelSettings = L10n.tr("Ui", "family device label settings", fallback: "DEVICE SETTINGS")
  /// STATISTICS
  internal static let familyDeviceLabelStatistics = L10n.tr("Ui", "family device label statistics", fallback: "STATISTICS")
  /// Details
  internal static let familyDeviceTitleDetails = L10n.tr("Ui", "family device title details", fallback: "Details")
  /// Enter a name for this device.
  internal static let familyDialogBriefDevice = L10n.tr("Ui", "family dialog brief device", fallback: "Enter a name for this device.")
  /// Enter a name for this profile.
  internal static let familyDialogBriefProfile = L10n.tr("Ui", "family dialog brief profile", fallback: "Enter a name for this profile.")
  /// New device
  internal static let familyDialogTitleNewDevice = L10n.tr("Ui", "family dialog title new device", fallback: "New device")
  /// New profile
  internal static let familyDialogTitleNewProfile = L10n.tr("Ui", "family dialog title new profile", fallback: "New profile")
  /// Rename device
  internal static let familyDialogTitleRenameDevice = L10n.tr("Ui", "family dialog title rename device", fallback: "Rename device")
  /// Rename profile
  internal static let familyDialogTitleRenameProfile = L10n.tr("Ui", "family dialog title rename profile", fallback: "Rename profile")
  /// This device is already linked. Please unlink it using the parent app and try again.
  internal static let familyFaultLinkAlready = L10n.tr("Ui", "family fault link already", fallback: "This device is already linked. Please unlink it using the parent app and try again.")
  /// This device (%@)
  internal static func familyLabelThisDevice(_ p1: Any) -> String {
    return L10n.tr("Ui", "family label this device", String(describing: p1), fallback: "This device (%@)")
  }
  /// Scan the QR code below to link a device again. This screen will close automatically once the device is detected.
  internal static let familyLinkDescriptionAgain = L10n.tr("Ui", "family link description again", fallback: "Scan the QR code below to link a device again. This screen will close automatically once the device is detected.")
  /// Scan the QR code below to add a device to your family. This screen will close automatically once the device is detected.
  internal static let familyLinkDescriptionNew = L10n.tr("Ui", "family link description new", fallback: "Scan the QR code below to add a device to your family. This screen will close automatically once the device is detected.")
  /// Family protection is off
  internal static let familyNotificationSubtitle = L10n.tr("Ui", "family notification subtitle", fallback: "Family protection is off")
  /// Follow the instructions on screen to set up your first device.
  internal static let familyOnboardBody = L10n.tr("Ui", "family onboard body", fallback: "Follow the instructions on screen to set up your first device.")
  /// Welcome to Blokada Family!
  internal static let familyOnboardHeader = L10n.tr("Ui", "family onboard header", fallback: "Welcome to Blokada Family!")
  /// Welcome to %s!
  internal static func familyOnboardHeaderBrand(_ p1: UnsafePointer<CChar>) -> String {
    return L10n.tr("Ui", "family onboard header brand", p1, fallback: "Welcome to %s!")
  }
  /// Activating Blokada won't drain your battery. It might actually help it last longer by blocking unnecessary background activities.
  internal static let familyPaymentFeaturesBatteryBody = L10n.tr("Ui", "family payment features battery body", fallback: "Activating Blokada won't drain your battery. It might actually help it last longer by blocking unnecessary background activities.")
  /// Manage and monitor all your devices through a single app. Control access and content filtering directly from your device.
  internal static let familyPaymentFeaturesDevicesBody = L10n.tr("Ui", "family payment features devices body", fallback: "Manage and monitor all your devices through a single app. Control access and content filtering directly from your device.")
  /// Family Device Monitoring
  internal static let familyPaymentFeaturesDevicesHeader = L10n.tr("Ui", "family payment features devices header", fallback: "Family Device Monitoring")
  /// Enhance privacy across all your devices with DNS encryption. Blokada utilizes cutting-edge protocols to ensure your internet traffic remains confidential.
  internal static let familyPaymentFeaturesDnsBody = L10n.tr("Ui", "family payment features dns body", fallback: "Enhance privacy across all your devices with DNS encryption. Blokada utilizes cutting-edge protocols to ensure your internet traffic remains confidential.")
  /// Maintain a swift and responsive device while ensuring your internet connection remains at peak speeds, all thanks to our proven technology.
  internal static let familyPaymentFeaturesPerformanceBody = L10n.tr("Ui", "family payment features performance body", fallback: "Maintain a swift and responsive device while ensuring your internet connection remains at peak speeds, all thanks to our proven technology.")
  /// Protect your entire family with one subscription. Monitor and protect all family devices from unwanted content.
  internal static let familyPaymentSlug = L10n.tr("Ui", "family payment slug", fallback: "Protect your entire family with one subscription. Monitor and protect all family devices from unwanted content.")
  /// Activate '%@' in Settings by navigating as shown below.
  internal static func familyPermsBriefAlt(_ p1: Any) -> String {
    return L10n.tr("Ui", "family perms brief alt", String(describing: p1), fallback: "Activate '%@' in Settings by navigating as shown below.")
  }
  /// Finally, tap and hold the text field to paste the necessary configuration.
  internal static let familyPermsCopyAndroid = L10n.tr("Ui", "family perms copy android", fallback: "Finally, tap and hold the text field to paste the necessary configuration.")
  /// One more thing
  internal static let familyPermsHeader = L10n.tr("Ui", "family perms header", fallback: "One more thing")
  /// Connections
  internal static let familyPermsSettingAndroidConnections = L10n.tr("Ui", "family perms setting android connections", fallback: "Connections")
  /// Private DNS
  internal static let familyPermsSettingAndroidDns = L10n.tr("Ui", "family perms setting android dns", fallback: "Private DNS")
  /// Private DNS provider hostname
  internal static let familyPermsSettingAndroidHost = L10n.tr("Ui", "family perms setting android host", fallback: "Private DNS provider hostname")
  /// More connection settings
  internal static let familyPermsSettingAndroidMore = L10n.tr("Ui", "family perms setting android more", fallback: "More connection settings")
  /// (not always present)
  internal static let familyPermsSettingAndroidOptional = L10n.tr("Ui", "family perms setting android optional", fallback: "(not always present)")
  /// (or similar)
  internal static let familyPermsSettingAndroidSimilar = L10n.tr("Ui", "family perms setting android similar", fallback: "(or similar)")
  /// Automatic
  internal static let familyPermsSettingIosAutomatic = L10n.tr("Ui", "family perms setting ios automatic", fallback: "Automatic")
  /// DNS
  internal static let familyPermsSettingIosDns = L10n.tr("Ui", "family perms setting ios dns", fallback: "DNS")
  /// General
  internal static let familyPermsSettingIosGeneral = L10n.tr("Ui", "family perms setting ios general", fallback: "General")
  /// VPN & Device Management
  internal static let familyPermsSettingIosVpn = L10n.tr("Ui", "family perms setting ios vpn", fallback: "VPN & Device Management")
  /// Add new profile
  internal static let familyProfileActionAdd = L10n.tr("Ui", "family profile action add", fallback: "Add new profile")
  /// Remove this profile
  internal static let familyProfileActionDelete = L10n.tr("Ui", "family profile action delete", fallback: "Remove this profile")
  /// Select profile
  internal static let familyProfileActionSelect = L10n.tr("Ui", "family profile action select", fallback: "Select profile")
  /// Which profile would you like to add?
  internal static let familyProfileAdd = L10n.tr("Ui", "family profile add", fallback: "Which profile would you like to add?")
  /// Select a profile to use for %@.
  internal static func familyProfileDialogHeader(_ p1: Any) -> String {
    return L10n.tr("Ui", "family profile dialog header", String(describing: p1), fallback: "Select a profile to use for %@.")
  }
  /// Select a profile to use for this device.
  internal static let familyProfileDialogHeaderThis = L10n.tr("Ui", "family profile dialog header this", fallback: "Select a profile to use for this device.")
  /// Failed to delete this profile.
  internal static let familyProfileError = L10n.tr("Ui", "family profile error", fallback: "Failed to delete this profile.")
  /// This profile is currently in use. Ensure no device is using it before deletion.
  internal static let familyProfileErrorUse = L10n.tr("Ui", "family profile error use", fallback: "This profile is currently in use. Ensure no device is using it before deletion.")
  /// Child
  internal static let familyProfileNameChild = L10n.tr("Ui", "family profile name child", fallback: "Child")
  /// Custom
  internal static let familyProfileNameCustom = L10n.tr("Ui", "family profile name custom", fallback: "Custom")
  /// Parent
  internal static let familyProfileNameParent = L10n.tr("Ui", "family profile name parent", fallback: "Parent")
  /// Choose a template to get started.
  internal static let familyProfileTemplate = L10n.tr("Ui", "family profile template", fallback: "Choose a template to get started.")
  /// %@ Profile
  internal static func familyProfileTemplateName(_ p1: Any) -> String {
    return L10n.tr("Ui", "family profile template name", String(describing: p1), fallback: "%@ Profile")
  }
  /// Scan the QR code displayed on the parent device
  internal static let familyQrBrief = L10n.tr("Ui", "family qr brief", fallback: "Scan the QR code displayed on the parent device")
  /// Rename device
  internal static let familyRenameDevice = L10n.tr("Ui", "family rename device", fallback: "Rename device")
  /// No matches found for your search criteria
  internal static let familySearchEmpty = L10n.tr("Ui", "family search empty", fallback: "No matches found for your search criteria")
  /// Enter your new pin
  internal static let familySettingsLockEnter = L10n.tr("Ui", "family settings lock enter", fallback: "Enter your new pin")
  /// Lock with pin
  internal static let familySettingsLockPin = L10n.tr("Ui", "family settings lock pin", fallback: "Lock with pin")
  /// Remove pin
  internal static let familySettingsLockRemove = L10n.tr("Ui", "family settings lock remove", fallback: "Remove pin")
  /// Manage your own custom entries to block or allow.
  internal static let familyShieldsCustomSlug = L10n.tr("Ui", "family shields custom slug", fallback: "Manage your own custom entries to block or allow.")
  /// Activate shields to block access to selected content on your supervised devices.
  internal static let familyShieldsHeader = L10n.tr("Ui", "family shields header", fallback: "Activate shields to block access to selected content on your supervised devices.")
  /// Add to My exceptions
  internal static let familyStatsExceptionsAdd = L10n.tr("Ui", "family stats exceptions add", fallback: "Add to My exceptions")
  /// Remove from My exceptions
  internal static let familyStatsExceptionsRemove = L10n.tr("Ui", "family stats exceptions remove", fallback: "Remove from My exceptions")
  /// Show most common first
  internal static let familyStatsFilterMostCommon = L10n.tr("Ui", "family stats filter most common", fallback: "Show most common first")
  /// Blocklist
  internal static let familyStatsLabelBlocklist = L10n.tr("Ui", "family stats label blocklist", fallback: "Blocklist")
  /// Blocklists
  internal static let familyStatsLabelBlocklists = L10n.tr("Ui", "family stats label blocklists", fallback: "Blocklists")
  /// Blocklists in profile
  internal static let familyStatsLabelBlocklistsAlt = L10n.tr("Ui", "family stats label blocklists alt", fallback: "Blocklists in profile")
  /// %@ selected
  internal static func familyStatsLabelBlocklistsCount(_ p1: Any) -> String {
    return L10n.tr("Ui", "family stats label blocklists count", String(describing: p1), fallback: "%@ selected")
  }
  /// None
  internal static let familyStatsLabelNone = L10n.tr("Ui", "family stats label none", fallback: "None")
  /// Pause blocking
  internal static let familyStatsLabelPause = L10n.tr("Ui", "family stats label pause", fallback: "Pause blocking")
  /// Profile
  internal static let familyStatsLabelProfile = L10n.tr("Ui", "family stats label profile", fallback: "Profile")
  /// Unknown
  internal static let familyStatsLabelProfileUnknown = L10n.tr("Ui", "family stats label profile unknown", fallback: "Unknown")
  /// Reason
  internal static let familyStatsLabelReason = L10n.tr("Ui", "family stats label reason", fallback: "Reason")
  /// My exceptions
  internal static let familyStatsTitle = L10n.tr("Ui", "family stats title", fallback: "My exceptions")
  /// Tap on the device for more details.
  internal static let familyStatusActiveBody = L10n.tr("Ui", "family status active body", fallback: "Tap on the device for more details.")
  /// Active!
  internal static let familyStatusActiveHeader = L10n.tr("Ui", "family status active header", fallback: "Active!")
  /// Please activate your account to continue
  internal static let familyStatusExpiredBody = L10n.tr("Ui", "family status expired body", fallback: "Please activate your account to continue")
  /// Account expired
  internal static let familyStatusExpiredHeader = L10n.tr("Ui", "family status expired header", fallback: "Account expired")
  /// Activate or restore your account to continue
  internal static let familyStatusFreshBody = L10n.tr("Ui", "family status fresh body", fallback: "Activate or restore your account to continue")
  /// Hi there!
  internal static let familyStatusFreshHeader = L10n.tr("Ui", "family status fresh header", fallback: "Hi there!")
  /// Manage this device using the parent device.
  internal static let familyStatusLinkedBody = L10n.tr("Ui", "family status linked body", fallback: "Manage this device using the parent device.")
  /// App is linked!
  internal static let familyStatusLinkedHeader = L10n.tr("Ui", "family status linked header", fallback: "App is linked!")
  /// App is locked
  internal static let familyStatusLockedHeader = L10n.tr("Ui", "family status locked header", fallback: "App is locked")
  /// Please grant the necessary permissions
  internal static let familyStatusPermsBody = L10n.tr("Ui", "family status perms body", fallback: "Please grant the necessary permissions")
  /// Tap to finish the setup procedure
  internal static let familyStatusPermsBodyAlt = L10n.tr("Ui", "family status perms body alt", fallback: "Tap to finish the setup procedure")
  /// Almost there!
  internal static let familyStatusPermsHeader = L10n.tr("Ui", "family status perms header", fallback: "Almost there!")
  /// Scan the QR code to link this device.
  internal static let familyStatusQrBody = L10n.tr("Ui", "family status qr body", fallback: "Scan the QR code to link this device.")
  /// Add your first device now
  internal static let familyStatusReadyBody = L10n.tr("Ui", "family status ready body", fallback: "Add your first device now")
  /// App is ready!
  internal static let familyStatusReadyHeader = L10n.tr("Ui", "family status ready header", fallback: "App is ready!")
  /// Upgrade to Plus to access detailed statistics and insights.
  internal static let freemiumActivityCtaDesc = L10n.tr("Ui", "freemium activity cta desc", fallback: "Upgrade to Plus to access detailed statistics and insights.")
  /// Unlock your stats
  internal static let freemiumActivityCtaHeader = L10n.tr("Ui", "freemium activity cta header", fallback: "Unlock your stats")
  /// Upgrade your plan to enable advanced protection and extra blocklists.
  internal static let freemiumFiltersCtaDesc = L10n.tr("Ui", "freemium filters cta desc", fallback: "Upgrade your plan to enable advanced protection and extra blocklists.")
  /// Unlock advanced blocklists
  internal static let freemiumFiltersCtaHeader = L10n.tr("Ui", "freemium filters cta header", fallback: "Unlock advanced blocklists")
  /// Essential protection is active in Safari. Upgrade to unlock full coverage for all apps.
  internal static let freemiumHomeStatusDescSafari = L10n.tr("Ui", "freemium home status desc safari", fallback: "Essential protection is active in Safari. Upgrade to unlock full coverage for all apps.")
  /// Essentials
  internal static let freemiumHomeStatusHeader = L10n.tr("Ui", "freemium home status header", fallback: "Essentials")
  /// Open Safari
  internal static let freemiumSheetSafariCta = L10n.tr("Ui", "freemium sheet safari cta", fallback: "Open Safari")
  /// Enable our extension in Safari to get essential protection while you browse. It blocks annoying ads — including video ads on YouTube — so you can enjoy a cleaner, faster web experience.
  internal static let freemiumSheetSafariDesc = L10n.tr("Ui", "freemium sheet safari desc", fallback: "Enable our extension in Safari to get essential protection while you browse. It blocks annoying ads — including video ads on YouTube — so you can enjoy a cleaner, faster web experience.")
  /// Start blocking ads in Safari
  internal static let freemiumSheetSafariHeader = L10n.tr("Ui", "freemium sheet safari header", fallback: "Start blocking ads in Safari")
  /// See which trackers are reaching you - and block them.
  internal static let freemiumStatsCtaDesc = L10n.tr("Ui", "freemium stats cta desc", fallback: "See which trackers are reaching you - and block them.")
  /// Unlock full tracking control
  internal static let freemiumStatsCtaHeader = L10n.tr("Ui", "freemium stats cta header", fallback: "Unlock full tracking control")
  /// Your account has been successfully restored. Welcome back!
  internal static let genericAccountActive = L10n.tr("Ui", "generic account active", fallback: "Your account has been successfully restored. Welcome back!")
  /// Tap to activate
  internal static let homeActionTapToActivate = L10n.tr("Ui", "home action tap to activate", fallback: "Tap to activate")
  /// ads and trackers blocked since installation
  internal static let homeAdsCounterFootnote = L10n.tr("Ui", "home ads counter footnote", fallback: "ads and trackers blocked since installation")
  /// BLOKADA+ deactivated
  internal static let homePlusButtonDeactivated = L10n.tr("Ui", "home plus button deactivated", fallback: "BLOKADA+ deactivated")
  /// VPN deactivated
  internal static let homePlusButtonDeactivatedCloud = L10n.tr("Ui", "home plus button deactivated cloud", fallback: "VPN deactivated")
  /// Location: *%@*
  internal static func homePlusButtonLocation(_ p1: Any) -> String {
    return L10n.tr("Ui", "home plus button location", String(describing: p1), fallback: "Location: *%@*")
  }
  /// Select location
  internal static let homePlusButtonSelectLocation = L10n.tr("Ui", "home plus button select location", fallback: "Select location")
  /// Turn Off All Protection
  internal static let homePowerActionOffAll = L10n.tr("Ui", "home power action off all", fallback: "Turn Off All Protection")
  /// Pause for 5 min
  internal static let homePowerActionPause = L10n.tr("Ui", "home power action pause", fallback: "Pause for 5 min")
  /// Pause for 5 Minutes
  internal static let homePowerActionPauseFive = L10n.tr("Ui", "home power action pause five", fallback: "Pause for 5 Minutes")
  /// Turn off
  internal static let homePowerActionTurnOff = L10n.tr("Ui", "home power action turn off", fallback: "Turn off")
  /// Turn on
  internal static let homePowerActionTurnOn = L10n.tr("Ui", "home power action turn on", fallback: "Turn on")
  /// What would you like to do?
  internal static let homePowerOffMenuHeader = L10n.tr("Ui", "home power off menu header", fallback: "What would you like to do?")
  /// Ad Blocking is Active
  internal static let homePowerPauseStatusActive = L10n.tr("Ui", "home power pause status active", fallback: "Ad Blocking is Active")
  /// Active
  internal static let homeStatusActive = L10n.tr("Ui", "home status active", fallback: "Active")
  /// Deactivated
  internal static let homeStatusDeactivated = L10n.tr("Ui", "home status deactivated", fallback: "Deactivated")
  /// Blocking *ads* and *trackers*
  internal static let homeStatusDetailActive = L10n.tr("Ui", "home status detail active", fallback: "Blocking *ads* and *trackers*")
  /// Ads and trackers blocked last 24h
  internal static let homeStatusDetailActiveDay = L10n.tr("Ui", "home status detail active day", fallback: "Ads and trackers blocked last 24h")
  /// Blokada *Slim* is active
  internal static let homeStatusDetailActiveSlim = L10n.tr("Ui", "home status detail active slim", fallback: "Blokada *Slim* is active")
  /// Blocked *%@* ads and trackers
  internal static func homeStatusDetailActiveWithCounter(_ p1: Any) -> String {
    return L10n.tr("Ui", "home status detail active with counter", String(describing: p1), fallback: "Blocked *%@* ads and trackers")
  }
  /// Paused until timer ends
  internal static let homeStatusDetailPaused = L10n.tr("Ui", "home status detail paused", fallback: "Paused until timer ends")
  /// *+* protecting your *privacy*
  internal static let homeStatusDetailPlus = L10n.tr("Ui", "home status detail plus", fallback: "*+* protecting your *privacy*")
  /// Please wait...
  internal static let homeStatusDetailProgress = L10n.tr("Ui", "home status detail progress", fallback: "Please wait...")
  /// Paused
  internal static let homeStatusPaused = L10n.tr("Ui", "home status paused", fallback: "Paused")
  /// 'WireGuard' and the 'WireGuard' logo are registered trademarks of Jason A. Donenfeld.
  internal static let homepageVpnCredit = L10n.tr("Ui", "homepage vpn credit", fallback: "'WireGuard' and the 'WireGuard' logo are registered trademarks of Jason A. Donenfeld.")
  /// Choose a Location
  internal static let locationChoiceHeader = L10n.tr("Ui", "location choice header", fallback: "Choose a Location")
  /// America
  internal static let locationRegionAmerica = L10n.tr("Ui", "location region america", fallback: "America")
  /// Asia
  internal static let locationRegionAsia = L10n.tr("Ui", "location region asia", fallback: "Asia")
  /// Australia
  internal static let locationRegionAustralia = L10n.tr("Ui", "location region australia", fallback: "Australia")
  /// Europe
  internal static let locationRegionEurope = L10n.tr("Ui", "location region europe", fallback: "Europe")
  /// Everywhere
  internal static let locationRegionWorldwide = L10n.tr("Ui", "location region worldwide", fallback: "Everywhere")
  /// Slide to unlock
  internal static let lockActionSlideUnlock = L10n.tr("Ui", "lock action slide unlock", fallback: "Slide to unlock")
  /// Slide
  internal static let lockActionSlideUnlockShort = L10n.tr("Ui", "lock action slide unlock short", fallback: "Slide")
  /// Change pin
  internal static let lockChangePin = L10n.tr("Ui", "lock change pin", fallback: "Change pin")
  /// Enter new pin code, or wait to lock...
  internal static let lockStatusEnterOrWait = L10n.tr("Ui", "lock status enter or wait", fallback: "Enter new pin code, or wait to lock...")
  /// Enter the pin code again to confirm
  internal static let lockStatusEnterToConfirm = L10n.tr("Ui", "lock status enter to confirm", fallback: "Enter the pin code again to confirm")
  /// Blokada is locked. Enter the pin code to unlock
  internal static let lockStatusLocked = L10n.tr("Ui", "lock status locked", fallback: "Blokada is locked. Enter the pin code to unlock")
  /// Too many wrong attempts. Try again later
  internal static let lockStatusTooManyAttempts = L10n.tr("Ui", "lock status too many attempts", fallback: "Too many wrong attempts. Try again later")
  /// Set your pin code to lock Blokada
  internal static let lockStatusUnlocked = L10n.tr("Ui", "lock status unlocked", fallback: "Set your pin code to lock Blokada")
  /// Enter the pin code to change it
  internal static let lockStatusUnlockedHasPin = L10n.tr("Ui", "lock status unlocked has pin", fallback: "Enter the pin code to change it")
  /// Sure!
  internal static let mainRateUsActionSure = L10n.tr("Ui", "main rate us action sure", fallback: "Sure!")
  /// How do you like Blokada so far?
  internal static let mainRateUsDescription = L10n.tr("Ui", "main rate us description", fallback: "How do you like Blokada so far?")
  /// Rate us!
  internal static let mainRateUsHeader = L10n.tr("Ui", "main rate us header", fallback: "Rate us!")
  /// Would you help us by rating Blokada on App Store?
  internal static let mainRateUsOnAppStore = L10n.tr("Ui", "main rate us on app store", fallback: "Would you help us by rating Blokada on App Store?")
  /// Blokada helped me block %@ ads and trackers!
  internal static func mainShareMessage(_ p1: Any) -> String {
    return L10n.tr("Ui", "main share message", String(describing: p1), fallback: "Blokada helped me block %@ ads and trackers!")
  }
  /// Activity
  internal static let mainTabActivity = L10n.tr("Ui", "main tab activity", fallback: "Activity")
  /// Advanced
  internal static let mainTabAdvanced = L10n.tr("Ui", "main tab advanced", fallback: "Advanced")
  /// Home
  internal static let mainTabHome = L10n.tr("Ui", "main tab home", fallback: "Home")
  /// Settings
  internal static let mainTabSettings = L10n.tr("Ui", "main tab settings", fallback: "Settings")
  /// Please update your subscription to continue using Blokada.
  internal static let notificationAccBody = L10n.tr("Ui", "notification acc body", fallback: "Please update your subscription to continue using Blokada.")
  /// Subscription expired
  internal static let notificationAccHeader = L10n.tr("Ui", "notification acc header", fallback: "Subscription expired")
  /// Adblocking is disabled
  internal static let notificationAccSubtitle = L10n.tr("Ui", "notification acc subtitle", fallback: "Adblocking is disabled")
  /// Swipe the notification left or right for settings.
  internal static let notificationDescSettings = L10n.tr("Ui", "notification desc settings", fallback: "Swipe the notification left or right for settings.")
  /// Please open the app for details.
  internal static let notificationGenericBody = L10n.tr("Ui", "notification generic body", fallback: "Please open the app for details.")
  /// Blokada: Action required
  internal static let notificationGenericHeader = L10n.tr("Ui", "notification generic header", fallback: "Blokada: Action required")
  /// Tap to learn more
  internal static let notificationGenericSubtitle = L10n.tr("Ui", "notification generic subtitle", fallback: "Tap to learn more")
  /// Blokada Plus is off
  internal static let notificationLeaseHeader = L10n.tr("Ui", "notification lease header", fallback: "Blokada Plus is off")
  /// New message
  internal static let notificationNewMessageTitle = L10n.tr("Ui", "notification new message title", fallback: "New message")
  /// Please open the app to resume Blokada.
  internal static let notificationPauseBody = L10n.tr("Ui", "notification pause body", fallback: "Please open the app to resume Blokada.")
  /// Blokada is still paused
  internal static let notificationPauseHeader = L10n.tr("Ui", "notification pause header", fallback: "Blokada is still paused")
  /// Adblocking is disabled
  internal static let notificationPauseSubtitle = L10n.tr("Ui", "notification pause subtitle", fallback: "Adblocking is disabled")
  /// You denied notifications. To change it, please use System Preferences.
  internal static let notificationPermsDenied = L10n.tr("Ui", "notification perms denied", fallback: "You denied notifications. To change it, please use System Preferences.")
  /// This feature requires notifications, please switch them on for Blokada.
  internal static let notificationPermsDesc = L10n.tr("Ui", "notification perms desc", fallback: "This feature requires notifications, please switch them on for Blokada.")
  /// Enable notifications in Settings
  internal static let notificationPermsHeader = L10n.tr("Ui", "notification perms header", fallback: "Enable notifications in Settings")
  /// An update is available
  internal static let notificationUpdateHeader = L10n.tr("Ui", "notification update header", fallback: "An update is available")
  /// Please update your subscription to continue using BLOKADA+
  internal static let notificationVpnExpiredBody = L10n.tr("Ui", "notification vpn expired body", fallback: "Please update your subscription to continue using BLOKADA+")
  /// BLOKADA+ subscription expired
  internal static let notificationVpnExpiredHeader = L10n.tr("Ui", "notification vpn expired header", fallback: "BLOKADA+ subscription expired")
  /// The VPN is disabled
  internal static let notificationVpnExpiredSubtitle = L10n.tr("Ui", "notification vpn expired subtitle", fallback: "The VPN is disabled")
  /// Turn off these notifications
  internal static let notificationWeeklyReportActionOptOut = L10n.tr("Ui", "notification weekly report action opt out", fallback: "Turn off these notifications")
  /// See more
  internal static let notificationWeeklyReportActionSeeMore = L10n.tr("Ui", "notification weekly report action see more", fallback: "See more")
  /// Allowed traffic decreased
  internal static let notificationWeeklyReportAllowedDecreasedTitle = L10n.tr("Ui", "notification weekly report allowed decreased title", fallback: "Allowed traffic decreased")
  /// Allowed traffic increased
  internal static let notificationWeeklyReportAllowedIncreasedTitle = L10n.tr("Ui", "notification weekly report allowed increased title", fallback: "Allowed traffic increased")
  /// Domain moved down
  internal static let notificationWeeklyReportAllowedToplistDownTitle = L10n.tr("Ui", "notification weekly report allowed toplist down title", fallback: "Domain moved down")
  /// New domain in top list
  internal static let notificationWeeklyReportAllowedToplistNewTitle = L10n.tr("Ui", "notification weekly report allowed toplist new title", fallback: "New domain in top list")
  /// Domain moved up
  internal static let notificationWeeklyReportAllowedToplistUpTitle = L10n.tr("Ui", "notification weekly report allowed toplist up title", fallback: "Domain moved up")
  /// Allowed traffic is %s% compared to last week.
  internal static func notificationWeeklyReportAllowedTotalsBody(_ p1: UnsafePointer<CChar>, _ p2: CChar) -> String {
    return L10n.tr("Ui", "notification weekly report allowed totals body", p1, p2, fallback: "Allowed traffic is %s% compared to last week.")
  }
  /// Allowed traffic is %s compared to last week.
  internal static func notificationWeeklyReportAllowedTotalsBodyNopercent(_ p1: UnsafePointer<CChar>) -> String {
    return L10n.tr("Ui", "notification weekly report allowed totals body nopercent", p1, fallback: "Allowed traffic is %s compared to last week.")
  }
  /// Tracker activity decreased
  internal static let notificationWeeklyReportBlockedDecreasedTitle = L10n.tr("Ui", "notification weekly report blocked decreased title", fallback: "Tracker activity decreased")
  /// Tracker activity increased
  internal static let notificationWeeklyReportBlockedIncreasedTitle = L10n.tr("Ui", "notification weekly report blocked increased title", fallback: "Tracker activity increased")
  /// Tracker activity decreased
  internal static let notificationWeeklyReportBlockedToplistDownTitle = L10n.tr("Ui", "notification weekly report blocked toplist down title", fallback: "Tracker activity decreased")
  /// New tracker in top list
  internal static let notificationWeeklyReportBlockedToplistNewTitle = L10n.tr("Ui", "notification weekly report blocked toplist new title", fallback: "New tracker in top list")
  /// Tracker activity increased
  internal static let notificationWeeklyReportBlockedToplistUpTitle = L10n.tr("Ui", "notification weekly report blocked toplist up title", fallback: "Tracker activity increased")
  /// Blocked traffic is %s% compared to last week.
  internal static func notificationWeeklyReportBlockedTotalsBody(_ p1: UnsafePointer<CChar>, _ p2: CChar) -> String {
    return L10n.tr("Ui", "notification weekly report blocked totals body", p1, p2, fallback: "Blocked traffic is %s% compared to last week.")
  }
  /// Blocked traffic is %s compared to last week.
  internal static func notificationWeeklyReportBlockedTotalsBodyNopercent(_ p1: UnsafePointer<CChar>) -> String {
    return L10n.tr("Ui", "notification weekly report blocked totals body nopercent", p1, fallback: "Blocked traffic is %s compared to last week.")
  }
  /// Open Blokada to see your weekly report.
  internal static let notificationWeeklyReportBody = L10n.tr("Ui", "notification weekly report body", fallback: "Open Blokada to see your weekly report.")
  /// View report
  internal static let notificationWeeklyReportCta = L10n.tr("Ui", "notification weekly report cta", fallback: "View report")
  /// Weekly privacy report notifications turned off.
  internal static let notificationWeeklyReportOptOutConfirmation = L10n.tr("Ui", "notification weekly report opt out confirmation", fallback: "Weekly privacy report notifications turned off.")
  /// Open Blokada to view the latest details.
  internal static let notificationWeeklyReportRefreshedBody = L10n.tr("Ui", "notification weekly report refreshed body", fallback: "Open Blokada to view the latest details.")
  /// Your weekly report is ready
  internal static let notificationWeeklyReportRefreshedTitle = L10n.tr("Ui", "notification weekly report refreshed title", fallback: "Your weekly report is ready")
  /// Privacy Shield Report
  internal static let notificationWeeklyReportTitle = L10n.tr("Ui", "notification weekly report title", fallback: "Privacy Shield Report")
  /// %s moved to #%s (was #%s). Tap to see more.
  internal static func notificationWeeklyReportToplistMoveBody(_ p1: UnsafePointer<CChar>, _ p2: UnsafePointer<CChar>, _ p3: UnsafePointer<CChar>) -> String {
    return L10n.tr("Ui", "notification weekly report toplist move body", p1, p2, p3, fallback: "%s moved to #%s (was #%s). Tap to see more.")
  }
  /// Blokada is blocking %s — now ranked #%s. Tap to see more.
  internal static func notificationWeeklyReportToplistNewBody(_ p1: UnsafePointer<CChar>, _ p2: UnsafePointer<CChar>) -> String {
    return L10n.tr("Ui", "notification weekly report toplist new body", p1, p2, fallback: "Blokada is blocking %s — now ranked #%s. Tap to see more.")
  }
  /// Block ads and trackers everywhere with our premium app. Enjoy faster browsing, better privacy, and reduced data usage.
  internal static let onboardDesc = L10n.tr("Ui", "onboard desc", fallback: "Block ads and trackers everywhere with our premium app. Enjoy faster browsing, better privacy, and reduced data usage.")
  /// No more ads.
  /// Seriously.
  internal static let onboardHeader = L10n.tr("Ui", "onboard header", fallback: "No more ads.\nSeriously.")
  /// Enable our extension in Safari to block video ads while browsing.
  internal static let onboardSafariBrief = L10n.tr("Ui", "onboard safari brief", fallback: "Enable our extension in Safari to block video ads while browsing.")
  /// Open YouTube in Safari
  internal static let onboardSafariCta = L10n.tr("Ui", "onboard safari cta", fallback: "Open YouTube in Safari")
  /// Want to block video ads?
  internal static let onboardSafariHeader = L10n.tr("Ui", "onboard safari header", fallback: "Want to block video ads?")
  /// Skip for now
  internal static let onboardSafariSkip = L10n.tr("Ui", "onboard safari skip", fallback: "Skip for now")
  /// Manage Extensions
  internal static let onboardSafariStep2 = L10n.tr("Ui", "onboard safari step 2", fallback: "Manage Extensions")
  /// By continuing you accept our Terms of Service and acknowledge receipt of our Privacy Policy.
  internal static let onboardTerms = L10n.tr("Ui", "onboard terms", fallback: "By continuing you accept our Terms of Service and acknowledge receipt of our Privacy Policy.")
  /// GET
  internal static let packActionInstall = L10n.tr("Ui", "pack action install", fallback: "GET")
  /// REMOVE
  internal static let packActionUninstall = L10n.tr("Ui", "pack action uninstall", fallback: "REMOVE")
  /// UPDATE
  internal static let packActionUpdate = L10n.tr("Ui", "pack action update", fallback: "UPDATE")
  /// Author
  internal static let packAuthor = L10n.tr("Ui", "pack author", fallback: "Author")
  /// Active
  internal static let packCategoryActive = L10n.tr("Ui", "pack category active", fallback: "Active")
  /// All
  internal static let packCategoryAll = L10n.tr("Ui", "pack category all", fallback: "All")
  /// Highlights
  internal static let packCategoryHighlights = L10n.tr("Ui", "pack category highlights", fallback: "Highlights")
  /// Configurations
  internal static let packConfigurationsHeader = L10n.tr("Ui", "pack configurations header", fallback: "Configurations")
  /// More
  internal static let packInformationHeader = L10n.tr("Ui", "pack information header", fallback: "More")
  /// Advanced Features
  internal static let packSectionHeader = L10n.tr("Ui", "pack section header", fallback: "Advanced Features")
  /// Feature Details
  internal static let packSectionHeaderDetails = L10n.tr("Ui", "pack section header details", fallback: "Feature Details")
  /// Tags
  internal static let packTagsHeader = L10n.tr("Ui", "pack tags header", fallback: "Tags")
  /// None
  internal static let packTagsNone = L10n.tr("Ui", "pack tags none", fallback: "None")
  /// Parent
  internal static let parent = L10n.tr("Ui", "Parent", fallback: "Parent")
  /// Choose a location
  internal static let paymentActionChooseLocation = L10n.tr("Ui", "payment action choose location", fallback: "Choose a location")
  /// Compare plans
  internal static let paymentActionCompare = L10n.tr("Ui", "payment action compare", fallback: "Compare plans")
  /// Apply Offer Code
  internal static let paymentActionOffer = L10n.tr("Ui", "payment action offer", fallback: "Apply Offer Code")
  /// Pay %@
  internal static func paymentActionPay(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment action pay", String(describing: p1), fallback: "Pay %@")
  }
  /// Pay %@ each period
  internal static func paymentActionPayPeriod(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment action pay period", String(describing: p1), fallback: "Pay %@ each period")
  }
  /// Privacy Policy
  internal static let paymentActionPolicy = L10n.tr("Ui", "payment action policy", fallback: "Privacy Policy")
  /// Restore Purchases
  internal static let paymentActionRestore = L10n.tr("Ui", "payment action restore", fallback: "Restore Purchases")
  /// See All Features
  internal static let paymentActionSeeAllFeatures = L10n.tr("Ui", "payment action see all features", fallback: "See All Features")
  /// Our Locations
  internal static let paymentActionSeeLocations = L10n.tr("Ui", "payment action see locations", fallback: "Our Locations")
  /// Terms of Service
  internal static let paymentActionTerms = L10n.tr("Ui", "payment action terms", fallback: "Terms of Service")
  /// Terms & Privacy
  internal static let paymentActionTermsAndPrivacy = L10n.tr("Ui", "payment action terms and privacy", fallback: "Terms & Privacy")
  /// Blokada will now switch into Plus mode, and connect through one of our secure locations. If you are unsure which one to choose, the closest one to you is recommended.
  internal static let paymentActivatedDescription = L10n.tr("Ui", "payment activated description", fallback: "Blokada will now switch into Plus mode, and connect through one of our secure locations. If you are unsure which one to choose, the closest one to you is recommended.")
  /// A message from App Store
  internal static let paymentAlertErrorHeader = L10n.tr("Ui", "payment alert error header", fallback: "A message from App Store")
  /// The subscription is auto-renewed before the current billing period ends. You can cancel anytime in Settings.
  internal static let paymentCancelFooter = L10n.tr("Ui", "payment cancel footer", fallback: "The subscription is auto-renewed before the current billing period ends. You can cancel anytime in Settings.")
  /// Cancel during the next %@ days, and you won’t be charged.
  internal static func paymentCancelFooterTrialShort(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment cancel footer trial short", String(describing: p1), fallback: "Cancel during the next %@ days, and you won’t be charged.")
  }
  /// Change
  internal static let paymentChangeMethod = L10n.tr("Ui", "payment change method", fallback: "Change")
  /// We accept Euro, and the displayed prices are an estimate. A refund is available if your bank charges too much.
  internal static let paymentConversionNote = L10n.tr("Ui", "payment conversion note", fallback: "We accept Euro, and the displayed prices are an estimate. A refund is available if your bank charges too much.")
  /// To pay with your cryptocurrency wallet, tap the button below.
  internal static let paymentCryptoDesc = L10n.tr("Ui", "payment crypto desc", fallback: "To pay with your cryptocurrency wallet, tap the button below.")
  /// We are based in Europe, so we accept Euro: €10 is roughly $12.
  internal static let paymentEuroDesc = L10n.tr("Ui", "payment euro desc", fallback: "We are based in Europe, so we accept Euro: €10 is roughly $12.")
  /// Your battery life isn't going to be impacted, it might even improve when Blokada Cloud is activated.
  internal static let paymentFeatureDescBattery = L10n.tr("Ui", "payment feature desc battery", fallback: "Your battery life isn't going to be impacted, it might even improve when Blokada Cloud is activated.")
  /// Hide your IP address and pretend you are in another country. This will mask you from third-parties and help protect your identity.
  internal static let paymentFeatureDescChangeLocation = L10n.tr("Ui", "payment feature desc change location", fallback: "Hide your IP address and pretend you are in another country. This will mask you from third-parties and help protect your identity.")
  /// In addition to all the benefits of Blokada Cloud, you'll get access to our global VPN network
  internal static let paymentFeatureDescCloudVpn = L10n.tr("Ui", "payment feature desc cloud vpn", fallback: "In addition to all the benefits of Blokada Cloud, you'll get access to our global VPN network")
  /// Use the same account to share your subscription with up to 5 devices: iOS, Android, or PC.
  internal static let paymentFeatureDescDevices = L10n.tr("Ui", "payment feature desc devices", fallback: "Use the same account to share your subscription with up to 5 devices: iOS, Android, or PC.")
  /// Configure and monitor all your devices in one place. Either through our mobile app or our web app.
  internal static let paymentFeatureDescDevicesCloud = L10n.tr("Ui", "payment feature desc devices cloud", fallback: "Configure and monitor all your devices in one place. Either through our mobile app or our web app.")
  /// Data sent through our VPN tunnel is encrypted using strong algorithms in order to protect against interception by unauthorized parties.
  internal static let paymentFeatureDescEncryptData = L10n.tr("Ui", "payment feature desc encrypt data", fallback: "Data sent through our VPN tunnel is encrypted using strong algorithms in order to protect against interception by unauthorized parties.")
  /// Improve your privacy with DNS encryption. Blokada Cloud uses modern protocols to help keep your traffic private.
  internal static let paymentFeatureDescEncryptDns = L10n.tr("Ui", "payment feature desc encrypt dns", fallback: "Improve your privacy with DNS encryption. Blokada Cloud uses modern protocols to help keep your traffic private.")
  /// Great speeds up to 100Mbps with servers in various parts of the World.
  internal static let paymentFeatureDescFasterConnection = L10n.tr("Ui", "payment feature desc faster connection", fallback: "Great speeds up to 100Mbps with servers in various parts of the World.")
  /// Use the popular Blokada adblocking technology to block ads on your devices. Advanced settings are available.
  internal static let paymentFeatureDescNoAds = L10n.tr("Ui", "payment feature desc no ads", fallback: "Use the popular Blokada adblocking technology to block ads on your devices. Advanced settings are available.")
  /// Keep your device snappy and your Internet connection at max speeds, thanks to our new Cloud solution.
  internal static let paymentFeatureDescPerformance = L10n.tr("Ui", "payment feature desc performance", fallback: "Keep your device snappy and your Internet connection at max speeds, thanks to our new Cloud solution.")
  /// Get a prompt response to any questions thanks to our Customer Support and vibrant open source community.
  internal static let paymentFeatureDescSupport = L10n.tr("Ui", "payment feature desc support", fallback: "Get a prompt response to any questions thanks to our Customer Support and vibrant open source community.")
  /// Zero Battery Impact
  internal static let paymentFeatureTitleBattery = L10n.tr("Ui", "payment feature title battery", fallback: "Zero Battery Impact")
  /// Change Location
  internal static let paymentFeatureTitleChangeLocation = L10n.tr("Ui", "payment feature title change location", fallback: "Change Location")
  /// The Cloud plus VPN
  internal static let paymentFeatureTitleCloudVpn = L10n.tr("Ui", "payment feature title cloud vpn", fallback: "The Cloud plus VPN")
  /// Up to 5 devices
  internal static let paymentFeatureTitleDevices = L10n.tr("Ui", "payment feature title devices", fallback: "Up to 5 devices")
  /// Multiple Devices
  internal static let paymentFeatureTitleDevicesCloud = L10n.tr("Ui", "payment feature title devices cloud", fallback: "Multiple Devices")
  /// Encrypt Data
  internal static let paymentFeatureTitleEncryptData = L10n.tr("Ui", "payment feature title encrypt data", fallback: "Encrypt Data")
  /// Encrypt DNS
  internal static let paymentFeatureTitleEncryptDns = L10n.tr("Ui", "payment feature title encrypt dns", fallback: "Encrypt DNS")
  /// Faster Connection
  internal static let paymentFeatureTitleFasterConnection = L10n.tr("Ui", "payment feature title faster connection", fallback: "Faster Connection")
  /// Block Ads
  internal static let paymentFeatureTitleNoAds = L10n.tr("Ui", "payment feature title no ads", fallback: "Block Ads")
  /// Great Performance
  internal static let paymentFeatureTitlePerformance = L10n.tr("Ui", "payment feature title performance", fallback: "Great Performance")
  /// Great Support
  internal static let paymentFeatureTitleSupport = L10n.tr("Ui", "payment feature title support", fallback: "Great Support")
  /// Activated!
  internal static let paymentHeaderActivated = L10n.tr("Ui", "payment header activated", fallback: "Activated!")
  /// Cheapest
  internal static let paymentLabelCheapest = L10n.tr("Ui", "payment label cheapest", fallback: "Cheapest")
  /// Choose your package
  internal static let paymentLabelChoosePackage = L10n.tr("Ui", "payment label choose package", fallback: "Choose your package")
  /// Choose your payment method
  internal static let paymentLabelChoosePaymentMethod = L10n.tr("Ui", "payment label choose payment method", fallback: "Choose your payment method")
  /// Country
  internal static let paymentLabelCountry = L10n.tr("Ui", "payment label country", fallback: "Country")
  /// Save %@ (%@ / mo)
  internal static func paymentLabelDiscount(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "payment label discount", String(describing: p1), String(describing: p2), fallback: "Save %@ (%@ / mo)")
  }
  /// Email
  internal static let paymentLabelEmail = L10n.tr("Ui", "payment label email", fallback: "Email")
  /// Most popular
  internal static let paymentLabelMostPopular = L10n.tr("Ui", "payment label most popular", fallback: "Most popular")
  /// Pay with card
  internal static let paymentLabelPayWithCard = L10n.tr("Ui", "payment label pay with card", fallback: "Pay with card")
  /// Pay with crypto
  internal static let paymentLabelPayWithCrypto = L10n.tr("Ui", "payment label pay with crypto", fallback: "Pay with crypto")
  /// Pay with PayPal
  internal static let paymentLabelPayWithPaypal = L10n.tr("Ui", "payment label pay with paypal", fallback: "Pay with PayPal")
  /// Credit card payments should not take more than a few minutes. Cryptocurrency payments usually take up to an hour, depending on what transaction fee you chose. In case of PayPal, it may take up to 24 hours. You will get redirected once your account is ready. You may also close this screen, and come again later. If you feel like your transaction is taking too long, please contact us.
  internal static let paymentOngoingDesc = L10n.tr("Ui", "payment ongoing desc", fallback: "Credit card payments should not take more than a few minutes. Cryptocurrency payments usually take up to an hour, depending on what transaction fee you chose. In case of PayPal, it may take up to 24 hours. You will get redirected once your account is ready. You may also close this screen, and come again later. If you feel like your transaction is taking too long, please contact us.")
  /// Your payment is now being processed.
  internal static let paymentOngoingTitle = L10n.tr("Ui", "payment ongoing title", fallback: "Your payment is now being processed.")
  /// 1 Month
  internal static let paymentPackageOneMonth = L10n.tr("Ui", "payment package one month", fallback: "1 Month")
  /// 6 Months
  internal static let paymentPackageSixMonths = L10n.tr("Ui", "payment package six months", fallback: "6 Months")
  /// 12 Months
  internal static let paymentPackageTwelveMonths = L10n.tr("Ui", "payment package twelve months", fallback: "12 Months")
  /// Apple Pay
  internal static let paymentPayAppleShort = L10n.tr("Ui", "payment pay apple short", fallback: "Apple Pay")
  /// Google Pay
  internal static let paymentPayGoogleShort = L10n.tr("Ui", "payment pay google short", fallback: "Google Pay")
  /// Subscribe Annually
  internal static let paymentPlanCtaAnnual = L10n.tr("Ui", "payment plan cta annual", fallback: "Subscribe Annually")
  /// Subscribe Monthly
  internal static let paymentPlanCtaMonthly = L10n.tr("Ui", "payment plan cta monthly", fallback: "Subscribe Monthly")
  /// Start 7-Day Free Trial
  internal static let paymentPlanCtaTrial = L10n.tr("Ui", "payment plan cta trial", fallback: "Start 7-Day Free Trial")
  /// Start %@-Day Free Trial
  internal static func paymentPlanCtaTrialLength(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment plan cta trial length", String(describing: p1), fallback: "Start %@-Day Free Trial")
  }
  /// (current plan)
  internal static let paymentPlanCurrent = L10n.tr("Ui", "payment plan current", fallback: "(current plan)")
  /// Blocks ads and trackers
  internal static let paymentPlanSluglineCloud = L10n.tr("Ui", "payment plan slugline cloud", fallback: "Blocks ads and trackers")
  /// (includes Blokada Cloud)
  internal static let paymentPlanSluglineCloudDetail = L10n.tr("Ui", "payment plan slugline cloud detail", fallback: "(includes Blokada Cloud)")
  /// Additional protection with VPN
  internal static let paymentPlanSluglinePlus = L10n.tr("Ui", "payment plan slugline plus", fallback: "Additional protection with VPN")
  /// Please wait. This should only take a moment.
  internal static let paymentRedirectDesc = L10n.tr("Ui", "payment redirect desc", fallback: "Please wait. This should only take a moment.")
  /// Redirecting...
  internal static let paymentRedirectLabel = L10n.tr("Ui", "payment redirect label", fallback: "Redirecting...")
  /// You are saving %@
  internal static func paymentSaveText(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment save text", String(describing: p1), fallback: "You are saving %@")
  }
  /// 1 Month
  internal static let paymentSubscription1Month = L10n.tr("Ui", "payment subscription 1 month", fallback: "1 Month")
  /// %@ Months
  internal static func paymentSubscriptionManyMonths(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment subscription many months", String(describing: p1), fallback: "%@ Months")
  }
  /// Save %@
  internal static func paymentSubscriptionOffer(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment subscription offer", String(describing: p1), fallback: "Save %@")
  }
  /// %@ per month
  internal static func paymentSubscriptionPerMonth(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment subscription per month", String(describing: p1), fallback: "%@ per month")
  }
  /// %@ per year
  internal static func paymentSubscriptionPerYear(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment subscription per year", String(describing: p1), fallback: "%@ per year")
  }
  /// then %@ per year
  internal static func paymentSubscriptionPerYearThen(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment subscription per year then", String(describing: p1), fallback: "then %@ per year")
  }
  /// Your account is now active! You may now use all Blokada Plus features on all your devices.
  internal static let paymentSuccessDesc = L10n.tr("Ui", "payment success desc", fallback: "Your account is now active! You may now use all Blokada Plus features on all your devices.")
  /// Thanks!
  internal static let paymentSuccessLabel = L10n.tr("Ui", "payment success label", fallback: "Thanks!")
  /// Upgrade to our VPN service to stay in control of *your privacy*.
  internal static let paymentTitle = L10n.tr("Ui", "payment title", fallback: "Upgrade to our VPN service to stay in control of *your privacy*.")
  /// Pay after %@ days. Subscription auto-renews every year until canceled.
  internal static func paymentTrialBrief(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment trial brief", String(describing: p1), fallback: "Pay after %@ days. Subscription auto-renews every year until canceled.")
  }
  /// See recent activity and the protection status of this device.
  internal static let privacyPulseBrief = L10n.tr("Ui", "privacy pulse brief", fallback: "See recent activity and the protection status of this device.")
  /// Nothing to show yet
  internal static let privacyPulseEmpty = L10n.tr("Ui", "privacy pulse empty", fallback: "Nothing to show yet")
  /// Recent Activity
  internal static let privacyPulseRecentsHeader = L10n.tr("Ui", "privacy pulse recents header", fallback: "Recent Activity")
  /// Privacy Pulse
  internal static let privacyPulseSectionHeader = L10n.tr("Ui", "privacy pulse section header", fallback: "Privacy Pulse")
  /// Allowed
  internal static let privacyPulseTabAllowed = L10n.tr("Ui", "privacy pulse tab allowed", fallback: "Allowed")
  /// Blocked
  internal static let privacyPulseTabBlocked = L10n.tr("Ui", "privacy pulse tab blocked", fallback: "Blocked")
  /// Last 24 h
  internal static let privacyPulseTimespan24h = L10n.tr("Ui", "privacy pulse timespan 24h", fallback: "Last 24 h")
  /// See All
  internal static let privacyPulseTimespanShowAll = L10n.tr("Ui", "privacy pulse timespan show all", fallback: "See All")
  /// Top domains
  internal static let privacyPulseToplistsHeader = L10n.tr("Ui", "privacy pulse toplists header", fallback: "Top domains")
  /// Note: Native app for Android does not support Blokada Cloud yet. We are working on the update.
  internal static let setupCommentNativeApps = L10n.tr("Ui", "setup comment native apps", fallback: "Note: Native app for Android does not support Blokada Cloud yet. We are working on the update.")
  /// Note: The VPN configuration will use Blokada Cloud by default. Choose a different DNS setting if you wish to opt out. 'WireGuard' and the 'WireGuard' logo are registered trademarks of Jason A. Donenfeld.
  internal static let setupCommentWireguard = L10n.tr("Ui", "setup comment wireguard", fallback: "Note: The VPN configuration will use Blokada Cloud by default. Choose a different DNS setting if you wish to opt out. 'WireGuard' and the 'WireGuard' logo are registered trademarks of Jason A. Donenfeld.")
  /// There are many ways to configure your device to use Blokada Cloud. Choose the one that works for you.
  internal static let setupDesc = L10n.tr("Ui", "setup desc", fallback: "There are many ways to configure your device to use Blokada Cloud. Choose the one that works for you.")
  /// Setup
  internal static let setupHeader = L10n.tr("Ui", "setup header", fallback: "Setup")
  /// Choose any of the following setup options:
  internal static let setupLabelChoose = L10n.tr("Ui", "setup label choose", fallback: "Choose any of the following setup options:")
  /// What type of device you wish to set up?
  internal static let setupLabelWhichDevice = L10n.tr("Ui", "setup label which device", fallback: "What type of device you wish to set up?")
  /// (unnamed)
  internal static let setupNameLabelUnnamed = L10n.tr("Ui", "setup name label unnamed", fallback: "(unnamed)")
  /// Alternative: %@
  internal static func setupOptionLabelAlternative(_ p1: Any) -> String {
    return L10n.tr("Ui", "setup option label alternative", String(describing: p1), fallback: "Alternative: %@")
  }
  /// Recommended: %@
  internal static func setupOptionLabelRecommended(_ p1: Any) -> String {
    return L10n.tr("Ui", "setup option label recommended", String(describing: p1), fallback: "Recommended: %@")
  }
  /// Step %@: %@
  internal static func setupStep(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "setup step", String(describing: p1), String(describing: p2), fallback: "Step %@: %@")
  }
  /// Apply the new configuration
  internal static let setupStepApplyConfig = L10n.tr("Ui", "setup step apply config", fallback: "Apply the new configuration")
  /// Copy your hostname
  internal static let setupStepCopy = L10n.tr("Ui", "setup step copy", fallback: "Copy your hostname")
  /// Generate and download your profile
  internal static let setupStepDownloadProfile = L10n.tr("Ui", "setup step download profile", fallback: "Generate and download your profile")
  /// When asked, enter your tag
  internal static let setupStepEnterTag = L10n.tr("Ui", "setup step enter tag", fallback: "When asked, enter your tag")
  /// Install and start our app
  internal static let setupStepInstall = L10n.tr("Ui", "setup step install", fallback: "Install and start our app")
  /// Install and start WireGuard
  internal static let setupStepInstallWireguard = L10n.tr("Ui", "setup step install wireguard", fallback: "Install and start WireGuard")
  /// Name your device (optional)
  internal static let setupStepName = L10n.tr("Ui", "setup step name", fallback: "Name your device (optional)")
  /// Shields
  internal static let shieldsSectionHeader = L10n.tr("Ui", "shields section header", fallback: "Shields")
  /// Stats
  internal static let statsHeader = L10n.tr("Ui", "stats header", fallback: "Stats")
  /// All time
  internal static let statsHeaderAllTime = L10n.tr("Ui", "stats header all time", fallback: "All time")
  /// Last 24h
  internal static let statsHeaderDay = L10n.tr("Ui", "stats header day", fallback: "Last 24h")
  /// Allowed
  internal static let statsLabelAllowed = L10n.tr("Ui", "stats label allowed", fallback: "Allowed")
  /// Blocked
  internal static let statsLabelBlocked = L10n.tr("Ui", "stats label blocked", fallback: "Blocked")
  /// Total
  internal static let statsLabelTotal = L10n.tr("Ui", "stats label total", fallback: "Total")
  /// Ratio
  internal static let statsRatioHeader = L10n.tr("Ui", "stats ratio header", fallback: "Ratio")
  /// Requests
  internal static let statsRequestsHeader = L10n.tr("Ui", "stats requests header", fallback: "Requests")
  /// Queries over time
  internal static let statsRequestsSubheader = L10n.tr("Ui", "stats requests subheader", fallback: "Queries over time")
  /// Top allowed requests
  internal static let statsTopAllowedHeader = L10n.tr("Ui", "stats top allowed header", fallback: "Top allowed requests")
  /// Top blocked requests
  internal static let statsTopBlockedHeader = L10n.tr("Ui", "stats top blocked header", fallback: "Top blocked requests")
  /// Chat with us
  internal static let supportActionChat = L10n.tr("Ui", "support action chat", fallback: "Chat with us")
  /// End
  internal static let supportActionEnd = L10n.tr("Ui", "support action end", fallback: "End")
  /// Sorry did not understand, can you repeat?
  internal static let supportErrorGeneric = L10n.tr("Ui", "support error generic", fallback: "Sorry did not understand, can you repeat?")
  /// Blocka Bot
  internal static let supportNameBot = L10n.tr("Ui", "support name bot", fallback: "Blocka Bot")
  /// Ask about anything you want to know!
  internal static let supportPlaceholder = L10n.tr("Ui", "support placeholder", fallback: "Ask about anything you want to know!")
  /// Other
  internal static let toplistCompanyOther = L10n.tr("Ui", "toplist company other", fallback: "Other")
  /// unknown
  internal static let toplistTldUnknown = L10n.tr("Ui", "toplist tld unknown", fallback: "unknown")
  /// Add
  internal static let universalActionAdd = L10n.tr("Ui", "universal action add", fallback: "Add")
  /// Cancel
  internal static let universalActionCancel = L10n.tr("Ui", "universal action cancel", fallback: "Cancel")
  /// Clear
  internal static let universalActionClear = L10n.tr("Ui", "universal action clear", fallback: "Clear")
  /// Close
  internal static let universalActionClose = L10n.tr("Ui", "universal action close", fallback: "Close")
  /// Community
  internal static let universalActionCommunity = L10n.tr("Ui", "universal action community", fallback: "Community")
  /// Contact us
  internal static let universalActionContactUs = L10n.tr("Ui", "universal action contact us", fallback: "Contact us")
  /// Continue
  internal static let universalActionContinue = L10n.tr("Ui", "universal action continue", fallback: "Continue")
  /// Copy
  internal static let universalActionCopy = L10n.tr("Ui", "universal action copy", fallback: "Copy")
  /// Delete
  internal static let universalActionDelete = L10n.tr("Ui", "universal action delete", fallback: "Delete")
  /// Disable
  internal static let universalActionDisable = L10n.tr("Ui", "universal action disable", fallback: "Disable")
  /// Donate
  internal static let universalActionDonate = L10n.tr("Ui", "universal action donate", fallback: "Donate")
  /// Done
  internal static let universalActionDone = L10n.tr("Ui", "universal action done", fallback: "Done")
  /// Download
  internal static let universalActionDownload = L10n.tr("Ui", "universal action download", fallback: "Download")
  /// Edit
  internal static let universalActionEdit = L10n.tr("Ui", "universal action edit", fallback: "Edit")
  /// Filter
  internal static let universalActionFilter = L10n.tr("Ui", "universal action filter", fallback: "Filter")
  /// Help
  internal static let universalActionHelp = L10n.tr("Ui", "universal action help", fallback: "Help")
  /// Hide
  internal static let universalActionHide = L10n.tr("Ui", "universal action hide", fallback: "Hide")
  /// Learn more
  internal static let universalActionLearnMore = L10n.tr("Ui", "universal action learn more", fallback: "Learn more")
  /// More
  internal static let universalActionMore = L10n.tr("Ui", "universal action more", fallback: "More")
  /// News
  internal static let universalActionNews = L10n.tr("Ui", "universal action news", fallback: "News")
  /// No
  internal static let universalActionNo = L10n.tr("Ui", "universal action no", fallback: "No")
  /// Open in browser
  internal static let universalActionOpenInBrowser = L10n.tr("Ui", "universal action open in browser", fallback: "Open in browser")
  /// Revoke
  internal static let universalActionRevoke = L10n.tr("Ui", "universal action revoke", fallback: "Revoke")
  /// Save
  internal static let universalActionSave = L10n.tr("Ui", "universal action save", fallback: "Save")
  /// Search
  internal static let universalActionSearch = L10n.tr("Ui", "universal action search", fallback: "Search")
  /// Select
  internal static let universalActionSelect = L10n.tr("Ui", "universal action select", fallback: "Select")
  /// Selected
  internal static let universalActionSelected = L10n.tr("Ui", "universal action selected", fallback: "Selected")
  /// Share log
  internal static let universalActionShareLog = L10n.tr("Ui", "universal action share log", fallback: "Share log")
  /// Logs
  internal static let universalActionShowLog = L10n.tr("Ui", "universal action show log", fallback: "Logs")
  /// Support
  internal static let universalActionSupport = L10n.tr("Ui", "universal action support", fallback: "Support")
  /// Try again
  internal static let universalActionTryAgain = L10n.tr("Ui", "universal action try again", fallback: "Try again")
  /// Upgrade to BLOKADA+
  internal static let universalActionUpgrade = L10n.tr("Ui", "universal action upgrade", fallback: "Upgrade to BLOKADA+")
  /// Upgrade
  internal static let universalActionUpgradeShort = L10n.tr("Ui", "universal action upgrade short", fallback: "Upgrade")
  /// Yes
  internal static let universalActionYes = L10n.tr("Ui", "universal action yes", fallback: "Yes")
  /// Count
  internal static let universalLabelCount = L10n.tr("Ui", "universal label count", fallback: "Count")
  /// Device
  internal static let universalLabelDevice = L10n.tr("Ui", "universal label device", fallback: "Device")
  /// Help
  internal static let universalLabelHelp = L10n.tr("Ui", "universal label help", fallback: "Help")
  /// Name
  internal static let universalLabelName = L10n.tr("Ui", "universal label name", fallback: "Name")
  /// None
  internal static let universalLabelNone = L10n.tr("Ui", "universal label none", fallback: "None")
  /// Time
  internal static let universalLabelTime = L10n.tr("Ui", "universal label time", fallback: "Time")
  /// Type
  internal static let universalLabelType = L10n.tr("Ui", "universal label type", fallback: "Type")
  /// Welcome!
  internal static let universalLabelWelcome = L10n.tr("Ui", "universal label welcome", fallback: "Welcome!")
  /// Are you sure you want to proceed?
  internal static let universalStatusConfirm = L10n.tr("Ui", "universal status confirm", fallback: "Are you sure you want to proceed?")
  /// Copied to Clipboard
  internal static let universalStatusCopiedToClipboard = L10n.tr("Ui", "universal status copied to clipboard", fallback: "Copied to Clipboard")
  /// Loading...
  internal static let universalStatusLoading = L10n.tr("Ui", "universal status loading", fallback: "Loading...")
  /// Processing... Please wait.
  internal static let universalStatusProcessing = L10n.tr("Ui", "universal status processing", fallback: "Processing... Please wait.")
  /// Continue with the Blokada App
  internal static let universalStatusRedirect = L10n.tr("Ui", "universal status redirect", fallback: "Continue with the Blokada App")
  /// Please restart the app for the changes to take effect.
  internal static let universalStatusRestartRequired = L10n.tr("Ui", "universal status restart required", fallback: "Please restart the app for the changes to take effect.")
  /// Waiting for data
  internal static let universalStatusWaitingForData = L10n.tr("Ui", "universal status waiting for data", fallback: "Waiting for data")
  /// You are now using the newest version of Blokada! Remember, donating or subscribing to Blokada Plus allows us to continue improving the app.
  internal static let updateDescUpdated = L10n.tr("Ui", "update desc updated", fallback: "You are now using the newest version of Blokada! Remember, donating or subscribing to Blokada Plus allows us to continue improving the app.")
  /// You are now using the newest version of Blokada!
  internal static let updateDescUpdatedNodon = L10n.tr("Ui", "update desc updated nodon", fallback: "You are now using the newest version of Blokada!")
  /// The update is now downloading, and you should see the installation prompt shortly.
  internal static let updateDownloadingDescription = L10n.tr("Ui", "update downloading description", fallback: "The update is now downloading, and you should see the installation prompt shortly.")
  /// Updated!
  internal static let updateLabelUpdated = L10n.tr("Ui", "update label updated", fallback: "Updated!")
  /// Open Exceptions
  internal static let userdefinedActionOpen = L10n.tr("Ui", "userdefined action open", fallback: "Open Exceptions")
  /// Allow
  internal static let userdeniedActionAllow = L10n.tr("Ui", "userdenied action allow", fallback: "Allow")
  /// Block
  internal static let userdeniedActionBlock = L10n.tr("Ui", "userdenied action block", fallback: "Block")
  /// Exceptions
  internal static let userdeniedSectionHeader = L10n.tr("Ui", "userdenied section header", fallback: "Exceptions")
  /// Manage blocking of particular websites
  internal static let userdeniedSectionSlugline = L10n.tr("Ui", "userdenied section slugline", fallback: "Manage blocking of particular websites")
  /// Allowed
  internal static let userdeniedTabAllowed = L10n.tr("Ui", "userdenied tab allowed", fallback: "Allowed")
  /// Blocked
  internal static let userdeniedTabBlocked = L10n.tr("Ui", "userdenied tab blocked", fallback: "Blocked")
  /// Generate
  internal static let webActionGenerate = L10n.tr("Ui", "web action generate", fallback: "Generate")
  /// Open setup
  internal static let webActionOpenSetup = L10n.tr("Ui", "web action open setup", fallback: "Open setup")
  /// Your Libre account gives you free adblocking on your device with our open source apps. Upgrade to Blokada Plus for an even better protection. You'll get access to our global VPN-network as well as our new *cloud based* adblocking that is more efficient and easier to use.
  internal static let webCtaPlusDesc = L10n.tr("Ui", "web cta plus desc", fallback: "Your Libre account gives you free adblocking on your device with our open source apps. Upgrade to Blokada Plus for an even better protection. You'll get access to our global VPN-network as well as our new *cloud based* adblocking that is more efficient and easier to use.")
  /// Upgrade to Blokada Plus to stay in control of your privacy.
  internal static let webCtaPlusHeader = L10n.tr("Ui", "web cta plus header", fallback: "Upgrade to Blokada Plus to stay in control of your privacy.")
  /// VPN Devices
  internal static let webVpnDevicesHeader = L10n.tr("Ui", "web vpn devices header", fallback: "VPN Devices")
  /// Open VPN Devices
  internal static let webVpnDevicesOpenAction = L10n.tr("Ui", "web vpn devices open action", fallback: "Open VPN Devices")
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
