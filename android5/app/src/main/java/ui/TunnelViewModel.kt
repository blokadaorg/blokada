/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package ui

import androidx.lifecycle.*
import engine.EngineService
import kotlinx.coroutines.launch
import model.*
import service.*
import ui.utils.cause
import utils.Logger

/**
 * This class is responsible for managing the tunnel state and reflecting it on the UI.
 *
 * Mainly used in HomeFragment, but also affecting other parts, like Settings.
 * Warning, this class has the highest chance to be the bloated point of the app.
 */
class TunnelViewModel: ViewModel() {

    private val log = Logger("Blocka")
    private val persistence = PersistenceService
    private val engine = EngineService
    private val vpnPerm = VpnPermissionService
    private val lease = LeaseService

    private val _config = MutableLiveData<BlockaConfig>()
    val config: LiveData<BlockaConfig> = _config

    private val _tunnelStatus = MutableLiveData<TunnelStatus>()
    val tunnelStatus: LiveData<TunnelStatus> = _tunnelStatus.distinctUntilChanged()

    init {
        engine.onTunnelStoppedUnexpectedly = this::handleTunnelStoppedUnexpectedly
        engine.onTunnelStatusChanged = { status ->
            viewModelScope.launch { status.emit() }
        }
        viewModelScope.launch {
            val cfg = persistence.load(BlockaConfig::class)
            _config.value = cfg
            TunnelStatus.off().emit()

            if (cfg.tunnelEnabled) {
                log.w("Starting tunnel after app start, as it was active before")
                turnOnWhenStartedBySystem()
            }
        }
    }

    fun refreshStatus() {
        viewModelScope.launch {
            log.v("Querying tunnel status")
            engine.getTunnelStatus().emit()
            _config.value?.let {
                if (it.vpnEnabled) {
                    try {
                        lease.checkLease(it)
                    } catch (ex: Exception) {
                        log.e("Could not check lease when querying status".cause(ex))
                        clearLease()
                    }
                }
            }
        }
    }

    fun goToBackground() {
        viewModelScope.launch {
            engine.goToBackground()
        }
    }

    fun turnOn() {
        viewModelScope.launch {
            if (!vpnPerm.hasPermission()) {
                log.v("Requested to start tunnel, no VPN permissions")
                TunnelStatus.noPermissions().emit()
                TunnelStatus.off().emit()
            } else {
                log.v("Requested to start tunnel")
                val s = engine.getTunnelStatus()
                if (!s.inProgress && !s.active) {
                    try {
                        TunnelStatus.inProgress().emit()
                        val cfg = _config.value ?: throw BlokadaException("Config not set")
                        if (cfg.vpnEnabled) {
                            engine.startTunnel(cfg.lease)
                            engine.connectVpn(cfg)
                            lease.checkLease(cfg)
                        } else {
                            engine.startTunnel(null)
                        }
                        cfg.copy(tunnelEnabled = true).emit()
                        engine.getTunnelStatus().emit()
                        log.v("Tunnel started successfully")
                    } catch (ex: Exception) {
                        handleException(ex)
                    }
                } else {
                    log.w("Tunnel busy or already active")
                    s.emit()
                }
            }
        }
    }

    fun turnOff() {
        viewModelScope.launch {
            log.v("Requested to stop tunnel")
            val s = engine.getTunnelStatus()
            if (!s.inProgress && s.active) {
                try {
                    TunnelStatus.inProgress().emit()
                    engine.stopTunnel()
                    _config.value?.copy(tunnelEnabled = false)?.emit()
                    engine.getTunnelStatus().emit()
                    log.v("Tunnel stopped successfully")
                } catch (ex: Exception) {
                    handleException(ex)
                }
        } else {
                log.w("Tunnel busy or already stopped")
                s.emit()
            }
        }
    }

    fun switchGatewayOn() {
        viewModelScope.launch {
            log.v("Requested to switch gateway on")
            val s = engine.getTunnelStatus()
            if (!s.inProgress && s.gatewayId == null) {
                try {
                    TunnelStatus.inProgress().emit()
                    if (!s.active) throw BlokadaException("Tunnel is not active")
                    val cfg = _config.value ?: throw BlokadaException("BlockaConfig not set")
                    if (cfg.lease == null) throw BlokadaException("Lease not set in BlockaConfig")

                    engine.restartSystemTunnel(cfg.lease)
                    engine.connectVpn(cfg)

                    cfg.copy(vpnEnabled = true).emit()
                    engine.getTunnelStatus().emit()
                    log.v("Gateway switched on successfully")

                    viewModelScope.launch {
                        try {
                            // Async check lease to not slow down the primary user flow
                            lease.checkLease(cfg)
                        } catch (ex: Exception) {
                            log.w("Could not check lease".cause(ex))
                        }
                    }
                } catch (ex: Exception) {
                    handleException(ex)
                }
            } else {
                log.w("Tunnel busy or already gateway connected")
                s.emit()
            }
        }
    }

