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

package ui.settings

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.ListView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import androidx.preference.Preference
import androidx.preference.PreferenceFragmentCompat
import binding.StageBinding
import org.blokada.R
import repository.LANGUAGE_NICE_NAMES
import service.EnvironmentService
import service.UpdateService
import ui.BlockaRepoViewModel
import ui.SettingsViewModel
import ui.app
import utils.Links

class SettingsAppFragment : PreferenceFragmentCompat() {

    private lateinit var vm: SettingsViewModel
    private lateinit var blockaRepoVM: BlockaRepoViewModel
    private val stage by lazy { StageBinding }

    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        setPreferencesFromResource(R.xml.settings_app, rootKey)
    }

    override fun onActivityCreated(savedInstanceState: Bundle?) {
        super.onActivityCreated(savedInstanceState)

        activity?.let {
            vm = ViewModelProvider(it.app()).get(SettingsViewModel::class.java)
            blockaRepoVM = ViewModelProvider(it.app()).get(BlockaRepoViewModel::class.java)
        }

        val language: Preference = findPreference("app_language")!!
        val languages = mutableMapOf(
            "root" to getString(R.string.app_settings_status_default)
        ).also {
            it.putAll(LANGUAGE_NICE_NAMES.toSortedMap())
        }
        language.setOnPreferenceClickListener { _ ->
            showSingleChoiceDialog(
                requireContext(), getString(R.string.app_settings_language_label),
                languages, vm.localConfig.value?.locale ?: "root"
            ) { newValue ->
                when (newValue) {
                    "root" -> vm.setLocale(null)
                    else -> vm.setLocale(newValue)
                }
            }
            true
        }

        val theme: Preference = findPreference("app_theme")!!
        val themes = mapOf(
            "default" to getString(R.string.app_settings_status_default),
            "dark" to getString(R.string.app_settings_theme_dark),
            "light" to getString(R.string.app_settings_theme_light),
        )
        theme.setOnPreferenceClickListener { _ ->
            val value = when (vm.localConfig.value?.useDarkTheme) {
                true -> "dark"
                false -> "light"
                else -> "default"
            }
            showSingleChoiceDialog(
                requireContext(), getString(R.string.app_settings_theme_label),
                themes, value
            ) { newValue ->
                when (newValue) {
                    "dark" -> vm.setUseDarkTheme(true)
                    "light" -> vm.setUseDarkTheme(false)
                    else -> vm.setUseDarkTheme(null)
                }
                showRestartRequired()
            }
            true
        }

        val browser: Preference = findPreference("app_browser")!!
        val browsers = mapOf(
            "internal" to getString(R.string.app_settings_browser_internal),
            "external" to getString(R.string.app_settings_browser_external)
        )
        browser.setOnPreferenceClickListener { _ ->
            val value = if (vm.localConfig.value?.useChromeTabs == true) "external" else "internal"
            showSingleChoiceDialog(
                requireContext(), getString(R.string.app_settings_browser_label),
                browsers, value
            ) { newValue ->
                when (newValue) {
                    "internal" -> vm.setUseChromeTabs(false)
                    else -> vm.setUseChromeTabs(true)
                }
            }
            true
        }

        val yesNoChoice = mapOf(
            "yes" to getString(R.string.universal_action_yes),
            "no" to getString(R.string.universal_action_no)
        )

        val backup: Preference? = findPreference("app_backup")
        backup?.let { backup ->
            backup.setOnPreferenceClickListener { _ ->
                val value = if (vm.localConfig.value?.backup == true) "yes" else "no"
                showSingleChoiceDialog(
                    requireContext(), getString(R.string.app_settings_backup),
                    yesNoChoice, value
                ) { newValue ->
                    when (newValue) {
                        "yes" -> vm.setUseBackup(true)
                        else -> vm.setUseBackup(false)
                    }
                }
                showRestartRequired()
                true
            }
        }

        val useForeground: Preference = findPreference("app_useforeground")!!
        useForeground.setOnPreferenceClickListener { _ ->
            val value = if (vm.localConfig.value?.useForegroundService == true) "yes" else "no"
            showSingleChoiceDialog(
                requireContext(), getString(R.string.app_settings_section_use_foreground),
                yesNoChoice, value
            ) { newValue ->
                when (newValue) {
                    "yes" -> vm.setUseForegroundService(true)
                    else -> vm.setUseForegroundService(false)
                }
            }
            showRestartRequired()
            true
        }

        val details: Preference = findPreference("app_details")!!
        details.summary = EnvironmentService.getUserAgent()

        var clicks = 0
        details.setOnPreferenceClickListener {
            if (clicks++ == 21) {
                vm.setRatedApp()
                Toast.makeText(requireContext(), "( ͡° ͜ʖ ͡°)", Toast.LENGTH_SHORT).show()
            }
            true
        }

        vm.localConfig.observe(viewLifecycleOwner, Observer {
            val locale = it.locale
            val selected = locale ?: "root"
            language.setDefaultValue(selected)
        })

        val config: Preference = findPreference("app_config")!!
        config.setOnPreferenceClickListener {
            UpdateService.resetSeenUpdate()
            blockaRepoVM.refreshRepo()
            true
        }

        blockaRepoVM.repoConfig.observe(viewLifecycleOwner, Observer {
            config.summary = it.name
        })

        val boot: Preference = findPreference("app_startonboot")!!
        boot.setOnPreferenceClickListener {
            stage.setRoute(Links.startOnBoot)
            true
        }

        val info: Preference = findPreference("app_info")!!
        info.setOnPreferenceClickListener {
            val ctx = requireContext()
            ctx.startActivity(getIntentForAppInfo(ctx))
            true
        }

        val vpn: Preference = findPreference("app_vpn")!!
        vpn.setOnPreferenceClickListener {
            val ctx = requireContext()
            ctx.startActivity(getIntentForVpnProfile(ctx))
            true
        }

        val notification: Preference = findPreference("app_notifications")!!
        notification.setOnPreferenceClickListener {
            val ctx = requireContext()
            ctx.startActivity(getIntentForNotificationChannelsSettings(ctx))
            true
        }
    }

    private fun showRestartRequired() {
        Toast.makeText(requireContext(), getString(R.string.universal_status_restart_required), Toast.LENGTH_LONG).show()
    }

    private fun getIntentForVpnProfile(ctx: Context) = Intent().apply {
        action = "android.net.vpn.SETTINGS"
        flags = Intent.FLAG_ACTIVITY_NEW_TASK
    }

    fun getIntentForNotificationChannelsSettings(ctx: Context) = Intent().apply {
        action = "android.settings.APP_NOTIFICATION_SETTINGS"
        flags = Intent.FLAG_ACTIVITY_NEW_TASK
        putExtra("app_package", ctx.packageName)
        putExtra("app_uid", ctx.applicationInfo.uid)
        putExtra("android.provider.extra.APP_PACKAGE", ctx.packageName)
    }

    private fun showSingleChoiceDialog(
        context: Context, title: String,
       items: Map<String, String>, selected: String?, onItemSelected: (String) -> Unit
    ) {
        val builder = AlertDialog.Builder(context)
        builder.setTitle(title)

        val values = items.entries.toTypedArray().associateWith { item ->
            if (item.key == selected) getString(R.string.universal_action_selected) else ""
        }.map { it.key.value to it.value }.toList()

        val listView = ListView(requireContext())
        val adapter = object : ArrayAdapter<Pair<String, String>>(requireContext(),
            R.layout.item_setting, R.id.settings_name, values) {
            override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                val view = super.getView(position, convertView, parent)
                val text1 = view.findViewById<TextView>(R.id.settings_name)
                val sel1 = view.findViewById<View>(R.id.settings_selected)
                val sel2 = view.findViewById<View>(R.id.settings_selected_text)

                val item = getItem(position)
                text1.text = item?.first

                if (item?.second?.isNotEmpty() == true) {
                    sel1.visibility = View.VISIBLE
                    sel2.visibility = View.VISIBLE
                } else {
                    sel1.visibility = View.GONE
                    sel2.visibility = View.GONE
                }

                return view
            }
        }

        listView.adapter = adapter

        builder.setView(listView)

        builder.setNegativeButton(getString(R.string.universal_action_cancel), null)

        val dialog = builder.create()

        listView.setOnItemClickListener { _, _, position, _ ->
            onItemSelected(items.keys.toTypedArray()[position])
            dialog.dismiss()
        }
        dialog.show()
    }
}

fun getIntentForAppInfo(ctx: Context) = Intent().apply {
    action = android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS
    data = Uri.parse("package:${ctx.packageName}")
    flags = Intent.FLAG_ACTIVITY_NEW_TASK
}

