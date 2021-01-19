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
import android.os.Bundle
import android.util.DisplayMetrics
import android.view.Menu
import android.view.MenuItem
import android.view.View
import androidx.appcompat.widget.Toolbar
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
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.blokada.R
import service.*
import ui.advanced.packs.PacksViewModel
import ui.home.ActivatedFragment
import ui.home.FirstTimeFragment
import ui.home.HelpFragment
import ui.home.HomeFragmentDirections
import ui.settings.SettingsFragmentDirections
import ui.settings.SettingsNavigation
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ContextService.setActivityContext(this)
        TranslationService.setup()
        setupEvents()

        settingsVM.getTheme()?.let { setTheme(it) }

        setContentView(R.layout.activity_main)

        val navView: BottomNavigationView = findViewById(R.id.nav_view)
        val toolbar: Toolbar = findViewById(R.id.toolbar)

        setSupportActionBar(toolbar)

        val navController = findNavController(R.id.nav_host_fragment)
        // Passing each menu ID as a set of Ids because each
        // menu should be considered as top level destinations.
        val appBarConfiguration = AppBarConfiguration(
            setOf(
                R.id.navigation_home,
                R.id.navigation_activity,
                R.id.advancedFragment,
                R.id.navigation_settings
            )
        )
        setupActionBarWithNavController(navController, appBarConfiguration)
        navView.setupWithNavController(navController)

        // Hide the bottom navigation bar, unless we are top level
        navController.addOnDestinationChangedListener { _, destination, _ ->
            val showNavBar = when (destination.id) {
                R.id.navigation_home -> true
                R.id.navigation_activity -> true
                R.id.advancedFragment -> true
                R.id.navigation_settings -> true
                else -> isScreenBigEnough()
            }
            navView.visibility = if (showNavBar) View.VISIBLE else View.GONE
        }

        // Needed for dynamic translation of the bottom bar
        val selectionListener = BottomNavigationView.OnNavigationItemSelectedListener { item ->
            val (nav, title) = when (item.itemId) {
                R.id.navigation_activity -> R.id.navigation_activity to getString(R.string.main_tab_activity)
                R.id.advancedFragment -> R.id.advancedFragment to getString(R.string.main_tab_advanced)
                R.id.navigation_settings -> R.id.navigation_settings to getString(R.string.main_tab_settings)
                else -> R.id.navigation_home to getString(R.string.main_tab_home)
            }
            navController.navigate(nav)
            item.title = title
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

    private fun setupEvents() {
        accountVM = ViewModelProvider(app()).get(AccountViewModel::class.java)
        tunnelVM = ViewModelProvider(app()).get(TunnelViewModel::class.java)
        settingsVM = ViewModelProvider(app()).get(SettingsViewModel::class.java)
        statsVM = ViewModelProvider(app()).get(StatsViewModel::class.java)
        blockaRepoVM = ViewModelProvider(app()).get(BlockaRepoViewModel::class.java)
        activationVM = ViewModelProvider(this).get(ActivationViewModel::class.java)

        var expiredDialogShown = false
        activationVM.state.observe(this, Observer { state ->
            when (state) {
                ActivationViewModel.ActivationState.JUST_PURCHASED -> {
                    accountVM.refreshAccount()
                    val nav = findNavController(R.id.nav_host_fragment)
                    nav.navigateUp()
                }
                ActivationViewModel.ActivationState.JUST_ACTIVATED -> {
                    val fragment = ActivatedFragment.newInstance()
                    fragment.show(supportFragmentManager, null)
                }
                ActivationViewModel.ActivationState.JUST_EXPIRED -> {
                    if (!expiredDialogShown) {
                        expiredDialogShown = true
                        AlertDialogService.showAlert(getString(R.string.error_vpn_expired),
                            title = getString(R.string.alert_vpn_expired_header),
                            onDismiss = {
                                lifecycleScope.launch {
                                    activationVM.setInformedUserAboutExpiration()
                                    NotificationService.cancel(ExpiredNotification())
                                    tunnelVM.clearLease()
                                    accountVM.refreshAccount()
                                }
                            })
                    }
                }
            }
        })

        accountVM.accountExpiration.observe(this, Observer { activeUntil ->
            activationVM.setExpiration(activeUntil)
        })

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
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        tunnelVM.refreshStatus()
        accountVM.checkAccount()
        blockaRepoVM.maybeRefreshRepo()
        lifecycleScope.launch {
            statsVM.refresh()
        }
    }

    override fun onPause() {
        super.onPause()
        tunnelVM.goToBackground()
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
        SettingsNavigation.handle(navController, pref.key, accountVM.account.value?.id)
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
            R.id.help_settings -> {
                val nav = findNavController(R.id.nav_host_fragment)
                nav.navigate(R.id.navigation_settings)
                nav.navigate(
                    SettingsFragmentDirections.actionNavigationSettingsToSettingsAppFragment()
                )
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

    private fun isScreenBigEnough(): Boolean {
        val displayMetrics = DisplayMetrics()
        windowManager.defaultDisplay.getMetrics(displayMetrics)
        return displayMetrics.heightPixels / displayMetrics.density > 650
    }

    companion object {
        val ACTION = "action"
    }

}