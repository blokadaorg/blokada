/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package ui

import android.content.Intent
import android.graphics.Rect
import android.net.Uri
import android.os.Bundle
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import androidx.appcompat.widget.Toolbar
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.navigation.findNavController
import androidx.navigation.ui.AppBarConfiguration
import androidx.navigation.ui.setupActionBarWithNavController
import androidx.navigation.ui.setupWithNavController
import androidx.preference.Preference
import androidx.preference.PreferenceFragmentCompat
import com.akexorcist.localizationactivity.ui.LocalizationActivity
import com.google.android.material.bottomnavigation.BottomNavigationView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import model.AppStage
import model.PrivateDnsConfigured
import model.Tab
import org.blokada.R
import repository.Repos
import service.*
import ui.home.ActivatedFragment
import ui.home.FirstTimeFragment
import ui.home.HelpFragment
import ui.home.HomeFragmentDirections
import ui.settings.SettingsNavigation
import ui.utils.now
import ui.web.WebService
import utils.ExpiredNotification
import utils.Links
import utils.Logger


class MainActivity : LocalizationActivity(), PreferenceFragmentCompat.OnPreferenceStartFragmentCallback {

    private lateinit var accountVM: AccountViewModel
    private lateinit var tunnelVM: TunnelViewModel
    private lateinit var settingsVM: SettingsViewModel
    private lateinit var statsVM: StatsViewModel
    private lateinit var blockaRepoVM: BlockaRepoViewModel
    private lateinit var activationVM: ActivationViewModel

    private val navRepo by lazy { Repos.nav }
    private val paymentRepo by lazy { Repos.payment }
    private val processingRepo by lazy { Repos.processing }

    private val sheet = Services.sheet
    private val dialog by lazy { DialogService }
    private val flutter by lazy { FlutterService }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Logger.v("MainActivity", "onCreate: $this")

        WindowCompat.setDecorFitsSystemWindows(window, false)
        ContextService.setActivityContext(this)
        TranslationService.setup()
        Services.sheet.onShowFragment = { fragment ->
            fragment.show(supportFragmentManager, null)
        }
        setupEvents()

        settingsVM.getTheme()?.let { setTheme(it) }

        setContentView(R.layout.activity_main)

        val navView: BottomNavigationView = findViewById(R.id.nav_view)
        val toolbar: Toolbar = findViewById(R.id.toolbar)
        val fragmentContainer: ViewGroup = findViewById(R.id.container_fragment)

        val mainIssuesOverlay: ViewGroup = findViewById(R.id.main_issues_overlay)
        mainIssuesOverlay.translationY = 200f
        mainIssuesOverlay.setOnClickListener {
            sheet.showSheet(Sheet.ConnIssues)
        }
        lifecycleScope.launch {
            processingRepo.connIssuesHot
            .collect { isIssue ->
                if (isIssue) {
                    Logger.w("Main", "Showing ConnIssues bar")
                    mainIssuesOverlay.visibility = View.VISIBLE
                    mainIssuesOverlay.animate().translationY(0.0f)
                } else {
                    Logger.w("Main", "Hiding ConnIssues bar")
                    mainIssuesOverlay.animate().translationY(200.0f).withEndAction {
                        mainIssuesOverlay.visibility = View.GONE
                    }
                }
            }
        }

        setSupportActionBar(toolbar)
        setInsets(toolbar)

        val navController = findNavController(R.id.nav_host_fragment)
        // Passing each menu ID as a set of Ids because each
        // menu should be considered as top level destinations.
        val appBarConfiguration = AppBarConfiguration(
            setOf(
                R.id.navigation_home,
                R.id.navigation_flutterstats,
                R.id.advancedFragment,
                R.id.navigation_settings
            )
        )
        setupActionBarWithNavController(navController, appBarConfiguration)
        navView.setupWithNavController(navController)

        // Set the fragment inset as needed (home fragment has no inset)
        navController.addOnDestinationChangedListener { _, destination, _ ->
            val shouldInset = when (destination.id) {
                R.id.navigation_home -> false
                else -> true
            }
            setFragmentInset(fragmentContainer, shouldInset)

            // An ugly hack to hide jumping fragments when switching tabs
            fragmentContainer.visibility = View.INVISIBLE
            lifecycleScope.launch(Dispatchers.Main) {
                delay(100)
                fragmentContainer.visibility = View.VISIBLE
            }
        }


