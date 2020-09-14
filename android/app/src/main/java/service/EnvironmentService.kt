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

package service

import android.os.Build
import model.DeviceId
import org.blokada.BuildConfig

object EnvironmentService {

    fun getDeviceAlias(): String {
        val brand = Build.MANUFACTURER
        val model = Build.MODEL
        return "$brand $model"
    }

    fun getUserAgent(): String {
        val version = BuildConfig.VERSION_NAME
        val androidVersion = Build.VERSION.SDK_INT
        val type = BuildConfig.BUILD_TYPE
        val arch = Build.SUPPORTED_ABIS[0]
        val brand = Build.MANUFACTURER
        val device = Build.DEVICE
        val flavor = getFlavor()
        val touch = if (isSupportingTouch()) "touch" else "donttouch"
        val compatible = if (isCompatible()) "compatible" else "incompatible"
        return "blokada/$version (android-$androidVersion $flavor $type $arch $brand $device $touch api $compatible)"
    }

    fun isPublicBuild(): Boolean {
        return BuildConfig.BUILD_TYPE == "release"
    }

    fun isSlim(): Boolean {
        return BuildConfig.FLAVOR == "google" && !escaped
    }

    fun getFlavor(): String {
        return if (escaped) "escaped" else BuildConfig.FLAVOR
    }

    fun getBuildName(): String {
        return "${getFlavor()}${BuildConfig.BUILD_TYPE.capitalize()}"
    }

    fun getVersionCode() = BuildConfig.VERSION_CODE

    fun getDeviceId(): DeviceId {
        return getDeviceAlias() // TODO: more unique
    }

    fun isCompatible(): Boolean {
        val device = Build.MANUFACTURER.toLowerCase()
        return when {
            device.startsWith("realme") -> false
            device.startsWith("oppo") -> false
            !isSupportingTouch() -> false
            else -> true
        }
    }

    fun isSupportingTouch(): Boolean {
        val ctx = ContextService.requireContext()
        return ctx.packageManager.hasSystemFeature("android.hardware.touchscreen")
    }

    var escaped = false

}
