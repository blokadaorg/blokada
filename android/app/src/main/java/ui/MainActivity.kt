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

import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.os.Bundle
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import androidx.appcompat.widget.Toolbar
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.navigation.findNavController
import androidx.navigation.ui.AppBarConfiguration
import androidx.navigation.ui.setupActionBarWithNavController
import androidx.navigation.ui.setupWithNavController
import androidx.preference.Preference
import androidx.preference.PreferenceFragmentCompat
import binding.AccountBinding
import binding.RateBinding
import binding.StageBinding
import com.akexorcist.localizationactivity.ui.LocalizationActivity
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.google.android.play.core.review.ReviewManagerFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import model.Tab
import org.blokada.R
import repository.Repos
import service.ContextService
import service.LogService
import service.NetworkMonitorPermissionService
import service.Sheet
import service.SheetService
import service.TranslationService
import service.VpnPermissionService
import ui.home.HelpFragment
import ui.settings.SettingsNavigation
import ui.utils.now
import ui.web.WebService
import utils.Logger


class MainActivity : LocalizationActivity(), PreferenceFragmentCompat.OnPreferenceStartFragmentCallback {

    private lateinit var settingsVM: SettingsViewModel
    private lateinit var blockaRepoVM: BlockaRepoViewModel

    private val processingRepo by lazy { Repos.processing }

    private val stage by lazy { StageBinding }
    private val rate by lazy { RateBinding }
    private val account by lazy { AccountBinding }
    private val sheet by lazy { SheetService }
    private val context by lazy { ContextService }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Logger.v("MainActivity", "onCreate: $this")

        settingsVM = ViewModelProvider(app()).get(SettingsViewModel::class.java)
        blockaRepoVM = ViewModelProvider(app()).get(BlockaRepoViewModel::class.java)

        WindowCompat.setDecorFitsSystemWindows(window, false)
        context.setActivityContext(this)
        TranslationService.setup()
        sheet.onShowFragment = { fragment ->
            fragment.show(supportFragmentManager, null)
        }
        sheet.onHideFragment = { fragment ->
            fragment.dismiss()
        }

        settingsVM.getTheme()?.let { setTheme(it) }

        setContentView(R.layout.activity_main)

        val navView: BottomNavigationView = findViewById(R.id.nav_view)
        val toolbar: Toolbar = findViewById(R.id.toolbar)
        val fragmentContainer: ViewGroup = findViewById(R.id.container_fragment)

        stage.onShowNavBar = { show ->
            navView.visibility = if (show) View.VISIBLE else View.GONE
        }

        rate.onShowRateDialog = { askForReview(this) }

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
                R.id.navigation_flutterhome,
                R.id.navigation_activity,
                R.id.navigation_packs,
                R.id.navigation_settings
            )
        )
        setupActionBarWithNavController(navController, appBarConfiguration)
        navView.setupWithNavController(navController)

        // Set the fragment inset as needed (home fragment has no inset)
        navController.addOnDestinationChangedListener { _, destination, _ ->
            val shouldInset = when (destination.id) {
                R.id.navigation_flutterhome -> false
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
                R.id.navigation_activity -> R.id.navigation_activity to getString(R.string.main_tab_activity)
                R.id.navigation_packs -> R.id.navigation_packs to getString(R.string.main_tab_advanced)
                R.id.navigation_settings -> R.id.navigation_settings to getString(R.string.main_tab_settings)
                else -> R.id.navigation_flutterhome to getString(R.string.main_tab_home)
            }
            navController.navigate(nav)
            item.title = title

            // Also emit tab change in NavRepo
            lifecycleScope.launch {
                val tab = when(item.itemId) {
                    R.id.navigation_activity -> Tab.Activity
                    R.id.navigation_packs -> Tab.Advanced
                    R.id.navigation_settings -> Tab.Settings
                    else -> Tab.Home
                }
                stage.setActiveTab(tab)
            }

            true
        }
        navView.setOnNavigationItemSelectedListener(selectionListener)

        // Needed for dynamic translation of the top bar
        navController.addOnDestinationChangedListener { controller, destination, arguments ->
            Logger.v("Navigation", destination.toString())

            val translationId = when (destination.id) {
                R.id.navigation_activity -> R.string.main_tab_activity
                R.id.activityDetailFragment -> R.string.main_tab_activity
                R.id.navigation_packs -> getString(R.string.advanced_section_header_packs)
                R.id.packDetailFragment -> R.string.advanced_section_header_packs
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

        intent?.let {
            handleIntent(it)
        }
    }

//    private fun setupEvents() {
//        tunnelVM.tunnelStatus.observe(this, Observer { status ->
//            if (status.active) {
//                val firstTime = !(settingsVM.syncableConfig.value?.notFirstRun ?: true)
//                if (firstTime) {
//                    settingsVM.setFirstTimeSeen()
//                    val fragment = FirstTimeFragment.newInstance()
//                    fragment.show(supportFragmentManager, null)
//                }
//            }
//        })
//    }


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
        stage.setForeground()

        // Avoid multiple consecutive quick onResume events
        if (lastOnResume + 5 * 1000 > now()) return
        lastOnResume = now()

        Logger.w("MainActivity", "onResume: $this")
//        tunnelVM.refreshStatus()
        blockaRepoVM.maybeRefreshRepo()
    }

    override fun onPause() {
        Logger.w("MainActivity", "onPause: $this")
        stage.setBackground()
//        tunnelVM.goToBackground()
        super.onPause()
    }

    override fun onDestroy() {
        Logger.w("MainActivity", "onDestroy: $this")
        context.unsetActivityContext()
        super.onDestroy()
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
        SettingsNavigation.handle(this, navController, pref.key, account.account.value)
        return true
    }

//    override fun onCreateOptionsMenu(menu: Menu): Boolean {
//        val inflater = menuInflater
//        inflater.inflate(R.menu.help_menu, menu)
//        return true
//    }

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

    private fun askForReview(context: Context) {
        val manager = ReviewManagerFactory.create(context)
        val request = manager.requestReviewFlow()
        request.addOnCompleteListener { request ->
            if (request.isSuccessful) {
                // We got the ReviewInfo object
                val reviewInfo = request.result
                val flow = manager.launchReviewFlow(this, reviewInfo)
                flow.addOnCompleteListener { _ ->
                    // The flow has finished. The API does not indicate whether the user
                    // reviewed or not, or even whether the review dialog was shown. Thus, no
                    // matter the result, we continue our app flow.
                }
            } else {
                // There was some problem, continue regardless of the result.
            }
        }
    }
}