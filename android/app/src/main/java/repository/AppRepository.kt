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

package repository

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import model.App
import model.AppId
import model.BypassedAppIds
import service.ContextService
import service.PersistenceService
import ui.utils.cause
import utils.Logger

object AppRepository {

    private val log = Logger("AppRepository")
    private val context = ContextService
    private val persistence = PersistenceService
    private val scope = GlobalScope

    private var bypassedAppIds = persistence.load(BypassedAppIds::class).ids
        set(value) {
            persistence.save(BypassedAppIds(value))
            field = value
        }

    private val alwaysBypassed by lazy {
        listOf<AppId>(
            // This app package name
            context.requireContext().packageName
        )
    }

    private val bypassedForFakeVpn = listOf(
        "com.android.vending",
        "com.android.providers.downloads",
        "com.google.android.apps.fireball",
        "com.google.android.apps.authenticator2",
        "com.google.android.apps.docs",
        "com.google.android.apps.tachyon",
        "com.google.android.gm",
        "com.google.android.apps.photos",
        "com.google.android.play.games",
        "org.thoughtcrime.securesms",
        "com.plexapp.android",
        "org.kde.kdeconnect_tp",
        "com.samsung.android.email.provider",
        "com.xda.labs",
        "com.android.incallui",
        "com.android.phone",
        "com.android.providers.telephony",
        "com.huawei.systemmanager",
        "com.android.service.ims.RcsServiceApp",
        "com.google.android.carriersetup",
        "com.google.android.ims",
        "com.codeaurora.ims",
        "com.android.carrierconfig",
        "ch.threema.app",
        "ch.threema.app.work",
        "ch.threema.app.hms",
        "ch.threema.app.work.hms",
        "com.xiaomi.discover",
        "eu.siacs.conversations",
        "org.jitsi.meet",
        "com.tomtom.speedcams.android.map",
        "com.tomtom.amigo.huawei",
        // RCS: https://github.com/blokadaorg/blokadaorg.github.io/pull/31
        "com.android.service.ims.RcsServiceApp",
        "com.google.android.carriersetup",
        "com.google.android.ims",
        "com.codeaurora.ims",
        "com.android.carrierconfig",
        // MaaiiConnect #885
        "com.m800.liveconnect.mobile.agent.prod",
        "com.m800.liveconnect.mobile.agent.tb",
        // TomTom Go #878
        "com.tomtom.gplay.navapp",
        // Android Auto
        "com.google.android.projection.gearhead",
        // RCS
        "com.google.android.apps.messaging",
        // Additions from #3
        "com.google.android.apps.chromecast.app",
        "com.sonos.acr",
        "com.sonos.acr2",
        "com.gopro.smarty"
    )

    fun getPackageNamesOfAppsToBypass(forRealTunnel: Boolean = false): List<AppId> {
        return if (forRealTunnel) alwaysBypassed + bypassedAppIds
        else alwaysBypassed + bypassedForFakeVpn + bypassedAppIds
    }

    suspend fun getApps(): List<App> {
        return scope.async(Dispatchers.Default) {
            log.v("Fetching apps")
            val ctx = context.requireContext()
            val installed = try {
                ctx.packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
                    .filter { it.packageName != ctx.packageName }
            } catch (ex: Exception) {
                log.w("Could not fetch apps, ignoring".cause(ex))
                emptyList<ApplicationInfo>()
            }

            log.v("Fetched ${installed.size} apps, mapping")
            val apps = installed.mapNotNull {
                try {
                    App(
                        id = it.packageName,
                        name = ctx.packageManager.getApplicationLabel(it).toString(),
                        isSystem = (it.flags and ApplicationInfo.FLAG_SYSTEM) != 0,
                        isBypassed = isAppBypassed(it.packageName)
                    )
                } catch (ex: Exception) {
                    log.w("Could not map app, ignoring".cause(ex))
                    null
                }
            }
            log.v("Mapped ${apps.size} apps")
            apps
        }.await()
    }

    fun isAppBypassed(id: AppId): Boolean {
        return bypassedAppIds.contains(id)
    }

    fun switchBypassForApp(id: AppId) {
        if (isAppBypassed(id)) bypassedAppIds -= id
        else bypassedAppIds += id
    }

    fun getAppIcon(id: AppId): Drawable? {
        return try {
            val ctx = context.requireContext()
            ctx.packageManager.getApplicationIcon(
                ctx.packageManager.getApplicationInfo(id, PackageManager.GET_META_DATA)
            )
        } catch (e: Exception) {
            null
        }
    }
}
