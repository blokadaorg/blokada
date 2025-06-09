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
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import androidx.core.graphics.createBitmap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import model.App
import model.AppId
import service.ContextService
import utils.cause
import utils.Logger
import java.io.ByteArrayOutputStream

object AppRepository {

    private val log = Logger("AppRepository")
    private val context by lazy { ContextService }
    private val scope by lazy { CoroutineScope(Dispatchers.Main) }

    val alwaysBypassed: List<AppId> by lazy {
        listOf<AppId>(
            // This app package name
            context.requireContext().packageName
        )
    }

    suspend fun getApps(): List<App> {
        return scope.async(Dispatchers.Default) {
            log.v("Fetching apps (Android ${Build.VERSION.SDK_INT})")
            val ctx = context.requireContext()
            val installed = try {
                // On Android 11+ (API 30+), this requires QUERY_ALL_PACKAGES permission
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    log.v("Android 11+ detected, using QUERY_ALL_PACKAGES permission")
                }
                ctx.packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
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

    fun getAppIcon(packageName: String): ByteArray? {
        return try {
            val ctx = context.requireContext()
            val packageManager = ctx.packageManager

            // Get the application info to access the icon
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            val icon = packageManager.getDrawable(packageName, appInfo.icon, appInfo) ?: return null

            // Convert the drawable to a bitmap
            val bitmap = createBitmap(icon.intrinsicWidth, icon.intrinsicHeight)
            val canvas = Canvas(bitmap)
            icon.setBounds(0, 0, canvas.width, canvas.height)
            icon.draw(canvas)

            // Convert the bitmap to a byte array
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            val byteArray = stream.toByteArray()

            byteArray
        } catch (ex: PackageManager.NameNotFoundException) {
            log.w("Package not found: $packageName")
            null
        } catch (ex: Exception) {
            log.w("Could not get app icon for $packageName".cause(ex))
            null
        }
    }
}