        // Needed for dynamic translation of the bottom bar
        val selectionListener = BottomNavigationView.OnNavigationItemSelectedListener { item ->
            val (nav, title) = when (item.itemId) {
                R.id.navigation_flutterstats -> R.id.navigation_flutterstats to getString(R.string.main_tab_activity)
                R.id.advancedFragment -> R.id.advancedFragment to getString(R.string.main_tab_advanced)
                R.id.navigation_settings -> R.id.navigation_settings to getString(R.string.main_tab_settings)
                else -> R.id.navigation_home to getString(R.string.main_tab_home)
            }
            navController.navigate(nav)
            item.title = title

            // Also emit tab change in NavRepo
            lifecycleScope.launch {
                val tab = when(item.itemId) {
                    R.id.navigation_flutterstats -> Tab.Activity
                    R.id.advancedFragment -> Tab.Advanced
                    R.id.navigation_settings -> Tab.Settings
                    else -> Tab.Home
                }
                navRepo.setActiveTab(tab)
            }

            true
        }
        navView.setOnNavigationItemSelectedListener(selectionListener)

        // Needed for dynamic translation of the top bar
        navController.addOnDestinationChangedListener { controller, destination, arguments ->
            Logger.v("Navigation", destination.toString())

            val translationId = when (destination.id) {
                R.id.navigation_flutterstats -> R.string.main_tab_activity
                R.id.activityDetailFragment -> R.string.main_tab_activity
                R.id.navigation_packs -> getString(R.string.advanced_section_header_packs)
                R.id.packDetailFragment -> R.string.advanced_section_header_packs
                R.id.advancedFragment -> R.string.main_tab_advanced
                R.id.userDeniedFragment -> R.string.userdenied_section_header
                R.id.settingsNetworksFragment -> R.string.networks_section_header
                R.id.networksDetailFragment -> R.string.networks_section_header
                R.id.appsFragment -> R.string.apps_section_header
                R.id.navigation_settings -> R.string.main_tab_settings
                R.id.navigation_settings_account -> R.string.account_action_my_account
                R.id.settingsLogoutFragment -> R.string.account_header_logout
                R.id.settingsAppFragment -> R.string.app_settings_section_header
                R.id.leasesFragment -> R.string.account_action_devices
                R.id.retentionFragment -> R.string.activity_section_header
                else -> null
            }
            toolbar.title = translationId?.let {
                if (it is Int) getString(it)
                else it.toString()
            } ?: run { toolbar.title }
        }

        flutter.setup()

