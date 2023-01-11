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

import androidx.lifecycle.*
import engine.EngineService
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import model.*
import repository.Repos
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
        engine.setOnTunnelStatusChangedListener { status ->
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

    fun turnOn(vpnEnabled: Boolean? = null) {
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
                        val cfg = _config.value?.copy(
                            tunnelEnabled = true,
                            vpnEnabled = vpnEnabled ?: _config.value?.vpnEnabled ?: false
                        ) ?: throw BlokadaException("Config not set")
                        engine.updateConfig(user = cfg)
                        if (cfg.vpnEnabled) lease.checkLease(cfg)
                        cfg.copy(tunnelEnabled = true).emit()
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

    fun turnOff(vpnEnabled: Boolean? = null) {
        viewModelScope.launch {
            log.v("Requested to stop tunnel")
            val s = engine.getTunnelStatus()
            if (!s.inProgress && s.active) {
                try {
                    val cfg = _config.value?.copy(
                        tunnelEnabled = false,
                        vpnEnabled = vpnEnabled ?: _config.value?.vpnEnabled ?: false
                    ) ?: throw BlokadaException("Config not set")
                    engine.updateConfig(user = cfg)
                    cfg.emit()
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
                    if (!s.active) throw BlokadaException("Tunnel is not active")
                    var cfg = _config.value ?: throw BlokadaException("BlockaConfig not set")
                    if (cfg.lease == null) throw BlokadaException("Lease not set in BlockaConfig")
                    cfg = cfg.copy(vpnEnabled = true)
                    engine.updateConfig(user = cfg)
                    cfg.emit()
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
                    var cfg = _config.value ?: throw BlokadaException("BlockaConfig not set")
                    cfg = cfg.copy(vpnEnabled = false)
                    engine.updateConfig(user = cfg)
                    cfg.emit()
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
                    var cfg = _config.value ?: throw BlokadaException("BlockaConfig not set")
                    val lease = lease.createLease(cfg, gateway)
                    cfg = cfg.copy(tunnelEnabled = true, vpnEnabled = true, lease = lease, gateway = gateway)
                    engine.updateConfig(user = cfg)
                    cfg.emit()
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
            try {
                var cfg = _config.value ?: throw BlokadaException("BlockaConfig not set")
                cfg = cfg.copy(
                    tunnelEnabled = false,
                    vpnEnabled = false, lease = null, gateway = null
                )
                engine.updateConfig(user = cfg)
                cfg.emit()
                log.v("Disconnected from VPN")
            } catch (ex: Exception) {
                handleException(ex)
            }
        }
    }

    private var turnedOnAfterStartedBySystem = false
    fun turnOnWhenStartedBySystem() {
        viewModelScope.launch {
            _config.value?.let { config ->
                if (config.vpnEnabled) {
                    _tunnelStatus.value?.let { status ->
                        if (!status.inProgress && !turnedOnAfterStartedBySystem) {
                            turnedOnAfterStartedBySystem = true
                            log.w("System requested to start tunnel, setting up")
                            turnOn()
                        }
                    }
                }
            }
        }
    }

    fun setInformedUserAboutError(ex: Exception) {
        viewModelScope.launch {
            log.v("User has been informed about the error: $ex")
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
        log.e("Engine failed to execute action: $ex")
        val ex = ex as? BlokadaException ?: BlokadaException("Tunnel failure", ex)
        GlobalScope.launch { Repos.processing.notify("TunnelVM", ex, major = true) }
    }

    private fun handleTunnelStoppedUnexpectedly(ex: BlokadaException) {
    }

    private fun newKeypair(accountId: AccountId) {
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