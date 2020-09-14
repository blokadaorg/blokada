// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name
internal enum L10n {
  /// About
  internal static let accountActionAbout = L10n.tr("Ui", "account action about")
  /// Devices
  internal static let accountActionDevices = L10n.tr("Ui", "account action devices")
  /// Encryption
  internal static let accountActionEncryption = L10n.tr("Ui", "account action encryption")
  /// How do I restore my old account?
  internal static let accountActionHowToRestore = L10n.tr("Ui", "account action how to restore")
  /// Inbox
  internal static let accountActionInbox = L10n.tr("Ui", "account action inbox")
  /// Logout / Restore account
  internal static let accountActionLogout = L10n.tr("Ui", "account action logout")
  /// Manage subscription
  internal static let accountActionManageSubscription = L10n.tr("Ui", "account action manage subscription")
  /// My account
  internal static let accountActionMyAccount = L10n.tr("Ui", "account action my account")
  /// Restoring account: %@
  internal static func accountActionRestoring(_ p1: String) -> String {
    return L10n.tr("Ui", "account action restoring", p1)
  }
  /// Tap to show
  internal static let accountActionTapToShow = L10n.tr("Ui", "account action tap to show")
  /// Why should I upgrade?
  internal static let accountActionWhyUpgrade = L10n.tr("Ui", "account action why upgrade")
  /// Forever
  internal static let accountActiveForever = L10n.tr("Ui", "account active forever")
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
  /// Encrypting everything
  internal static let accountEncryptLabelEverything = L10n.tr("Ui", "account encrypt label everything")
  /// Level
  internal static let accountEncryptLabelLevel = L10n.tr("Ui", "account encrypt label level")
  /// High: Encrypting Everything
  internal static let accountEncryptLabelLevelHigh = L10n.tr("Ui", "account encrypt label level high")
  /// Low: No Encryption
  internal static let accountEncryptLabelLevelLow = L10n.tr("Ui", "account encrypt label level low")
  /// Medium: Encrypting DNS
  internal static let accountEncryptLabelLevelMedium = L10n.tr("Ui", "account encrypt label level medium")
  /// High
  internal static let accountEncryptLevelHigh = L10n.tr("Ui", "account encrypt level high")
  /// Low
  internal static let accountEncryptLevelLow = L10n.tr("Ui", "account encrypt level low")
  /// Medium
  internal static let accountEncryptLevelMedium = L10n.tr("Ui", "account encrypt level medium")
  /// Encryption
  internal static let accountEncryptSectionHeader = L10n.tr("Ui", "account encrypt section header")
  /// Log out
  internal static let accountHeaderLogout = L10n.tr("Ui", "account header logout")
  /// (unchanged)
  internal static let accountIdStatusUnchanged = L10n.tr("Ui", "account id status unchanged")
  /// Active until
  internal static let accountLabelActiveUntil = L10n.tr("Ui", "account label active until")
  /// Account ID
  internal static let accountLabelId = L10n.tr("Ui", "account label id")
  /// Account type
  internal static let accountLabelType = L10n.tr("Ui", "account label type")
  /// Devices
  internal static let accountLeaseLabelDevices = L10n.tr("Ui", "account lease label devices")
  /// These devices are connected to your account.
  internal static let accountLeaseLabelDevicesList = L10n.tr("Ui", "account lease label devices list")
  ///  (this device)
  internal static let accountLeaseLabelThisDevice = L10n.tr("Ui", "account lease label this device")
  /// Please enter another account ID, or go back to keep using your existing account (this app cannot be used without one).
  internal static let accountLogoutDescription = L10n.tr("Ui", "account logout description")
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
  internal static func accountStatusText(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Ui", "account status text", p1, p2)
  }
  /// Your BLOKADA Libre account is active until forever.
  internal static let accountStatusTextLibre = L10n.tr("Ui", "account status text libre")
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
  /// Full name
  internal static let activityDomainName = L10n.tr("Ui", "activity domain name")
  /// Try using your device, and come back here later, to see where your device connects to.
  internal static let activityEmptyText = L10n.tr("Ui", "activity empty text")
  /// Which entries would you like to see?
  internal static let activityFilterHeader = L10n.tr("Ui", "activity filter header")
  /// Show all entries
  internal static let activityFilterShowAll = L10n.tr("Ui", "activity filter show all")
  /// Show allowed only
  internal static let activityFilterShowAllowed = L10n.tr("Ui", "activity filter show allowed")
  /// Show blocked only
  internal static let activityFilterShowBlocked = L10n.tr("Ui", "activity filter show blocked")
  /// %@ times
  internal static func activityHappenedManyTimes(_ p1: String) -> String {
    return L10n.tr("Ui", "activity happened many times", p1)
  }
  /// 1 time
  internal static let activityHappenedOneTime = L10n.tr("Ui", "activity happened one time")
  /// Information
  internal static let activityInformationHeader = L10n.tr("Ui", "activity information header")
  /// Number of occurrences
  internal static let activityNumberOfOccurrences = L10n.tr("Ui", "activity number of occurrences")
  /// This request has been allowed.
  internal static let activityRequestAllowed = L10n.tr("Ui", "activity request allowed")
  /// This request has been allowed, because it is on your Allowed list
  internal static let activityRequestAllowedWhitelisted = L10n.tr("Ui", "activity request allowed whitelisted")
  /// This request has been blocked.
  internal static let activityRequestBlocked = L10n.tr("Ui", "activity request blocked")
  /// This request has been blocked, because it is on your Blocked list
  internal static let activityRequestBlockedBlacklisted = L10n.tr("Ui", "activity request blocked blacklisted")
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
  internal static func alertUpdateBody(_ p1: String) -> String {
    return L10n.tr("Ui", "alert update body", p1)
  }
  /// BLOKADA+ expired
  internal static let alertVpnExpiredHeader = L10n.tr("Ui", "alert vpn expired header")
  /// Open App Information
  internal static let appSettingsActionAppInfo = L10n.tr("Ui", "app settings action app info")
  /// Open Notification Settings
  internal static let appSettingsActionNotifications = L10n.tr("Ui", "app settings action notifications")
  /// Open VPN Profile
  internal static let appSettingsActionVpnProfile = L10n.tr("Ui", "app settings action vpn profile")
  /// Use cloud backup
  internal static let appSettingsBackup = L10n.tr("Ui", "app settings backup")
  /// External browser (if possible)
  internal static let appSettingsBrowserExternal = L10n.tr("Ui", "app settings browser external")
  /// Internal browser
  internal static let appSettingsBrowserInternal = L10n.tr("Ui", "app settings browser internal")
  /// Redirect links to
  internal static let appSettingsBrowserLabel = L10n.tr("Ui", "app settings browser label")
  /// Allow IPv6
  internal static let appSettingsIpv6Label = L10n.tr("Ui", "app settings ipv6 label")
  /// Language
  internal static let appSettingsLanguageLabel = L10n.tr("Ui", "app settings language label")
  /// Advanced
  internal static let appSettingsSectionAdvanced = L10n.tr("Ui", "app settings section advanced")
  /// Details
  internal static let appSettingsSectionDetails = L10n.tr("Ui", "app settings section details")
  /// This device
  internal static let appSettingsSectionHeader = L10n.tr("Ui", "app settings section header")
  /// System
  internal static let appSettingsSectionSystem = L10n.tr("Ui", "app settings section system")
  /// Start on boot
  internal static let appSettingsStartOnBoot = L10n.tr("Ui", "app settings start on boot")
  /// System default
  internal static let appSettingsStatusDefault = L10n.tr("Ui", "app settings status default")
  /// Dark
  internal static let appSettingsThemeDark = L10n.tr("Ui", "app settings theme dark")
  /// App theme
  internal static let appSettingsThemeLabel = L10n.tr("Ui", "app settings theme label")
  /// Light
  internal static let appSettingsThemeLight = L10n.tr("Ui", "app settings theme light")
  /// Use DNS over HTTPS
  internal static let appSettingsUseDnsOverHttps = L10n.tr("Ui", "app settings use dns over https")
  /// Show all apps
  internal static let appsFilterActionShowAll = L10n.tr("Ui", "apps filter action show all")
  /// Show bypassed only
  internal static let appsFilterActionShowBypassed = L10n.tr("Ui", "apps filter action show bypassed")
  /// Show not bypassed only
  internal static let appsFilterActionShowNotBypassed = L10n.tr("Ui", "apps filter action show not bypassed")
  /// Toggle all system apps
  internal static let appsFilterActionToggleSystem = L10n.tr("Ui", "apps filter action toggle system")
  /// Which apps would you like to see?
  internal static let appsFilterHeader = L10n.tr("Ui", "apps filter header")
  /// Installed
  internal static let appsLabelInstalled = L10n.tr("Ui", "apps label installed")
  /// System
  internal static let appsLabelSystem = L10n.tr("Ui", "apps label system")
  /// Apps
  internal static let appsSectionHeader = L10n.tr("Ui", "apps section header")
  /// (bypassed)
  internal static let appsStatusBypassed = L10n.tr("Ui", "apps status bypassed")
  /// Your account is inactive. Please activate your account in order to continue using BLOKADA+.
  internal static let errorAccountInactive = L10n.tr("Ui", "error account inactive")
  /// This does not seem to be a valid active account. If you believe this is a mistake, please contact us by tapping the help icon at the top.
  internal static let errorAccountInactiveAfterRestore = L10n.tr("Ui", "error account inactive after restore")
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
  /// tap to activate
  internal static let homeActionTapToActivate = L10n.tr("Ui", "home action tap to activate")
  /// ads and trackers blocked since installation
  internal static let homeAdsCounterFootnote = L10n.tr("Ui", "home ads counter footnote")
  /// BLOKADA+ deactivated
  internal static let homePlusButtonDeactivated = L10n.tr("Ui", "home plus button deactivated")
  /// Location: *%@*
  internal static func homePlusButtonLocation(_ p1: String) -> String {
    return L10n.tr("Ui", "home plus button location", p1)
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
  /// ACTIVE
  internal static let homeStatusActive = L10n.tr("Ui", "home status active")
  /// DEACTIVATED
  internal static let homeStatusDeactivated = L10n.tr("Ui", "home status deactivated")
  /// blocking *ads* and *trackers*
  internal static let homeStatusDetailActive = L10n.tr("Ui", "home status detail active")
  /// Blokada *Slim* is active
  internal static let homeStatusDetailActiveSlim = L10n.tr("Ui", "home status detail active slim")
  /// blocked *%@* ads and trackers
  internal static func homeStatusDetailActiveWithCounter(_ p1: String) -> String {
    return L10n.tr("Ui", "home status detail active with counter", p1)
  }
  /// paused until timer ends
  internal static let homeStatusDetailPaused = L10n.tr("Ui", "home status detail paused")
  /// *+* protecting your *privacy*
  internal static let homeStatusDetailPlus = L10n.tr("Ui", "home status detail plus")
  /// please wait...
  internal static let homeStatusDetailProgress = L10n.tr("Ui", "home status detail progress")
  /// PAUSED
  internal static let homeStatusPaused = L10n.tr("Ui", "home status paused")
  /// Blokada is Active!
  internal static let introHeader = L10n.tr("Ui", "intro header")
  /// A blue ring means that Blokada is working.\n\nRemember, some ads, like YouTube, cannot be blocked. However, you will notice a difference in many other apps.\n\nWe recommend you activate Always on VPN / Connect on Demand in your system settings.
  internal static let introText = L10n.tr("Ui", "intro text")
  /// Choose a Location
  internal static let locationChoiceHeader = L10n.tr("Ui", "location choice header")
  /// America
  internal static let locationRegionAmerica = L10n.tr("Ui", "location region america")
  /// Asia
  internal static let locationRegionAsia = L10n.tr("Ui", "location region asia")
  /// Europe
  internal static let locationRegionEurope = L10n.tr("Ui", "location region europe")
  /// Blokada is using a VPN Configuration to block ads. You will be asked to allow it in the next step.
  internal static let mainAskForPermissionsDescription = L10n.tr("Ui", "main ask for permissions description")
  /// Just one more step
  internal static let mainAskForPermissionsHeader = L10n.tr("Ui", "main ask for permissions header")
  /// Sure!
  internal static let mainRateUsActionSure = L10n.tr("Ui", "main rate us action sure")
  /// How do you like Blokada so far?
  internal static let mainRateUsDescription = L10n.tr("Ui", "main rate us description")
  /// Rate us!
  internal static let mainRateUsHeader = L10n.tr("Ui", "main rate us header")
  /// Would you help us by rating Blokada on App Store?
  internal static let mainRateUsOnAppStore = L10n.tr("Ui", "main rate us on app store")
  /// Blokada for iOS helped me block %@ ads and trackers!
  internal static func mainShareMessage(_ p1: String) -> String {
    return L10n.tr("Ui", "main share message", p1)
  }
  /// Activity
  internal static let mainTabActivity = L10n.tr("Ui", "main tab activity")
  /// Advanced
  internal static let mainTabAdvanced = L10n.tr("Ui", "main tab advanced")
  /// Home
  internal static let mainTabHome = L10n.tr("Ui", "main tab home")
  /// Settings
  internal static let mainTabSettings = L10n.tr("Ui", "main tab settings")
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
  /// Privacy Policy
  internal static let paymentActionPolicy = L10n.tr("Ui", "payment action policy")
  /// Restore Purchases
  internal static let paymentActionRestore = L10n.tr("Ui", "payment action restore")
  /// See All Features
  internal static let paymentActionSeeAllFeatures = L10n.tr("Ui", "payment action see all features")
  /// Terms of Service
  internal static let paymentActionTerms = L10n.tr("Ui", "payment action terms")
  /// Terms & Privacy
  internal static let paymentActionTermsAndPrivacy = L10n.tr("Ui", "payment action terms and privacy")
  /// Blokada will now switch into Plus mode, and connect through one of our secure locations. If you are unsure which one to choose, the closest one to you is recommended.
  internal static let paymentActivatedDescription = L10n.tr("Ui", "payment activated description")
  /// A message from App Store
  internal static let paymentAlertErrorHeader = L10n.tr("Ui", "payment alert error header")
  /// Hide your IP address and pretend you are in another country. This will mask you from third-parties and help protect your identity.
  internal static let paymentFeatureDescChangeLocation = L10n.tr("Ui", "payment feature desc change location")
  /// Use the same account to share your subscription with up to 5 devices: iOS, Android, or PC.
  internal static let paymentFeatureDescDevices = L10n.tr("Ui", "payment feature desc devices")
  /// Data sent through our VPN tunnel is encrypted using strong algorithms in order to protect against interception by unauthorized parties.
  internal static let paymentFeatureDescEncryptData = L10n.tr("Ui", "payment feature desc encrypt data")
  /// Great speeds up to 100Mbps with servers in various parts of the World.
  internal static let paymentFeatureDescFasterConnection = L10n.tr("Ui", "payment feature desc faster connection")
  /// Keep using the world famous Blokada adblocking technology while improving your protection level and keeping your data private.
  internal static let paymentFeatureDescNoAds = L10n.tr("Ui", "payment feature desc no ads")
  /// Get a prompt response to any questions thanks to our Customer Support and vibrant open source community.
  internal static let paymentFeatureDescSupport = L10n.tr("Ui", "payment feature desc support")
  /// Change Location
  internal static let paymentFeatureTitleChangeLocation = L10n.tr("Ui", "payment feature title change location")
  /// Up to 5 devices
  internal static let paymentFeatureTitleDevices = L10n.tr("Ui", "payment feature title devices")
  /// Encrypt Data
  internal static let paymentFeatureTitleEncryptData = L10n.tr("Ui", "payment feature title encrypt data")
  /// Faster Connection
  internal static let paymentFeatureTitleFasterConnection = L10n.tr("Ui", "payment feature title faster connection")
  /// No Ads
  internal static let paymentFeatureTitleNoAds = L10n.tr("Ui", "payment feature title no ads")
  /// Great Support
  internal static let paymentFeatureTitleSupport = L10n.tr("Ui", "payment feature title support")
  /// Activated!
  internal static let paymentHeaderActivated = L10n.tr("Ui", "payment header activated")
  /// 1 Month
  internal static let paymentSubscription1Month = L10n.tr("Ui", "payment subscription 1 month")
  /// %@ Months
  internal static func paymentSubscriptionManyMonths(_ p1: String) -> String {
    return L10n.tr("Ui", "payment subscription many months", p1)
  }
  /// Save %@
  internal static func paymentSubscriptionOffer(_ p1: String) -> String {
    return L10n.tr("Ui", "payment subscription offer", p1)
  }
  /// %@ per month
  internal static func paymentSubscriptionPerMonth(_ p1: String) -> String {
    return L10n.tr("Ui", "payment subscription per month", p1)
  }
  /// Upgrade to our VPN service to stay in control of *your privacy*.
  internal static let paymentTitle = L10n.tr("Ui", "payment title")
  /// Cancel
  internal static let universalActionCancel = L10n.tr("Ui", "universal action cancel")
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
  /// Donate
  internal static let universalActionDonate = L10n.tr("Ui", "universal action donate")
  /// Done
  internal static let universalActionDone = L10n.tr("Ui", "universal action done")
  /// Download
  internal static let universalActionDownload = L10n.tr("Ui", "universal action download")
  /// Help
  internal static let universalActionHelp = L10n.tr("Ui", "universal action help")
  /// Learn more
  internal static let universalActionLearnMore = L10n.tr("Ui", "universal action learn more")
  /// More
  internal static let universalActionMore = L10n.tr("Ui", "universal action more")
  /// No
  internal static let universalActionNo = L10n.tr("Ui", "universal action no")
  /// Open in browser
  internal static let universalActionOpenInBrowser = L10n.tr("Ui", "universal action open in browser")
  /// Save
  internal static let universalActionSave = L10n.tr("Ui", "universal action save")
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
  /// Yes
  internal static let universalActionYes = L10n.tr("Ui", "universal action yes")
  /// Help
  internal static let universalLabelHelp = L10n.tr("Ui", "universal label help")
  /// Copied to Clipboard
  internal static let universalStatusCopiedToClipboard = L10n.tr("Ui", "universal status copied to clipboard")
  /// Processing... Please wait.
  internal static let universalStatusProcessing = L10n.tr("Ui", "universal status processing")
  /// Please restart the app for the changes to take effect.
  internal static let universalStatusRestartRequired = L10n.tr("Ui", "universal status restart required")
  /// The update is now downloading, and you should see the installation prompt shortly.
  internal static let updateDownloadingDescription = L10n.tr("Ui", "update downloading description")
  /// Updated!
  internal static let updateLabelUpdated = L10n.tr("Ui", "update label updated")
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    // swiftlint:disable:next nslocalizedstring_key
    let format = NSLocalizedString(key, tableName: table, bundle: Bundle(for: BundleToken.self), comment: "")
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

private final class BundleToken {}
