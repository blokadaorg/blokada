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
import binding.CommonBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import model.App
import model.AppId
import model.BypassedAppIds
import service.ContextService
import service.PersistenceService
import utils.cause
import utils.Logger

object AppRepository {

    private val log = Logger("AppRepository")
    private val context = ContextService
    private val persistence = PersistenceService
    private val scope = GlobalScope
    private val common = CommonBinding

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

    // List decided by #133
    private val commonBypassList = listOf(
        "com.google.android.projection.gearhead", // Android Auto
        "com.google.android.apps.chromecast.app", // Google Chromecast
        "com.gopro.smarty", // GoPro
        "com.google.android.apps.messaging", // RCS/Jibe messaging services
        "com.sonos.acr", // Sonos
        "com.sonos.acr2", // Sonos
        "com.google.stadia.android", // Stadia
    )

    fun getPackageNamesOfAppsToBypass(forRealTunnel: Boolean = false): List<AppId> {
        if (common.skipBypassList) {
            return alwaysBypassed + bypassedAppIds
        } else {
            return alwaysBypassed + commonBypassList + bypassedAppIds
        }
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
