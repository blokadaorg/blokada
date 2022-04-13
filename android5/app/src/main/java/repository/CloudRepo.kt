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
import model.Granted
import service.BlockaApiForCurrentUserService
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

    private val writeDeviceInfo = MutableStateFlow<DevicePayload?>(null)
    private val writeDnsProfileActivated = MutableStateFlow<Granted?>(null)
    private val writePrivateDnsSetting = MutableStateFlow<String?>(null)

    val deviceInfoHot = writeDeviceInfo.filterNotNull().distinctUntilChanged()

    val expectedDnsStringHot = deviceInfoHot.map {
        // TODO: better sanitize device name
        val deviceName = env.getDeviceAlias().replace(" ", "--")
        val tag = it.device_tag
        "$deviceName-$tag.cloud.blokada.org"
    }

    val dnsProfileActivatedHot = writeDnsProfileActivated.filterNotNull().distinctUntilChanged()

    val deviceTagHot = deviceInfoHot.map { it.device_tag }.distinctUntilChanged()
    val blocklistsHot = deviceInfoHot.map { it.lists }.distinctUntilChanged()
    val activityRetentionHot = deviceInfoHot.map { it.retention }.distinctUntilChanged()
    val adblockingPausedHot = deviceInfoHot.map { it.paused }.distinctUntilChanged()

    private val refreshDeviceInfoT = SimpleTasker<Ignored>("refreshDeviceInfo", debounce = 500, errorIsMajor = true)
    private val setActivityRetentionT = Tasker<CloudActivityRetention, Ignored>("setActivityRetention")
    private val setBlocklistsT = Tasker<CloudBlocklists, Ignored>("setBlocklists")
    private val setPausedT = Tasker<Boolean, Ignored>("setPaused", errorIsMajor = true)

    open fun start() {
        GlobalScope.launch { onRefreshDeviceInfo() }
        GlobalScope.launch { onSetActivityRetention() }
        GlobalScope.launch { onSetBlocklists() }
        GlobalScope.launch { onSetPaused() }

        GlobalScope.launch { onTabChange_refreshDeviceInfo() }
        GlobalScope.launch { onAccountIdChanged_refreshDeviceInfo() }
        GlobalScope.launch { onPrivateDnsProfileChanged_update() }

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

    private suspend fun onRefreshDeviceInfo() {
        refreshDeviceInfoT.setTask {
            writeDeviceInfo.value = api.getDeviceForCurrentUser()
            true
        }
    }

    private suspend fun onSetActivityRetention() {
        setActivityRetentionT.setTask {
            api.putActivityRetentionForCurrentUser(it)
            refreshDeviceInfoT.send()
        }
    }

    private suspend fun onSetPaused() {
        setPausedT.setTask {
            api.putPausedForCurrentUser(it)
            refreshDeviceInfoT.send()
        }
    }

    private suspend fun onSetBlocklists() {
        setBlocklistsT.setTask {
            api.putBlocklistsForCurrentUser(it)
            refreshDeviceInfoT.send()
        }
    }

    // Will recheck device info on each tab change.
    // This struct contains something important for each tab.
    // Entering foreground will also re-publish active tab even if user doesn't change it.
    private suspend fun onTabChange_refreshDeviceInfo() {
        activeTabHot
        .collect {
            refreshDeviceInfoT.send()
        }
    }

    // Whenever account ID is changed, device tag will change, among other things.
    private suspend fun onAccountIdChanged_refreshDeviceInfo() {
        accountIdHot
        .collect {
            refreshDeviceInfoT.send()
        }
    }

    private suspend fun onPrivateDnsProfileChanged_update() {
        expectedDnsStringHot
        .combine(writePrivateDnsSetting) { setting, expected -> setting == expected }
        .collect { writeDnsProfileActivated.value = it }
    }

    private fun onPrivateDnsSettingChanged_update() {
        connectivity.onPrivateDnsChanged = {
            writePrivateDnsSetting.value = it
        }
        // First check has to happen manually
        writePrivateDnsSetting.value = connectivity.privateDns
    }

}

class DebugCloudRepo: CloudRepo() {

    override fun start() {
        super.start()

        GlobalScope.launch { printDnsProfAct() }
        GlobalScope.launch { printDeviceInfo() }
    }

    private suspend fun printDnsProfAct() {
        dnsProfileActivatedHot
        .collect {
            Logger.v("Cloud", "dnsProfileActivated: $it")
        }
    }

    private suspend fun printDeviceInfo() {
        deviceInfoHot
        .collect {
            Logger.v("Cloud", "deviceInfo: $it")
        }
    }

}