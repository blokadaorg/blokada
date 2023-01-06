/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package repository

import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import model.CloudActivityRetention
import model.CloudBlocklists
import model.DevicePayload
import model.PrivateDnsConfigured
import service.ConnectivityService
import service.EnvironmentService
import service.Services
import utils.Ignored
import utils.Logger
import utils.SimpleTasker
import utils.Tasker

open class CloudRepo {

    private val env by lazy { EnvironmentService }
    private val api by lazy { Services.apiForCurrentUser }
    private val connectivity by lazy { ConnectivityService }

    private val enteredForegroundHot by lazy { Repos.stage.enteredForegroundHot }
    private val accountIdHot by lazy { Repos.account.accountIdHot }
    private val activeTabHot by lazy { Repos.nav.activeTabHot }

    private val writeDeviceInfo = MutableSharedFlow<DevicePayload?>(replay = 1)
    private val writeDnsProfileActivated = MutableStateFlow<PrivateDnsConfigured?>(null)
    private val writePrivateDnsSetting = MutableStateFlow<String?>(null)

    val deviceInfoHot = writeDeviceInfo.filterNotNull()

    // Produces a hostname where the subdomain is unique to user and has a few properties:
    // - is max 63 chars length (56 for device name and the rest for the tag)
    // - is only ascii (unicode is normalized to ascii in EnvironmentService)
    // - spaces are replaces with two dashes
    // - device name won't end with a dash
    val expectedDnsStringHot = deviceInfoHot.map {
        val deviceName = env.getDeviceAlias().replace(" ", "--").take(56).trimEnd('-')
        val tag = it.device_tag
        "$deviceName-$tag.cloud.blokada.org"
    }

    val dnsProfileConfiguredHot = writeDnsProfileActivated.filterNotNull().distinctUntilChanged()
    val dnsProfileActivatedHot = dnsProfileConfiguredHot.map { it == PrivateDnsConfigured.CORRECT }

    val deviceTagHot = deviceInfoHot.map { it.device_tag }.distinctUntilChanged()
    val blocklistsHot = deviceInfoHot.map { it.lists }.distinctUntilChanged()
    val activityRetentionHot = deviceInfoHot.map { it.retention }
    val adblockingPausedHot = deviceInfoHot.map { it.paused }.distinctUntilChanged()

    private val refreshDeviceInfoT = SimpleTasker<Ignored>("refreshDeviceInfo", debounce = 500, errorIsMajor = false)
    private val setActivityRetentionT = Tasker<CloudActivityRetention, Ignored>("setActivityRetention")
    private val setBlocklistsT = Tasker<CloudBlocklists, Ignored>("setBlocklists")
    private val setPausedT = Tasker<Boolean, Ignored>("setPaused", errorIsMajor = true)

    open fun start() {
        onRefreshDeviceInfo()
        onSetActivityRetention()
        onSetBlocklists()
        onSetPaused()

        onTabChange_refreshDeviceInfo()
        onAccountIdChanged_refreshDeviceInfo()
        onPrivateDnsProfileChanged_update()
        onConnectedBack_refresh()
        onDeviceTag_setToEnv()

        onPrivateDnsSettingChanged_update()
    }

    suspend fun setActivityRetention(retention: CloudActivityRetention) {
        setActivityRetentionT.send(retention)
    }

    suspend fun setPaused(paused: Boolean) {
        setPausedT.send(paused)
    }

    suspend fun setBlocklists(lists: CloudBlocklists) {
        setBlocklistsT.send(lists)
    }

    private fun onRefreshDeviceInfo() {
        refreshDeviceInfoT.setTask {
            writeDeviceInfo.emit(api.getDeviceForCurrentUser())
            true
        }
    }

    private fun onSetActivityRetention() {
        setActivityRetentionT.setTask {
            api.putActivityRetentionForCurrentUser(it)
            refreshDeviceInfoT.get()
        }
    }

    private fun onSetPaused() {
        setPausedT.setTask {
            api.putPausedForCurrentUser(it)
            refreshDeviceInfoT.get()
        }
    }

    private fun onSetBlocklists() {
        setBlocklistsT.setTask {
            api.putBlocklistsForCurrentUser(it)
            refreshDeviceInfoT.get()
        }
    }

    // Will recheck device info on each tab change.
    // This struct contains something important for each tab.
    // Entering foreground will also re-publish active tab even if user doesn't change it.
    private fun onTabChange_refreshDeviceInfo() {
        GlobalScope.launch {
            activeTabHot
            .collect {
                refreshDeviceInfoT.send()
            }
        }
    }

    // Whenever account ID is changed, device tag will change, among other things.
    private fun onAccountIdChanged_refreshDeviceInfo() {
        GlobalScope.launch {
            accountIdHot
            .collect {
                refreshDeviceInfoT.send()
            }
        }
    }

    private fun onPrivateDnsProfileChanged_update() {
        GlobalScope.launch {
            expectedDnsStringHot
            .combine(writePrivateDnsSetting) { setting, expected -> setting to expected }
            .collect { writeDnsProfileActivated.value = when {
                it.first == it.second -> PrivateDnsConfigured.CORRECT
                it.second == null -> PrivateDnsConfigured.NONE
                else -> PrivateDnsConfigured.INCORRECT
            } }
        }
    }

    private fun onPrivateDnsSettingChanged_update() {
        connectivity.onPrivateDnsChanged = {
            writePrivateDnsSetting.value = it
        }
        // First check has to happen manually
        writePrivateDnsSetting.value = connectivity.privateDns
    }

    private fun onConnectedBack_refresh() {
        connectivity.onConnectedBack = {
            Logger.v("Cloud", "Connected back, refreshing device info")
            GlobalScope.launch { refreshDeviceInfoT.send() }
        }
    }

    private fun onDeviceTag_setToEnv() {
        GlobalScope.launch {
            deviceTagHot
            .collect {
                EnvironmentService.deviceTag = it
            }
        }
    }
}

class DebugCloudRepo: CloudRepo() {

    override fun start() {
        super.start()

        printDnsProfAct()
        printDeviceInfo()
    }

    private fun printDnsProfAct() {
        GlobalScope.launch {
            dnsProfileActivatedHot
            .collect {
                Logger.v("Cloud", "dnsProfileActivated: $it")
            }
        }
    }

    private fun printDeviceInfo() {
        GlobalScope.launch {
            deviceInfoHot
            .collect {
                Logger.v("Cloud", "deviceInfo: $it")
            }
        }
    }

}