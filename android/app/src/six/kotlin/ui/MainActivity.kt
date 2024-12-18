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
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.Toolbar
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.preference.Preference
import androidx.preference.PreferenceFragmentCompat
import binding.AccountBinding
import binding.AccountPaymentBinding
import binding.CommandBinding
import binding.RateBinding
import binding.StageBinding
import channel.command.CommandName
import com.google.android.play.core.review.ReviewManagerFactory
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.blokada.R
import repository.Repos
import service.ContextService
import service.FlutterService
import service.NetworkMonitorPermissionService
import service.Sheet
import service.SheetService
import service.TranslationService
import service.VpnPermissionService
import ui.advanced.decks.PacksFragment
import ui.home.FlutterHomeFragment
import ui.home.HelpFragment
import ui.journal.JournalFragment
import ui.settings.SettingsFragment
import ui.utils.now
import ui.web.WebService
import utils.Links
import utils.Logger


class MainActivity : AppCompatActivity(), PreferenceFragmentCompat.OnPreferenceStartFragmentCallback {

    private lateinit var settingsVM: SettingsViewModel
    private lateinit var blockaRepoVM: BlockaRepoViewModel

    private val processingRepo by lazy { Repos.processing }

    private val stage by lazy { StageBinding }
    private val rate by lazy { RateBinding }
    private val account by lazy { AccountBinding }
    private val payment by lazy { AccountPaymentBinding }
    private val commands by lazy { CommandBinding }
    private val sheet by lazy { SheetService }
    private val context by lazy { ContextService }
    private val flutter by lazy { FlutterService }

    private val tabHome by lazy { FlutterHomeFragment() }
    private val tabActivity by lazy { JournalFragment() }
    private val tabAdvanced by lazy { PacksFragment() }
    private val tabSettings by lazy { SettingsFragment() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Didnt work for me
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.decorView.systemGestureExclusionRects = emptyList() // Disable system gesture interception
        }

//        // Intercept the back press
//        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
//            override fun handleOnBackPressed() {
//                flutter.engine.navigationChannel.popRoute()
//            }
//        })

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
                    mainIssuesOverlay.visibility = View.VISIBLE
                    mainIssuesOverlay.animate().translationY(0.0f)
                } else {
                    mainIssuesOverlay.animate().translationY(200.0f).withEndAction {
                        mainIssuesOverlay.visibility = View.GONE
                    }
                }
            }
        }

        intent?.let {
            handleIntent(it)
        }

        supportFragmentManager.beginTransaction()
            .replace(R.id.container_fragment, FlutterHomeFragment())
            .commit()
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

//        tunnelVM.refreshStatus()
        blockaRepoVM.maybeRefreshRepo()

        lifecycleScope.launch {
            payment.verifyWaitingPurchases()
        }
    }

    override fun onPause() {
        stage.setBackground()
//        tunnelVM.goToBackground()
        super.onPause()
    }

    override fun onDestroy() {
        context.unsetActivityContext()
        super.onDestroy()
    }

    override fun onSupportNavigateUp(): Boolean {
        if (WebService.goBack()) return true
        return stage.goBack()
    }

    override fun onBackPressed() {
        if (WebService.goBack()) return
        if (stage.goBack()) return
        lifecycleScope.launch {
            commands.execute(CommandName.BACK)
        }
        return
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
        val path = when (pref.key) {
            "main_account" -> "settings/account"
            "main_logout" -> "settings/logout"
            "main_leases" -> "settings/leases"
            "main_retention" -> "settings/retention"
            "main_app" -> "settings/app"
            "main_kb" -> Links.kb
            "main_donate" -> Links.donate
            "main_community" -> Links.community
            "main_support" -> account.account.value?.id?.let { Links.support(it) }
            "main_about" -> Links.credits
            "account_subscription_manage" -> null
            "account_help_why" -> Links.whyUpgrade
            "logout_howtorestore" -> Links.howToRestore
            "logout_support" -> account.account.value?.id?.let { Links.support(it) }
            else -> null
        }

        when {
            path != null -> stage.setRoute(path)
            pref.key == "account_subscription_manage" -> {
                val intent = Intent(Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/account/subscriptions"))
                startActivity(intent)
            }
        }
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
            R.id.help_settings -> {
//                val nav = findNavController(R.id.nav_host_fragment)
//                nav.navigate(R.id.navigation_settings)



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