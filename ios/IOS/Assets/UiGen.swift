// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  /// About
  internal static let accountActionAbout = L10n.tr("Ui", "account action about")
  /// Generate new account
  internal static let accountActionCreate = L10n.tr("Ui", "account action create")
  /// Devices
  internal static let accountActionDevices = L10n.tr("Ui", "account action devices")
  /// Encryption & DNS
  internal static let accountActionEncryption = L10n.tr("Ui", "account action encryption")
  /// How do I restore my old account?
  internal static let accountActionHowToRestore = L10n.tr("Ui", "account action how to restore")
  /// Inbox
  internal static let accountActionInbox = L10n.tr("Ui", "account action inbox")
  /// Restore purchase
  internal static let accountActionLogout = L10n.tr("Ui", "account action logout")
  /// Log out
  internal static let accountActionLogoutOnly = L10n.tr("Ui", "account action logout only")
  /// Manage subscription
  internal static let accountActionManageSubscription = L10n.tr("Ui", "account action manage subscription")
  /// My account
  internal static let accountActionMyAccount = L10n.tr("Ui", "account action my account")
  /// New device
  internal static let accountActionNewDevice = L10n.tr("Ui", "account action new device")
  /// Restoring account: %@
  internal static func accountActionRestoring(_ p1: Any) -> String {
    return L10n.tr("Ui", "account action restoring", String(describing: p1))
  }
  /// Tap to show
  internal static let accountActionTapToShow = L10n.tr("Ui", "account action tap to show")
  /// Why should I upgrade?
  internal static let accountActionWhyUpgrade = L10n.tr("Ui", "account action why upgrade")
  /// Forever
  internal static let accountActiveForever = L10n.tr("Ui", "account active forever")
  /// Active forever
  internal static let accountActiveForeverFull = L10n.tr("Ui", "account active forever full")
  /// I wrote it down
  internal static let accountCreateConfirm = L10n.tr("Ui", "account create confirm")
  /// This is your account ID. Write it down and keep it private. It’s the only way to access your subscription.
  internal static let accountCreateDescription = L10n.tr("Ui", "account create description")
  /// Not available
  internal static let accountDevicesNotAvailable = L10n.tr("Ui", "account devices not available")
  /// %@ out of %@
  internal static func accountDevicesOutOf(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "account devices out of", String(describing: p1), String(describing: p2))
  }
  /// Devices remaining: %@
  internal static func accountDevicesRemaining(_ p1: Any) -> String {
    return L10n.tr("Ui", "account devices remaining", String(describing: p1))
  }
  /// Turn on BLOKADA
  internal static let accountEncryptActionTurnOn = L10n.tr("Ui", "account encrypt action turn on")
  /// What is DNS?
  internal static let accountEncryptActionWhatIsDns = L10n.tr("Ui", "account encrypt action what is dns")
  /// Domain Name System is how your device knows where to find the websites you want to visit. Unfortunately, most of  the Internet still uses unencrypted DNS, which puts your browsing history at risk of being spied on. When enabled, Blokada is forcing your device to connect only to encrypted DNS servers (also called DNS over HTTPS).
  internal static let accountEncryptDescDnsOnly = L10n.tr("Ui", "account encrypt desc dns only")
  /// Your device is connecting through our secure VPN servers, and all communication coming from, or to, your device is being encrypted using strong algorithms. This protects your personal information, like banking details or personal photos, from being stolen in unsecure places, like a coffee shop WiFi.
  internal static let accountEncryptDescEverything = L10n.tr("Ui", "account encrypt desc everything")
  /// DNS is how your device knows where to find websites. BLOKADA supports only encrypted servers.
  internal static let accountEncryptHeaderExplanation = L10n.tr("Ui", "account encrypt header explanation")
  /// Encryption Level
  internal static let accountEncryptHeaderLevel = L10n.tr("Ui", "account encrypt header level")
  /// DNS
  internal static let accountEncryptLabelDns = L10n.tr("Ui", "account encrypt label dns")
  /// Encrypting DNS
  internal static let accountEncryptLabelDnsOnly = L10n.tr("Ui", "account encrypt label dns only")
  /// Connecting through VPN
  internal static let accountEncryptLabelEverything = L10n.tr("Ui", "account encrypt label everything")
  /// Level
  internal static let accountEncryptLabelLevel = L10n.tr("Ui", "account encrypt label level")
  /// High: Encrypting Everything
  internal static let accountEncryptLabelLevelHigh = L10n.tr("Ui", "account encrypt label level high")
  /// Low: No Encryption
  internal static let accountEncryptLabelLevelLow = L10n.tr("Ui", "account encrypt label level low")
  /// Medium: Encrypting DNS
  internal static let accountEncryptLabelLevelMedium = L10n.tr("Ui", "account encrypt label level medium")
  /// Use Blokada DNS in Plus mode
  internal static let accountEncryptLabelUseBlockaDns = L10n.tr("Ui", "account encrypt label use blocka dns")
  /// High
  internal static let accountEncryptLevelHigh = L10n.tr("Ui", "account encrypt level high")
  /// Low
  internal static let accountEncryptLevelLow = L10n.tr("Ui", "account encrypt level low")
  /// Medium
  internal static let accountEncryptLevelMedium = L10n.tr("Ui", "account encrypt level medium")
  /// Blokada DNS
  internal static let accountEncryptSectionBlockaDns = L10n.tr("Ui", "account encrypt section blocka dns")
  /// Encryption
  internal static let accountEncryptSectionHeader = L10n.tr("Ui", "account encrypt section header")
  /// Restore purchase
  internal static let accountHeaderLogout = L10n.tr("Ui", "account header logout")
  /// (unchanged)
  internal static let accountIdStatusUnchanged = L10n.tr("Ui", "account id status unchanged")
  /// Active until
  internal static let accountLabelActiveUntil = L10n.tr("Ui", "account label active until")
  /// Enter your account ID to continue
  internal static let accountLabelEnterToContinue = L10n.tr("Ui", "account label enter to continue")
  /// Account ID
  internal static let accountLabelId = L10n.tr("Ui", "account label id")
  /// Account type
  internal static let accountLabelType = L10n.tr("Ui", "account label type")
  /// Choose a DNS
  internal static let accountLeaseActionDns = L10n.tr("Ui", "account lease action dns")
  /// Download Config
  internal static let accountLeaseActionDownload = L10n.tr("Ui", "account lease action download")
  /// Generate Config
  internal static let accountLeaseActionGenerate = L10n.tr("Ui", "account lease action generate")
  /// Device added! Download the configuration to use it on any device supported by WireGuard.
  internal static let accountLeaseGenerated = L10n.tr("Ui", "account lease generated")
  /// Devices
  internal static let accountLeaseLabelDevices = L10n.tr("Ui", "account lease label devices")
  /// These devices are connected to your account.
  internal static let accountLeaseLabelDevicesList = L10n.tr("Ui", "account lease label devices list")
  /// DNS
  internal static let accountLeaseLabelDns = L10n.tr("Ui", "account lease label dns")
  /// Selecting a location here will generate a config file that you can use in any VPN app that supports WireGuard. This is useful for platforms where we don't have our apps yet. Otherwise, we recommend using our native apps instead.
  internal static let accountLeaseLabelGenerate = L10n.tr("Ui", "account lease label generate")
  /// Location
  internal static let accountLeaseLabelLocation = L10n.tr("Ui", "account lease label location")
  /// Name of device
  internal static let accountLeaseLabelName = L10n.tr("Ui", "account lease label name")
  /// Public Key
  internal static let accountLeaseLabelPublicKey = L10n.tr("Ui", "account lease label public key")
  ///  (this device)
  internal static let accountLeaseLabelThisDevice = L10n.tr("Ui", "account lease label this device")
  /// Blokada uses WireGuard. Configurations can be downloaded when creating new devices.
  internal static let accountLeaseWireguardDesc = L10n.tr("Ui", "account lease wireguard desc")
  /// Please enter another account ID, or go back to keep using your existing account (this app cannot be used without one).
  internal static let accountLogoutDescription = L10n.tr("Ui", "account logout description")
  /// Don't worry, if you lost or forgot your account ID, we can recover it. Please contact our support, and provide us information that will allow us to identify your purchase (eg. last 4 digits of your credit card, or PayPal email).
  internal static let accountRestoreDescription = L10n.tr("Ui", "account restore description")
  /// General
  internal static let accountSectionHeaderGeneral = L10n.tr("Ui", "account section header general")
  /// My Subscription
  internal static let accountSectionHeaderMySubscription = L10n.tr("Ui", "account section header my subscription")
  /// Other
  internal static let accountSectionHeaderOther = L10n.tr("Ui", "account section header other")
  /// Primary
  internal static let accountSectionHeaderPrimary = L10n.tr("Ui", "account section header primary")
  /// Settings
  internal static let accountSectionHeaderSettings = L10n.tr("Ui", "account section header settings")
  /// Subscription
  internal static let accountSectionHeaderSubscription = L10n.tr("Ui", "account section header subscription")
  /// Your BLOKADA %@ account is active until %@.
  internal static func accountStatusText(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "account status text", String(describing: p1), String(describing: p2))
  }
  /// Your BLOKADA account is inactive.
  internal static let accountStatusTextInactive = L10n.tr("Ui", "account status text inactive")
  /// Your BLOKADA Libre account is active until forever.
  internal static let accountStatusTextLibre = L10n.tr("Ui", "account status text libre")
  /// Days remaining: %@
  internal static func accountSubscriptionDaysRemaining(_ p1: Any) -> String {
    return L10n.tr("Ui", "account subscription days remaining", String(describing: p1))
  }
  /// Payment method
  internal static let accountSubscriptionHeaderPaymentMethod = L10n.tr("Ui", "account subscription header payment method")
  /// Renew automatically
  internal static let accountSubscriptionHeaderRenew = L10n.tr("Ui", "account subscription header renew")
  /// Your payment method does not allow to control the auto renewal setting here.
  internal static let accountSubscriptionRenewUnsupported = L10n.tr("Ui", "account subscription renew unsupported")
  /// How can we help you?
  internal static let accountSupportActionHowHelp = L10n.tr("Ui", "account support action how help")
  /// Open Knowledge Base
  internal static let accountSupportActionKb = L10n.tr("Ui", "account support action kb")
  /// Unlock to show your account ID
  internal static let accountUnlockToShow = L10n.tr("Ui", "account unlock to show")
  /// Add to Blocked
  internal static let activityActionAddToBlacklist = L10n.tr("Ui", "activity action add to blacklist")
  /// Add to Allowed
  internal static let activityActionAddToWhitelist = L10n.tr("Ui", "activity action add to whitelist")
  /// Added to Blocked
  internal static let activityActionAddedToBlacklist = L10n.tr("Ui", "activity action added to blacklist")
  /// Added to Allowed
  internal static let activityActionAddedToWhitelist = L10n.tr("Ui", "activity action added to whitelist")
  /// Copy name to Clipboard
  internal static let activityActionCopyToClipboard = L10n.tr("Ui", "activity action copy to clipboard")
  /// Remove from Blocked
  internal static let activityActionRemoveFromBlacklist = L10n.tr("Ui", "activity action remove from blacklist")
  /// Remove from Allowed
  internal static let activityActionRemoveFromWhitelist = L10n.tr("Ui", "activity action remove from whitelist")
  /// Actions
  internal static let activityActionsHeader = L10n.tr("Ui", "activity actions header")
  /// Recent
  internal static let activityCategoryRecent = L10n.tr("Ui", "activity category recent")
  /// Top
  internal static let activityCategoryTop = L10n.tr("Ui", "activity category top")
  /// Top Allowed
  internal static let activityCategoryTopAllowed = L10n.tr("Ui", "activity category top allowed")
  /// Top Blocked
  internal static let activityCategoryTopBlocked = L10n.tr("Ui", "activity category top blocked")
  /// All devices
  internal static let activityDeviceFilterShowAll = L10n.tr("Ui", "activity device filter show all")
  /// Full name
  internal static let activityDomainName = L10n.tr("Ui", "activity domain name")
  /// Try using your device, and come back here later, to see where your device connects to.
  internal static let activityEmptyText = L10n.tr("Ui", "activity empty text")
  /// Which entries would you like to see?
  internal static let activityFilterHeader = L10n.tr("Ui", "activity filter header")
  /// All entries
  internal static let activityFilterShowAll = L10n.tr("Ui", "activity filter show all")
  /// Allowed only
  internal static let activityFilterShowAllowed = L10n.tr("Ui", "activity filter show allowed")
  /// Blocked only
  internal static let activityFilterShowBlocked = L10n.tr("Ui", "activity filter show blocked")
  /// %@ times
  internal static func activityHappenedManyTimes(_ p1: Any) -> String {
    return L10n.tr("Ui", "activity happened many times", String(describing: p1))
  }
  /// 1 time
  internal static let activityHappenedOneTime = L10n.tr("Ui", "activity happened one time")
  /// Information
  internal static let activityInformationHeader = L10n.tr("Ui", "activity information header")
  /// Number of occurrences
  internal static let activityNumberOfOccurrences = L10n.tr("Ui", "activity number of occurrences")
  /// This request has been allowed.
  internal static let activityRequestAllowed = L10n.tr("Ui", "activity request allowed")
  /// This request has been allowed, because it's present on the *%@* allowlist.
  internal static func activityRequestAllowedList(_ p1: Any) -> String {
    return L10n.tr("Ui", "activity request allowed list", String(describing: p1))
  }
  /// This request has been allowed, as it's not present on any of your configured blocklists.
  internal static let activityRequestAllowedNoList = L10n.tr("Ui", "activity request allowed no list")
  /// This request has been allowed, because it is on your Allowed list
  internal static let activityRequestAllowedWhitelisted = L10n.tr("Ui", "activity request allowed whitelisted")
  /// This request has been blocked.
  internal static let activityRequestBlocked = L10n.tr("Ui", "activity request blocked")
  /// This request has been blocked, because it is on your Blocked list
  internal static let activityRequestBlockedBlacklisted = L10n.tr("Ui", "activity request blocked blacklisted")
  /// This request has been blocked, because it's present on the *%@* blocklist.
  internal static func activityRequestBlockedList(_ p1: Any) -> String {
    return L10n.tr("Ui", "activity request blocked list", String(describing: p1))
  }
  /// This request has been blocked, as it's not present on any of your configured allowlists.
  internal static let activityRequestBlockedNoList = L10n.tr("Ui", "activity request blocked no list")
  /// Blokada Cloud is not logging anything by default. If you wish to see the aggregated stats and activity from all of your devices, choose the desired log retention period below.
  internal static let activityRetentionDesc = L10n.tr("Ui", "activity retention desc")
  /// For how long can we store your activity?
  internal static let activityRetentionHeader = L10n.tr("Ui", "activity retention header")
  /// 24 hours
  internal static let activityRetentionOption24h = L10n.tr("Ui", "activity retention option 24h")
  /// Do not store my activity
  internal static let activityRetentionOptionNone = L10n.tr("Ui", "activity retention option none")
  /// By enabling log retention you accept the privacy policy.
  internal static let activityRetentionPolicy = L10n.tr("Ui", "activity retention policy")
  /// Activity
  internal static let activitySectionHeader = L10n.tr("Ui", "activity section header")
  /// Activity Details
  internal static let activitySectionHeaderDetails = L10n.tr("Ui", "activity section header details")
  /// allowed
  internal static let activityStateAllowed = L10n.tr("Ui", "activity state allowed")
  /// blocked
  internal static let activityStateBlocked = L10n.tr("Ui", "activity state blocked")
  /// modified
  internal static let activityStateModified = L10n.tr("Ui", "activity state modified")
  /// Time
  internal static let activityTimeOfOccurrence = L10n.tr("Ui", "activity time of occurrence")
  /// You are using Blokada Slim. Learn more
  internal static let advancedActionSlimMigrateToFull = L10n.tr("Ui", "advanced action slim migrate to full")
  /// Blocklists
  internal static let advancedSectionHeaderPacks = L10n.tr("Ui", "advanced section header packs")
  /// Choose apps that should never be blocked
  internal static let advancedSectionSluglineApps = L10n.tr("Ui", "advanced section slugline apps")
  /// Adjust your encryption level and DNS
  internal static let advancedSectionSluglineEncryption = L10n.tr("Ui", "advanced section slugline encryption")
  /// Activate for more restrictive blocking
  internal static let advancedSectionSluglinePacks = L10n.tr("Ui", "advanced section slugline packs")
  /// For security reasons, to download a file, we need to open this website in your browser. Then, please tap the download link again.
  internal static let alertDownloadLinkBody = L10n.tr("Ui", "alert download link body")
  /// Ooops!
  internal static let alertErrorHeader = L10n.tr("Ui", "alert error header")
  /// Blokada %@ is now available for download. We recommend keeping the app up to date, and downloading it only from our official sources.
  internal static func alertUpdateBody(_ p1: Any) -> String {
    return L10n.tr("Ui", "alert update body", String(describing: p1))
  }
  /// BLOKADA+ expired
  internal static let alertVpnExpiredHeader = L10n.tr("Ui", "alert vpn expired header")
  /// Your account is inactive. Please activate your account in order to continue using BLOKADA+.
  internal static let errorAccountInactive = L10n.tr("Ui", "error account inactive")
  /// This does not seem to be a valid active account. If you believe this is a mistake, please contact us by tapping the help icon at the top.
  internal static let errorAccountInactiveAfterRestore = L10n.tr("Ui", "error account inactive after restore")
  /// This account ID seems invalid.
  internal static let errorAccountInvalid = L10n.tr("Ui", "error account invalid")
  /// Blokada DNS is currently supported only in Plus mode. Please choose another DNS and try again.
  internal static let errorBlockaDnsInFilteringMode = L10n.tr("Ui", "error blocka dns in filtering mode")
  /// Could not create a new account. Please try again later.
  internal static let errorCreatingAccount = L10n.tr("Ui", "error creating account")
  /// Your device is offline
  internal static let errorDeviceOffline = L10n.tr("Ui", "error device offline")
  /// This action could not be completed. Make sure you are online, and try again later. If the problem persists, please contact us by tapping the help icon at the top.
  internal static let errorFetchingData = L10n.tr("Ui", "error fetching data")
  /// Could not fetch locations.
  internal static let errorLocationFailedFetching = L10n.tr("Ui", "error location failed fetching")
  /// Could not install (or uninstall) this feature. Please try again later.
  internal static let errorPackInstall = L10n.tr("Ui", "error pack install")
  /// The payment has been canceled. You have not been charged.
  internal static let errorPaymentCanceled = L10n.tr("Ui", "error payment canceled")
  /// Payments are unavailable at this moment. Make sure you are online, and try again later. If the problem persists, please contact us by tapping the help icon at the top.
  internal static let errorPaymentFailed = L10n.tr("Ui", "error payment failed")
  /// Could not complete your payment. Please make sure your data is correct, and try again. If the problem persists, please contact us by tapping the help icon at the top.
  internal static let errorPaymentFailedAlternative = L10n.tr("Ui", "error payment failed alternative")
  /// Your previous payment was restored, but the subscription has already expired. If you believe this is a mistake, please contact us by tapping the help icon at the top.
  internal static let errorPaymentInactiveAfterRestore = L10n.tr("Ui", "error payment inactive after restore")
  /// Payments are unavailable for this device. Either Apple Pay is not activated, or we do not handle purchases in your country yet.
  internal static let errorPaymentNotAvailable = L10n.tr("Ui", "error payment not available")
  /// Could not establish the VPN. Please restart your device, or remove Blokada VPN profile in system settings, and try again.
  internal static let errorTunnel = L10n.tr("Ui", "error tunnel")
  /// An unknown problem occurred. Please try again. If the problem persists, please contact us by tapping the help icon at the top.
  internal static let errorUnknown = L10n.tr("Ui", "error unknown")
  /// Could not establish the VPN. Please restart your device, or remove Blokada VPN profile in system settings, and try again.
  internal static let errorVpn = L10n.tr("Ui", "error vpn")
  /// The VPN is disabled. Please update your subscription to continue using BLOKADA+
  internal static let errorVpnExpired = L10n.tr("Ui", "error vpn expired")
  /// Please select a location first.
  internal static let errorVpnNoCurrentLease = L10n.tr("Ui", "error vpn no current lease")
  /// No permissions granted to create a VPN profile.
  internal static let errorVpnPerms = L10n.tr("Ui", "error vpn perms")
  /// You reached your devices limit. Please remove one of your devices and try again.
  internal static let errorVpnTooManyLeases = L10n.tr("Ui", "error vpn too many leases")
  /// Tap to activate
  internal static let homeActionTapToActivate = L10n.tr("Ui", "home action tap to activate")
  /// ads and trackers blocked since installation
  internal static let homeAdsCounterFootnote = L10n.tr("Ui", "home ads counter footnote")
  /// Protection: High
  internal static let homeLevelHigh = L10n.tr("Ui", "home level high")
  /// Protection: Low
  internal static let homeLevelLow = L10n.tr("Ui", "home level low")
  /// Protection: Medium
  internal static let homeLevelMedium = L10n.tr("Ui", "home level medium")
  /// BLOKADA+ deactivated
  internal static let homePlusButtonDeactivated = L10n.tr("Ui", "home plus button deactivated")
  /// VPN deactivated
  internal static let homePlusButtonDeactivatedCloud = L10n.tr("Ui", "home plus button deactivated cloud")
  /// Location: *%@*
  internal static func homePlusButtonLocation(_ p1: Any) -> String {
    return L10n.tr("Ui", "home plus button location", String(describing: p1))
  }
  /// Select location
  internal static let homePlusButtonSelectLocation = L10n.tr("Ui", "home plus button select location")
  /// Pause for 5 min
  internal static let homePowerActionPause = L10n.tr("Ui", "home power action pause")
  /// Turn off
  internal static let homePowerActionTurnOff = L10n.tr("Ui", "home power action turn off")
  /// Turn on
  internal static let homePowerActionTurnOn = L10n.tr("Ui", "home power action turn on")
  /// What would you like to do?
  internal static let homePowerOffMenuHeader = L10n.tr("Ui", "home power off menu header")
  /// Active
  internal static let homeStatusActive = L10n.tr("Ui", "home status active")
  /// Deactivated
  internal static let homeStatusDeactivated = L10n.tr("Ui", "home status deactivated")
  /// Blocking *ads* and *trackers*
  internal static let homeStatusDetailActive = L10n.tr("Ui", "home status detail active")
  /// Blokada *Slim* is active
  internal static let homeStatusDetailActiveSlim = L10n.tr("Ui", "home status detail active slim")
  /// Blocked *%@* ads and trackers
  internal static func homeStatusDetailActiveWithCounter(_ p1: Any) -> String {
    return L10n.tr("Ui", "home status detail active with counter", String(describing: p1))
  }
  /// Paused until timer ends
  internal static let homeStatusDetailPaused = L10n.tr("Ui", "home status detail paused")
  /// *+* protecting your *privacy*
  internal static let homeStatusDetailPlus = L10n.tr("Ui", "home status detail plus")
  /// Please wait...
  internal static let homeStatusDetailProgress = L10n.tr("Ui", "home status detail progress")
  /// Paused
  internal static let homeStatusPaused = L10n.tr("Ui", "home status paused")
  /// Choose a Location
  internal static let locationChoiceHeader = L10n.tr("Ui", "location choice header")
  /// Blokada is using a VPN Configuration to block ads. You will be asked to allow it in the next step.
  internal static let mainAskForPermissionsDescription = L10n.tr("Ui", "main ask for permissions description")
  /// Just one more step
  internal static let mainAskForPermissionsHeader = L10n.tr("Ui", "main ask for permissions header")
  /// Use side menu to navigate
  internal static let mainLabelUseSideMenu = L10n.tr("Ui", "main label use side menu")
  /// Sure!
  internal static let mainRateUsActionSure = L10n.tr("Ui", "main rate us action sure")
  /// How do you like Blokada so far?
  internal static let mainRateUsDescription = L10n.tr("Ui", "main rate us description")
  /// Rate us!
  internal static let mainRateUsHeader = L10n.tr("Ui", "main rate us header")
  /// Would you help us by rating Blokada on App Store?
  internal static let mainRateUsOnAppStore = L10n.tr("Ui", "main rate us on app store")
  /// Blokada for iOS helped me block %@ ads and trackers!
  internal static func mainShareMessage(_ p1: Any) -> String {
    return L10n.tr("Ui", "main share message", String(describing: p1))
  }
  /// Activity
  internal static let mainTabActivity = L10n.tr("Ui", "main tab activity")
  /// Advanced
  internal static let mainTabAdvanced = L10n.tr("Ui", "main tab advanced")
  /// Home
  internal static let mainTabHome = L10n.tr("Ui", "main tab home")
  /// Settings
  internal static let mainTabSettings = L10n.tr("Ui", "main tab settings")
  /// Encrypt DNS
  internal static let networksActionEncryptDns = L10n.tr("Ui", "networks action encrypt dns")
  /// Force Libre mode
  internal static let networksActionForceLibreMode = L10n.tr("Ui", "networks action force libre mode")
  /// Tap here to modify default settings. To make the app behave differently on some networks, tap below.
  internal static let networksActionNetworkSpecific = L10n.tr("Ui", "networks action network specific")
  /// Use DNS: %@
  internal static func networksActionUseDns(_ p1: Any) -> String {
    return L10n.tr("Ui", "networks action use dns", String(describing: p1))
  }
  /// Prefer network DNS
  internal static let networksActionUseNetworkDns = L10n.tr("Ui", "networks action use network dns")
  /// All networks
  internal static let networksLabelAllNetworks = L10n.tr("Ui", "networks label all networks")
  /// Any mobile network
  internal static let networksLabelAnyMobile = L10n.tr("Ui", "networks label any mobile")
  /// Any WiFi network
  internal static let networksLabelAnyWifi = L10n.tr("Ui", "networks label any wifi")
  /// These settings are currently active
  internal static let networksLabelConfigurationActive = L10n.tr("Ui", "networks label configuration active")
  /// Not connected to this network
  internal static let networksLabelConfigurationEnabled = L10n.tr("Ui", "networks label configuration enabled")
  /// Tap to modify settings for this network
  internal static let networksLabelConfigurationInactive = L10n.tr("Ui", "networks label configuration inactive")
  /// The settings below are applied by default for all networks. You can override them for selected networks (in the previous screen).
  internal static let networksLabelDetailsDefaultNetwork = L10n.tr("Ui", "networks label details default network")
  /// Adjust what should happen when your device connects to this network.
  internal static let networksLabelSpecificNetwork = L10n.tr("Ui", "networks label specific network")
  /// Adjust what should happen when your device connects to a network of this type.
  internal static let networksLabelSpecificNetworkType = L10n.tr("Ui", "networks label specific network type")
  /// Blokada can recognize networks you connect to, and let you configure separate settings for them. However, this app will collect location data in the form of network name to enable this feature, even when the app is closed or not in use. Sometimes you may see a system notification about location access - Blokada will only read the network's name.
  internal static let networksPermissionDialog = L10n.tr("Ui", "networks permission dialog")
  /// To have more control, tap here and let the app recognise all networks.
  internal static let networksPermissionRequest = L10n.tr("Ui", "networks permission request")
  /// You may see a notification when Blokada reads your network name in the background.
  internal static let networksPermissionRequestGranted = L10n.tr("Ui", "networks permission request granted")
  /// Choose DNS
  internal static let networksSectionChooseDns = L10n.tr("Ui", "networks section choose dns")
  /// Networks
  internal static let networksSectionHeader = L10n.tr("Ui", "networks section header")
  /// Adjust settings for WiFi and mobile networks
  internal static let networksSectionLabel = L10n.tr("Ui", "networks section label")
  /// Blokada will use Blokada DNS in Plus mode, to ensure high level of encryption and speed. You may change this setting at the bottom of the Choose DNS screen.
  internal static let networksSummaryBlockaPlusMode = L10n.tr("Ui", "networks summary blocka plus mode")
  /// Blokada will encrypt DNS if possible. This improves your security and prevents malicious actors to spy on what websites and apps you use.
  internal static let networksSummaryEncryptDns = L10n.tr("Ui", "networks summary encrypt dns")
  /// Blokada will always use Libre mode on this network, and ignore your Blokada Plus location. This is useful for networks where you do not want the additional protection.
  internal static let networksSummaryForceLibreMode = L10n.tr("Ui", "networks summary force libre mode")
  /// Blokada will use the network's DNS if available, or switch to %@ otherwise. Also, the Encrypt DNS settings will be ignored whenever network DNS is used. Using the network's DNS helps to fix connectivity problems on troublesome networks, but leaves you unprotected.
  internal static func networksSummaryNetworkDns(_ p1: Any) -> String {
    return L10n.tr("Ui", "networks summary network dns", String(describing: p1))
  }
  /// Blokada will temporarily disable Plus Mode whenever network DNS is used. This is because it is not possible to access network DNS in VPN. The Plus Mode will be automatically restored when your device switches to another network.
  internal static let networksSummaryNetworkDnsAndPlusMode = L10n.tr("Ui", "networks summary network dns and plus mode")
  /// Blokada will use %@ as your device's DNS. Choosing the one that allows for encryption (has the lock icon), and is near to you, will help protecting your data and making your connection fast.
  internal static func networksSummaryUseDns(_ p1: Any) -> String {
    return L10n.tr("Ui", "networks summary use dns", String(describing: p1))
  }
  /// Swipe the notification left or right for settings.
  internal static let notificationDescSettings = L10n.tr("Ui", "notification desc settings")
  /// An update is available
  internal static let notificationUpdateHeader = L10n.tr("Ui", "notification update header")
  /// Please update your subscription to continue using BLOKADA+
  internal static let notificationVpnExpiredBody = L10n.tr("Ui", "notification vpn expired body")
  /// BLOKADA+ subscription expired
  internal static let notificationVpnExpiredHeader = L10n.tr("Ui", "notification vpn expired header")
  /// The VPN is disabled
  internal static let notificationVpnExpiredSubtitle = L10n.tr("Ui", "notification vpn expired subtitle")
  /// GET
  internal static let packActionInstall = L10n.tr("Ui", "pack action install")
  /// REMOVE
  internal static let packActionUninstall = L10n.tr("Ui", "pack action uninstall")
  /// UPDATE
  internal static let packActionUpdate = L10n.tr("Ui", "pack action update")
  /// Author
  internal static let packAuthor = L10n.tr("Ui", "pack author")
  /// Active
  internal static let packCategoryActive = L10n.tr("Ui", "pack category active")
  /// All
  internal static let packCategoryAll = L10n.tr("Ui", "pack category all")
  /// Highlights
  internal static let packCategoryHighlights = L10n.tr("Ui", "pack category highlights")
  /// Configurations
  internal static let packConfigurationsHeader = L10n.tr("Ui", "pack configurations header")
  /// More
  internal static let packInformationHeader = L10n.tr("Ui", "pack information header")
  /// Advanced Features
  internal static let packSectionHeader = L10n.tr("Ui", "pack section header")
  /// Feature Details
  internal static let packSectionHeaderDetails = L10n.tr("Ui", "pack section header details")
  /// Tags
  internal static let packTagsHeader = L10n.tr("Ui", "pack tags header")
  /// None
  internal static let packTagsNone = L10n.tr("Ui", "pack tags none")
  /// Choose a location
  internal static let paymentActionChooseLocation = L10n.tr("Ui", "payment action choose location")
  /// Compare plans
  internal static let paymentActionCompare = L10n.tr("Ui", "payment action compare")
  /// Pay %@
  internal static func paymentActionPay(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment action pay", String(describing: p1))
  }
  /// Pay %@ each period
  internal static func paymentActionPayPeriod(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment action pay period", String(describing: p1))
  }
  /// Privacy Policy
  internal static let paymentActionPolicy = L10n.tr("Ui", "payment action policy")
  /// Restore Purchases
  internal static let paymentActionRestore = L10n.tr("Ui", "payment action restore")
  /// See All Features
  internal static let paymentActionSeeAllFeatures = L10n.tr("Ui", "payment action see all features")
  /// Our Locations
  internal static let paymentActionSeeLocations = L10n.tr("Ui", "payment action see locations")
  /// Terms of Service
  internal static let paymentActionTerms = L10n.tr("Ui", "payment action terms")
  /// Terms & Privacy
  internal static let paymentActionTermsAndPrivacy = L10n.tr("Ui", "payment action terms and privacy")
  /// Blokada will now switch into Plus mode, and connect through one of our secure locations. If you are unsure which one to choose, the closest one to you is recommended.
  internal static let paymentActivatedDescription = L10n.tr("Ui", "payment activated description")
  /// A message from App Store
  internal static let paymentAlertErrorHeader = L10n.tr("Ui", "payment alert error header")
  /// Change
  internal static let paymentChangeMethod = L10n.tr("Ui", "payment change method")
  /// We accept Euro, and the displayed prices are an estimate. A refund is available if your bank charges too much.
  internal static let paymentConversionNote = L10n.tr("Ui", "payment conversion note")
  /// To pay with your cryptocurrency wallet, tap the button below.
  internal static let paymentCryptoDesc = L10n.tr("Ui", "payment crypto desc")
  /// This won't activate your Blokada Plus account. If you wish to use our VPN service, please subscribe instead of donating.
  internal static let paymentDonateDisclaimer = L10n.tr("Ui", "payment donate disclaimer")
  /// We are based in Europe, so we accept Euro: €10 is roughly $12.
  internal static let paymentEuroDesc = L10n.tr("Ui", "payment euro desc")
  /// Your battery life isn't going to be impacted, it might even improve when Blokada Cloud is activated.
  internal static let paymentFeatureDescBattery = L10n.tr("Ui", "payment feature desc battery")
  /// Hide your IP address and pretend you are in another country. This will mask you from third-parties and help protect your identity.
  internal static let paymentFeatureDescChangeLocation = L10n.tr("Ui", "payment feature desc change location")
  /// In addition to all the benefits of Blokada Cloud, you'll get access to our global VPN network
  internal static let paymentFeatureDescCloudVpn = L10n.tr("Ui", "payment feature desc cloud vpn")
  /// Use the same account to share your subscription with up to 5 devices: iOS, Android, or PC.
  internal static let paymentFeatureDescDevices = L10n.tr("Ui", "payment feature desc devices")
  /// Configure and monitor all your devices in one place. Either through our mobile app or our web app.
  internal static let paymentFeatureDescDevicesCloud = L10n.tr("Ui", "payment feature desc devices cloud")
  /// Data sent through our VPN tunnel is encrypted using strong algorithms in order to protect against interception by unauthorized parties.
  internal static let paymentFeatureDescEncryptData = L10n.tr("Ui", "payment feature desc encrypt data")
  /// Improve your privacy with DNS encryption. Blokada Cloud uses modern protocols to help keep your traffic private.
  internal static let paymentFeatureDescEncryptDns = L10n.tr("Ui", "payment feature desc encrypt dns")
  /// Great speeds up to 100Mbps with servers in various parts of the World.
  internal static let paymentFeatureDescFasterConnection = L10n.tr("Ui", "payment feature desc faster connection")
  /// Use the popular Blokada adblocking technology to block ads on your devices. Advanced settings are available.
  internal static let paymentFeatureDescNoAds = L10n.tr("Ui", "payment feature desc no ads")
  /// Keep your device snappy and your Internet connection at max speeds, thanks to our new Cloud solution.
  internal static let paymentFeatureDescPerformance = L10n.tr("Ui", "payment feature desc performance")
  /// Get a prompt response to any questions thanks to our Customer Support and vibrant open source community.
  internal static let paymentFeatureDescSupport = L10n.tr("Ui", "payment feature desc support")
  /// Zero Battery Impact
  internal static let paymentFeatureTitleBattery = L10n.tr("Ui", "payment feature title battery")
  /// Change Location
  internal static let paymentFeatureTitleChangeLocation = L10n.tr("Ui", "payment feature title change location")
  /// The Cloud plus VPN
  internal static let paymentFeatureTitleCloudVpn = L10n.tr("Ui", "payment feature title cloud vpn")
  /// Up to 5 devices
  internal static let paymentFeatureTitleDevices = L10n.tr("Ui", "payment feature title devices")
  /// Multiple Devices
  internal static let paymentFeatureTitleDevicesCloud = L10n.tr("Ui", "payment feature title devices cloud")
  /// Encrypt Data
  internal static let paymentFeatureTitleEncryptData = L10n.tr("Ui", "payment feature title encrypt data")
  /// Encrypt DNS
  internal static let paymentFeatureTitleEncryptDns = L10n.tr("Ui", "payment feature title encrypt dns")
  /// Faster Connection
  internal static let paymentFeatureTitleFasterConnection = L10n.tr("Ui", "payment feature title faster connection")
  /// Block Ads
  internal static let paymentFeatureTitleNoAds = L10n.tr("Ui", "payment feature title no ads")
  /// Great Performance
  internal static let paymentFeatureTitlePerformance = L10n.tr("Ui", "payment feature title performance")
  /// Great Support
  internal static let paymentFeatureTitleSupport = L10n.tr("Ui", "payment feature title support")
  /// Activated!
  internal static let paymentHeaderActivated = L10n.tr("Ui", "payment header activated")
  /// Cheapest
  internal static let paymentLabelCheapest = L10n.tr("Ui", "payment label cheapest")
  /// Choose your package
  internal static let paymentLabelChoosePackage = L10n.tr("Ui", "payment label choose package")
  /// Choose your payment method
  internal static let paymentLabelChoosePaymentMethod = L10n.tr("Ui", "payment label choose payment method")
  /// Country
  internal static let paymentLabelCountry = L10n.tr("Ui", "payment label country")
  /// Save %@ (%@ / mo)
  internal static func paymentLabelDiscount(_ p1: Any, _ p2: Any) -> String {
    return L10n.tr("Ui", "payment label discount", String(describing: p1), String(describing: p2))
  }
  /// Email
  internal static let paymentLabelEmail = L10n.tr("Ui", "payment label email")
  /// Most popular
  internal static let paymentLabelMostPopular = L10n.tr("Ui", "payment label most popular")
  /// Pay with card
  internal static let paymentLabelPayWithCard = L10n.tr("Ui", "payment label pay with card")
  /// Pay with crypto
  internal static let paymentLabelPayWithCrypto = L10n.tr("Ui", "payment label pay with crypto")
  /// Pay with PayPal
  internal static let paymentLabelPayWithPaypal = L10n.tr("Ui", "payment label pay with paypal")
  /// Credit card payments should not take more than a few minutes. Cryptocurrency payments usually take up to an hour, depending on what transaction fee you chose. In case of PayPal, it may take up to 24 hours. You will get redirected once your account is ready. You may also close this screen, and come again later. If you feel like your transaction is taking too long, please contact us.
  internal static let paymentOngoingDesc = L10n.tr("Ui", "payment ongoing desc")
  /// Your payment is now being processed.
  internal static let paymentOngoingTitle = L10n.tr("Ui", "payment ongoing title")
  /// 1 Month
  internal static let paymentPackageOneMonth = L10n.tr("Ui", "payment package one month")
  /// 6 Months
  internal static let paymentPackageSixMonths = L10n.tr("Ui", "payment package six months")
  /// 12 Months
  internal static let paymentPackageTwelveMonths = L10n.tr("Ui", "payment package twelve months")
  /// Apple Pay
  internal static let paymentPayAppleShort = L10n.tr("Ui", "payment pay apple short")
  /// Google Pay
  internal static let paymentPayGoogleShort = L10n.tr("Ui", "payment pay google short")
  /// Blocks ads and trackers
  internal static let paymentPlanSluglineCloud = L10n.tr("Ui", "payment plan slugline cloud")
  /// Please wait. This should only take a moment.
  internal static let paymentRedirectDesc = L10n.tr("Ui", "payment redirect desc")
  /// Redirecting...
  internal static let paymentRedirectLabel = L10n.tr("Ui", "payment redirect label")
  /// You are saving %@
  internal static func paymentSaveText(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment save text", String(describing: p1))
  }
  /// 1 Month
  internal static let paymentSubscription1Month = L10n.tr("Ui", "payment subscription 1 month")
  /// %@ Months
  internal static func paymentSubscriptionManyMonths(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment subscription many months", String(describing: p1))
  }
  /// Save %@
  internal static func paymentSubscriptionOffer(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment subscription offer", String(describing: p1))
  }
  /// %@ per month
  internal static func paymentSubscriptionPerMonth(_ p1: Any) -> String {
    return L10n.tr("Ui", "payment subscription per month", String(describing: p1))
  }
  /// Your account is now active! You may now use all Blokada Plus features on all your devices.
  internal static let paymentSuccessDesc = L10n.tr("Ui", "payment success desc")
  /// Thanks!
  internal static let paymentSuccessLabel = L10n.tr("Ui", "payment success label")
  /// Upgrade to our VPN service to stay in control of *your privacy*.
  internal static let paymentTitle = L10n.tr("Ui", "payment title")
  /// Cancel
  internal static let universalActionCancel = L10n.tr("Ui", "universal action cancel")
  /// Clear
  internal static let universalActionClear = L10n.tr("Ui", "universal action clear")
  /// Close
  internal static let universalActionClose = L10n.tr("Ui", "universal action close")
  /// Community
  internal static let universalActionCommunity = L10n.tr("Ui", "universal action community")
  /// Contact us
  internal static let universalActionContactUs = L10n.tr("Ui", "universal action contact us")
  /// Continue
  internal static let universalActionContinue = L10n.tr("Ui", "universal action continue")
  /// Copy
  internal static let universalActionCopy = L10n.tr("Ui", "universal action copy")
  /// Delete
  internal static let universalActionDelete = L10n.tr("Ui", "universal action delete")
  /// Donate
  internal static let universalActionDonate = L10n.tr("Ui", "universal action donate")
  /// Done
  internal static let universalActionDone = L10n.tr("Ui", "universal action done")
  /// Download
  internal static let universalActionDownload = L10n.tr("Ui", "universal action download")
  /// Filter
  internal static let universalActionFilter = L10n.tr("Ui", "universal action filter")
  /// Help
  internal static let universalActionHelp = L10n.tr("Ui", "universal action help")
  /// Hide
  internal static let universalActionHide = L10n.tr("Ui", "universal action hide")
  /// Learn more
  internal static let universalActionLearnMore = L10n.tr("Ui", "universal action learn more")
  /// More
  internal static let universalActionMore = L10n.tr("Ui", "universal action more")
  /// News
  internal static let universalActionNews = L10n.tr("Ui", "universal action news")
  /// No
  internal static let universalActionNo = L10n.tr("Ui", "universal action no")
  /// Open in browser
  internal static let universalActionOpenInBrowser = L10n.tr("Ui", "universal action open in browser")
  /// Revoke
  internal static let universalActionRevoke = L10n.tr("Ui", "universal action revoke")
  /// Save
  internal static let universalActionSave = L10n.tr("Ui", "universal action save")
  /// Search
  internal static let universalActionSearch = L10n.tr("Ui", "universal action search")
  /// Select
  internal static let universalActionSelect = L10n.tr("Ui", "universal action select")
  /// Selected
  internal static let universalActionSelected = L10n.tr("Ui", "universal action selected")
  /// Share log
  internal static let universalActionShareLog = L10n.tr("Ui", "universal action share log")
  /// Logs
  internal static let universalActionShowLog = L10n.tr("Ui", "universal action show log")
  /// Support
  internal static let universalActionSupport = L10n.tr("Ui", "universal action support")
  /// Try again
  internal static let universalActionTryAgain = L10n.tr("Ui", "universal action try again")
  /// Upgrade to BLOKADA+
  internal static let universalActionUpgrade = L10n.tr("Ui", "universal action upgrade")
  /// Upgrade
  internal static let universalActionUpgradeShort = L10n.tr("Ui", "universal action upgrade short")
  /// Yes
  internal static let universalActionYes = L10n.tr("Ui", "universal action yes")
  /// Count
  internal static let universalLabelCount = L10n.tr("Ui", "universal label count")
  /// Device
  internal static let universalLabelDevice = L10n.tr("Ui", "universal label device")
  /// Help
  internal static let universalLabelHelp = L10n.tr("Ui", "universal label help")
  /// Name
  internal static let universalLabelName = L10n.tr("Ui", "universal label name")
  /// None
  internal static let universalLabelNone = L10n.tr("Ui", "universal label none")
  /// Time
  internal static let universalLabelTime = L10n.tr("Ui", "universal label time")
  /// Type
  internal static let universalLabelType = L10n.tr("Ui", "universal label type")
  /// Welcome!
  internal static let universalLabelWelcome = L10n.tr("Ui", "universal label welcome")
  /// Are you sure you want to proceed?
  internal static let universalStatusConfirm = L10n.tr("Ui", "universal status confirm")
  /// Copied to Clipboard
  internal static let universalStatusCopiedToClipboard = L10n.tr("Ui", "universal status copied to clipboard")
  /// Processing... Please wait.
  internal static let universalStatusProcessing = L10n.tr("Ui", "universal status processing")
  /// Continue with the Blokada App
  internal static let universalStatusRedirect = L10n.tr("Ui", "universal status redirect")
  /// Please restart the app for the changes to take effect.
  internal static let universalStatusRestartRequired = L10n.tr("Ui", "universal status restart required")
  /// You are now using the newest version of Blokada! Remember, donating or subscribing to Blokada Plus allows us to continue improving the app.
  internal static let updateDescUpdated = L10n.tr("Ui", "update desc updated")
  /// The update is now downloading, and you should see the installation prompt shortly.
  internal static let updateDownloadingDescription = L10n.tr("Ui", "update downloading description")
  /// Updated!
  internal static let updateLabelUpdated = L10n.tr("Ui", "update label updated")
  /// Allow
  internal static let userdeniedActionAllow = L10n.tr("Ui", "userdenied action allow")
  /// Block
  internal static let userdeniedActionBlock = L10n.tr("Ui", "userdenied action block")
  /// Exceptions
  internal static let userdeniedSectionHeader = L10n.tr("Ui", "userdenied section header")
  /// Manage blocking of particular websites
  internal static let userdeniedSectionSlugline = L10n.tr("Ui", "userdenied section slugline")
  /// Allowed
  internal static let userdeniedTabAllowed = L10n.tr("Ui", "userdenied tab allowed")
  /// Blocked
  internal static let userdeniedTabBlocked = L10n.tr("Ui", "userdenied tab blocked")
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: nil, table: table)
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