    fun switchGatewayOff() {
        viewModelScope.launch {
            log.v("Requested to switch gateway off")
            val s = engine.getTunnelStatus()
            if (!s.inProgress && s.gatewayId != null) {
                try {
                    TunnelStatus.inProgress().emit()
                    if (s.active) {
                        engine.disconnectVpn()
                        engine.restartSystemTunnel(null)
                    }
                    _config.value?.copy(vpnEnabled = false)?.emit()
                    engine.getTunnelStatus().emit()
                    log.v("Gateway switched off successfully")
                } catch (ex: Exception) {
                    handleException(ex)
                }
            } else {
                log.w("Tunnel busy or already no gateway")
                s.emit()
            }
        }
    }

    fun changeGateway(gateway: Gateway) {
        viewModelScope.launch {
            log.v("Requested to change gateway")
            val s = engine.getTunnelStatus()
            if (!s.inProgress) {
                try {
                    TunnelStatus.inProgress().emit()
                    var cfg = _config.value ?: throw BlokadaException("BlockaConfig not set")
                    val lease = lease.createLease(cfg, gateway)
                    cfg = cfg.copy(vpnEnabled = true, lease = lease, gateway = gateway)

                    if (s.active && s.gatewayId != null) engine.disconnectVpn()
                    if (s.active) engine.restartSystemTunnel(lease)
                    else engine.startTunnel(lease)
                    engine.connectVpn(cfg)

                    cfg.emit()
                    engine.getTunnelStatus().emit()
                    log.v("Gateway changed successfully")
                } catch (ex: Exception) {
                    handleException(ex)
                }
            } else {
                log.w("Tunnel busy")
                s.emit()
            }

        }
    }

    fun checkConfigAfterAccountChanged(account: Account) {
        viewModelScope.launch {
            _config.value?.let {
                if (account.id != it.keysGeneratedForAccountId) {
                    log.w("Account ID changed")
                    newKeypair(account.id)
                } else if (it.keysGeneratedForDevice != EnvironmentService.getDeviceId()) {
                    log.w("Device ID changed")
                    newKeypair(account.id)
                }
            }
        }
    }

    fun clearLease() {
        viewModelScope.launch {
            log.v("Clearing lease")
            _config.value?.copy(vpnEnabled = false, lease = null, gateway = null)?.emit()
            val s = engine.getTunnelStatus()
            if (!s.inProgress && s.gatewayId != null) {
                try {
                    TunnelStatus.inProgress().emit()
                    if (s.active) {
                        engine.disconnectVpn()
                        engine.restartSystemTunnel(null)
                    }
                    engine.getTunnelStatus().emit()
                    log.v("Disconnected from VPN")
                } catch (ex: Exception) {
                    handleException(ex)
                }
            } else {
                log.w("Tunnel busy")
                s.emit()
            }
        }
    }

    private var turnedOnAfterStartedBySystem = false
    fun turnOnWhenStartedBySystem() {
        viewModelScope.launch {
            _tunnelStatus.value?.let { status ->
                if (!status.inProgress && !turnedOnAfterStartedBySystem) {
                    turnedOnAfterStartedBySystem = true
                    log.w("System requested to start tunnel, setting up")
                    turnOn()
                }
            }
        }
    }

    fun setInformedUserAboutError() {
        viewModelScope.launch {
            log.v("User has been informed about the error")
            engine.getTunnelStatus().emit()
        }
    }

    fun isMe(publicKey: PublicKey): Boolean {
        return publicKey == _config.value?.publicKey
    }

    fun isCurrentlySelectedGateway(gatewayId: GatewayId): Boolean {
        return gatewayId == _config.value?.gateway?.public_key
    }

    private fun handleException(ex: Exception) {
        log.e("Tunnel failure".cause(ex))
        TunnelStatus.error(TunnelFailure(ex)).emit()
    }

    private fun handleTunnelStoppedUnexpectedly(ex: BlokadaException) {
        viewModelScope.launch {
            log.e("Engine reports tunnel stopped unexpectedly".cause(ex))
            TunnelStatus.error(ex).emit()
            //engine.getTunnelStatus().emit()
        }
    }

    private suspend fun newKeypair(accountId: AccountId) {
        _config.value?.let {
            try {
                log.w("Generating new keypair")
                val keypair = engine.newKeypair()
                val newConfig = it.copy(
                    privateKey = keypair.first,
                    publicKey = keypair.second,
                    keysGeneratedForAccountId = accountId,
                    keysGeneratedForDevice = EnvironmentService.getDeviceId()
                )
                updateLiveData(newConfig)
                BackupService.requestBackup()
            } catch (ex: Exception) {
                log.e("Could not generate new keypair".cause(ex))
            }
        }
    }

    private fun updateLiveData(config: BlockaConfig) {
        persistence.save(config)
        viewModelScope.launch {
            _config.value = config
        }
    }

    private fun TunnelStatus.emit() {
        _tunnelStatus.value = this
    }

    private fun BlockaConfig.emit() {
        _config.value = this
        persistence.save(this)
    }

}