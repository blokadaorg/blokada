/*
 * Copyright © 2017-2021 WireGuard LLC. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

package com.wireguard.android.util

import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import ui.MainApplication

object UserKnobs {
    private val ENABLE_KERNEL_MODULE = booleanPreferencesKey("enable_kernel_module")
    val enableKernelModule: Flow<Boolean>
        get() = MainApplication.getPreferencesDataStore().data.map {
            it[ENABLE_KERNEL_MODULE] ?: false
        }

    suspend fun setEnableKernelModule(enable: Boolean?) {
        MainApplication.getPreferencesDataStore().edit {
            if (enable == null)
                it.remove(ENABLE_KERNEL_MODULE)
            else
                it[ENABLE_KERNEL_MODULE] = enable
        }
    }

    private val MULTIPLE_TUNNELS = booleanPreferencesKey("multiple_tunnels")
    val multipleTunnels: Flow<Boolean>
        get() = MainApplication.getPreferencesDataStore().data.map {
            it[MULTIPLE_TUNNELS] ?: false
        }

    private val DARK_THEME = booleanPreferencesKey("dark_theme")
    val darkTheme: Flow<Boolean>
        get() = MainApplication.getPreferencesDataStore().data.map {
            it[DARK_THEME] ?: false
        }

    private val ALLOW_REMOTE_CONTROL_INTENTS = booleanPreferencesKey("allow_remote_control_intents")
    val allowRemoteControlIntents: Flow<Boolean>
        get() = MainApplication.getPreferencesDataStore().data.map {
            it[ALLOW_REMOTE_CONTROL_INTENTS] ?: false
        }

    private val RESTORE_ON_BOOT = booleanPreferencesKey("restore_on_boot")
    val restoreOnBoot: Flow<Boolean>
        get() = MainApplication.getPreferencesDataStore().data.map {
            it[RESTORE_ON_BOOT] ?: false
        }

    private val LAST_USED_TUNNEL = stringPreferencesKey("last_used_tunnel")
    val lastUsedTunnel: Flow<String?>
        get() = MainApplication.getPreferencesDataStore().data.map {
            it[LAST_USED_TUNNEL]
        }

    suspend fun setLastUsedTunnel(lastUsedTunnel: String?) {
        MainApplication.getPreferencesDataStore().edit {
            if (lastUsedTunnel == null)
                it.remove(LAST_USED_TUNNEL)
            else
                it[LAST_USED_TUNNEL] = lastUsedTunnel
        }
    }

    private val RUNNING_TUNNELS = stringSetPreferencesKey("enabled_configs")
    val runningTunnels: Flow<Set<String>>
        get() = MainApplication.getPreferencesDataStore().data.map {
            it[RUNNING_TUNNELS] ?: emptySet()
        }

    suspend fun setRunningTunnels(runningTunnels: Set<String>) {
        MainApplication.getPreferencesDataStore().edit {
            if (runningTunnels.isEmpty())
                it.remove(RUNNING_TUNNELS)
            else
                it[RUNNING_TUNNELS] = runningTunnels
        }
    }
}
