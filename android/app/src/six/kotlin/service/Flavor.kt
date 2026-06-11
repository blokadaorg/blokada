/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2024 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object Flavor {
    val CHANNEL_NAME = "org.blokada/flavor"

    fun attach(messenger: BinaryMessenger) {
        val channel = MethodChannel(
            messenger,
            CHANNEL_NAME
        )

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getTimezone" -> result.success(java.util.TimeZone.getDefault().id)
                else -> result.success(getFlavor())
            }
        }
    }

    fun getFlavor(): String {
        return "notfamily"
    }

    fun isFamily(): Boolean {
        return false;
    }
}