        intent?.let {
            handleIntent(it)
        }
    }

    private fun setupEvents() {
        accountVM = ViewModelProvider(app()).get(AccountViewModel::class.java)
        tunnelVM = ViewModelProvider(app()).get(TunnelViewModel::class.java)
        settingsVM = ViewModelProvider(app()).get(SettingsViewModel::class.java)
        statsVM = ViewModelProvider(app()).get(StatsViewModel::class.java)
        blockaRepoVM = ViewModelProvider(app()).get(BlockaRepoViewModel::class.java)
        activationVM = ViewModelProvider(app()).get(ActivationViewModel::class.java)

        var expiredDialogShown = false
        activationVM.state.observe(this, Observer { state ->
            when (state) {
                ActivationViewModel.ActivationState.JUST_PURCHASED -> {
                    accountVM.refreshAccount()
                    val nav = findNavController(R.id.nav_host_fragment)
                    nav.navigateUp()
                }
                ActivationViewModel.ActivationState.JUST_ACTIVATED -> {
                    expiredDialogShown = false
                    val fragment = ActivatedFragment.newInstance()
                    fragment.show(supportFragmentManager, null)
                }
                ActivationViewModel.ActivationState.JUST_EXPIRED -> {
                    if (!expiredDialogShown) {
                        expiredDialogShown = true
                        NotificationService.show(ExpiredNotification())
                        AlertDialogService.showAlert(getString(R.string.notification_acc_body),
                            title = getString(R.string.notification_acc_header),
                            onDismiss = {
                                lifecycleScope.launch {
                                    activationVM.setInformedUserAboutExpiration()
                                    NotificationService.cancel(ExpiredNotification())
                                    tunnelVM.clearLease()
                                    //accountVM.refreshAccount()
                                }
                            })
                    }
                }
                else -> {}
            }
        })

        // A separate global-lifecycle observer to make sure expiration alarm is handled also in bg
        activationVM.state.observeForever { state ->
            when (state) {
                ActivationViewModel.ActivationState.EXPIRING -> {
                    accountVM.refreshAccount()
                }
                ActivationViewModel.ActivationState.JUST_EXPIRED -> {
                    Logger.v("Main", "Showing expired notification in bg")
                    NotificationService.show(ExpiredNotification())
                }
                else -> {}
            }
        }

        accountVM.accountExpiration.observeForever { activeUntil ->
            //val justBeforeExpired = Date(activeUntil.time - 30 * 1000)
            activationVM.setExpiration(activeUntil)
        }

        tunnelVM.tunnelStatus.observe(this, Observer { status ->
            if (status.active) {
                val firstTime = !(settingsVM.syncableConfig.value?.notFirstRun ?: true)
                if (firstTime) {
                    settingsVM.setFirstTimeSeen()
                    val fragment = FirstTimeFragment.newInstance()
                    fragment.show(supportFragmentManager, null)
                }
            }
        })

        lifecycleScope.launch {
            Repos.account.hackyAccount()
            onPaymentSuccessful_UpdateAccount()
        }
    }

    private suspend fun onPaymentSuccessful_UpdateAccount() {
        paymentRepo.successfulPurchasesHot
        .collect {
            Logger.v("Payment", "Received account after payment")
            accountVM.restoreAccount(it.first.id)
            if (it.first.isActive()) {
                delay(1000)
                sheet.showSheet(Sheet.Activated)
            }
        }
    }

    private fun setInsets(toolbar: Toolbar) {
        val root = findViewById<ViewGroup>(R.id.container)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, windowInsets ->
            val insets = windowInsets.getInsets(WindowInsetsCompat.Type.systemBars())
            topInset = insets.top

            // Apply the insets as a margin to the view. Here the system is setting
            // only the bottom, left, and right dimensions, but apply whichever insets are
            // appropriate to your layout. You can also update the view padding
            // if that's more appropriate.
            view.layoutParams =  (view.layoutParams as FrameLayout.LayoutParams).apply {
                leftMargin = insets.left
                bottomMargin = insets.bottom
                rightMargin = insets.right
            }

            // Also move down the toolbar
            toolbar.layoutParams = (toolbar.layoutParams as FrameLayout.LayoutParams).apply {
                topMargin = insets.top
            }

            // Return CONSUMED if you don't want want the window insets to keep being
            // passed down to descendant views.
            WindowInsetsCompat.CONSUMED
        }
        setupKeyboardMonitoring(root)
    }

    private var topInset = 0
    private val actionBarHeight: Int
        get() = theme.obtainStyledAttributes(intArrayOf(android.R.attr.actionBarSize))
        .let { attrs -> attrs.getDimension(0, 0F).toInt().also { attrs.recycle() } }

    private fun setFragmentInset(fragment: ViewGroup, shouldInset: Boolean) {
        fragment.layoutParams = (fragment.layoutParams as LinearLayout.LayoutParams).apply {
            topMargin = if (shouldInset) topInset + actionBarHeight else 0
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        lifecycleScope.launch {
            delay(1000) // So user sees the transition
            intent.extras?.getString(ACTION)?.let { action ->
                when (action) {
                    ACC_MANAGE -> {
                        accountVM.account.value?.let { account ->
                            Logger.w("MainActivity", "Navigating to account manage screen")
                            val nav = findNavController(R.id.nav_host_fragment)
                            nav.navigate(R.id.navigation_home)
                            nav.navigate(
                                HomeFragmentDirections.actionNavigationHomeToWebFragment(
                                    Links.manageSubscriptions(account.id), getString(R.string.universal_action_upgrade)
                                ))
                        } ?: Logger.e("MainActivity", "No account while received action $ACC_MANAGE")
                    }
                    else -> {
                        Logger.w("MainActivity", "Received unknown intent: $action")
                    }
                }
            }
        }
    }

    private var lastOnResume = 0L
    override fun onResume() {
        super.onResume()
        Repos.stage.onForeground()

        // Avoid multiple consecutive quick onResume events
        if (lastOnResume + 5 * 1000 > now()) return
        lastOnResume = now()

        Logger.w("MainActivity", "onResume: $this")
        tunnelVM.refreshStatus()
        blockaRepoVM.maybeRefreshRepo()
        lifecycleScope.launch {
            statsVM.refresh()
        }

        accountVM.maybeRefreshAccount()
        maybeInformAboutMigration()
        maybeInformAboutBadDnsProfileConfig()
    }

    override fun onPause() {
        Logger.w("MainActivity", "onPause: $this")
        super.onPause()
        Repos.stage.onBackground()
        tunnelVM.goToBackground()
    }

    override fun onDestroy() {
        Logger.w("MainActivity", "onDestroy: $this")
        super.onDestroy()
        Repos.stage.onDestroy()
    }

    /**
     * Will show the migration prompt to open our new listing. This will only happen in Slim build,
     * which is being phased out, as it's been cut down by Google severely. The dialog will show:
     * - only once per app lifetime (eg need to kill to show again)
     * - after 5 seconds from foreground event
     * - only if Slim was escaped
     */
    private var informed = false
    private fun maybeInformAboutMigration() {
        if (!informed && EnvironmentService.isSlim(ignoreEscape = true)) {
            lifecycleScope.launch {
                delay(5000)
                val stage = Repos.stage.stageHot.first()
                if (stage == AppStage.Foreground && EnvironmentService.escaped) {
                    Logger.w("Main", "Displaying Slim migration prompt")
                    informed = true
                    dialog.showAlert(
                        message = "This version of Blokada has been banned by Google. We have released a better version on PlayStore that we recommend. Please visit blokada.org for other install options.",
                        header = getString(R.string.alert_error_header),
                        okText = getString(R.string.universal_action_continue),
                        okAction = {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://go.blokada.org/play_cloud_migrate")));
                        }
                    )
                    .collect {  }
                }
            }
        }
    }

    /**
     * Will show a dialog prompt that the private DNS system setting is incorrect.
     * This is important because it will cause lack of connectivity without a clear
     * information on what is wrong. This only applies to Libre as in Cloud its handled
     * by the onboarding flow.
      */
    private fun maybeInformAboutBadDnsProfileConfig() {
        lifecycleScope.launch {
            delay(2000)
            val dns = Repos.cloud.dnsProfileConfiguredHot.first()
            if (EnvironmentService.isLibre() && dns == PrivateDnsConfigured.INCORRECT) {
                Logger.w("Main", "Displaying bad private DNS prompt")
                dialog.showAlert(
                    message = "Your Private DNS setting is set. This may cause connectivity issues. Please turn it off in Settings.",
                    header = getString(R.string.alert_error_header),
                    okText = getString(R.string.dnsprofile_action_open_settings),
                    okAction = {
                        SystemNavService.openNetworkSettings()
                    }
                )
                .collect {  }
            }
        }
    }

    override fun onSupportNavigateUp(): Boolean {
        if (WebService.goBack()) return true
        val navController = findNavController(R.id.nav_host_fragment)
        return navController.navigateUp()
    }

    override fun onBackPressed() {
        if (WebService.goBack()) return
        super.onBackPressed()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        VpnPermissionService.resultReturned(resultCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        NetworkMonitorPermissionService.resultReturned(grantResults)
    }

    override fun onPreferenceStartFragment(caller: PreferenceFragmentCompat, pref: Preference): Boolean {
        val navController = findNavController(R.id.nav_host_fragment)
        SettingsNavigation.handle(this, navController, pref.key, accountVM.account.value)
        return true
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        val inflater = menuInflater
        inflater.inflate(R.menu.help_menu, menu)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        when (item.itemId) {
            R.id.help_help -> {
                val fragment = HelpFragment.newInstance()
                fragment.show(supportFragmentManager, null)
            }
            R.id.help_logs -> LogService.showLog()
            R.id.help_sharelog -> LogService.shareLog()
            R.id.help_marklog -> LogService.markLog()
            R.id.help_settings -> {
                val nav = findNavController(R.id.nav_host_fragment)
                nav.navigate(R.id.navigation_settings)
//                nav.navigate(
//                    SettingsFragmentDirections.actionNavigationSettingsToSettingsAppFragment()
//                )
            }
//            R.id.help_debug -> AlertDialogService.showChoiceAlert(
//                choices = listOf(
//                    "> Test app crash (it should restart)" to {
//                        throw BlokadaException("This is a test of a fatal crash")
//                    }
//                ),
//                title = "Debug Tools"
//            )
            else -> return false
        }
        return true
    }

    companion object {
        val ACTION = "action"
    }

    // A snipped to detect if keyboard is open and adjust content (just Android things)
    private var isKeyboardShowing = false
    private var contentHeight = 0
    private fun setupKeyboardMonitoring(contentView: View) {
        contentView.viewTreeObserver.addOnGlobalLayoutListener {
            val r = Rect()
            contentView.getWindowVisibleDisplayFrame(r)
            val screenHeight = contentView.rootView.height

            // r.bottom is the position above soft keypad or device button.
            // if keypad is shown, the r.bottom is smaller than that before.
            val keypadHeight = screenHeight - r.bottom

            if (keypadHeight > screenHeight * 0.15) { // 0.15 ratio is perhaps enough to determine keypad height.
                // keyboard is opened
                if (!isKeyboardShowing) {
                    isKeyboardShowing = true
                    val params = contentView.layoutParams as FrameLayout.LayoutParams
                    contentHeight = params.height
                    params.height = screenHeight - keypadHeight
                    contentView.layoutParams = params
                }
            }
            else {
                // keyboard is closed
                if (isKeyboardShowing) {
                    isKeyboardShowing = false
                    val params = contentView.layoutParams as FrameLayout.LayoutParams
                    params.height = contentHeight
                    contentView.layoutParams = params
                }
            }
        }
    }

}