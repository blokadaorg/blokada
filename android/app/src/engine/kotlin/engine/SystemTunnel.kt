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

package engine

import android.content.Intent
import android.net.VpnService
import android.os.Binder
import android.os.IBinder
import android.os.ParcelFileDescriptor
import androidx.lifecycle.ViewModelProvider
import model.BlokadaException
import model.SystemTunnelRevoked
import service.ContextService
import ui.TunnelViewModel
import ui.app
import ui.utils.cause
import utils.Logger
import java.io.FileInputStream
import java.io.FileOutputStream

class SystemTunnel : VpnService() {

    private val log = Logger("SystemTunnel")

    private var binder: SystemTunnelBinder? = null
        @Synchronized get
        @Synchronized set

    private var config: SystemTunnelConfig? = null
        @Synchronized get
        @Synchronized set

    private var reactedToStart = false
        @Synchronized get
        @Synchronized set

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = {
        ContextService.setApp(this.application)
        log.v("onStartCommand received: $this, intent: $intent")

        if (!reactedToStart) {
            // System calls us twice in a row on boot
            reactedToStart = true

            // This might be a misuse
            val tunnelVM = ViewModelProvider(app()).get(TunnelViewModel::class.java)
            tunnelVM.turnOnWhenStartedBySystem()
        }

        START_STICKY
    }()

    override fun onBind(intent: Intent?): IBinder? {
        if (SYSTEM_TUNNEL_BINDER_ACTION == intent?.action) {
            log.v("onBind received: $this")
            binder = SystemTunnelBinder(this)
            return binder
        }
        return super.onBind(intent)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        if (SYSTEM_TUNNEL_BINDER_ACTION == intent?.action) {
            log.v("onUnbind received: $this")
            return true
        }
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        log.v("onDestroy received: $this")
        turnOff()
        binder { it.onTunnelClosed(null) }
        super.onDestroy()
    }

    override fun onRevoke() {
        log.w("onRevoke received: $this")
        turnOff()
        binder { it.onTunnelClosed(SystemTunnelRevoked()) }
        super.onRevoke()
    }

    fun queryConfig() = config

    fun turnOn(): SystemTunnelConfig {
        log.v("Tunnel turnOn() called")
        val tunnel = super.Builder()
        binder { it.onConfigureTunnel(tunnel) }
        log.v("Asking system for tunnel")
        val descriptor = tunnel.establish() ?: throw BlokadaException("Tunnel establish() returned no fd")
        val fd = descriptor.fileDescriptor
        val config = SystemTunnelConfig(descriptor, FileInputStream(fd), FileOutputStream(fd))
        this.config = config
        return config
    }

    fun turnOff() {
        log.v("Tunnel turnOff() called")
        config?.let { config ->
            log.v("Closing tunnel descriptors")
            try {
                config.fd.close()
                config.deviceIn.close()
                config.deviceOut.close()
            } catch (ex: Exception) {
                log.w("Could not close SystemTunnel descriptor".cause(ex))
            }
        }

        config = null
    }

    private fun binder(exec: (SystemTunnelBinder) -> Unit) {
        binder?.let(exec) ?: log.e("No binder attached: $this")
    }

}

class SystemTunnelConfig(
    val fd: ParcelFileDescriptor,
    val deviceIn: FileInputStream,
    val deviceOut: FileOutputStream
)

class SystemTunnelBinder(
    val tunnel: SystemTunnel,
    var onTunnelClosed: (exception: BlokadaException?) -> Unit = {},
    var onConfigureTunnel: (vpn: VpnService.Builder) -> Unit = {}
) : Binder()

const val SYSTEM_TUNNEL_BINDER_ACTION = "SystemTunnel"
