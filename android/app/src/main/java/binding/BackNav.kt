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

package binding

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object BackNav {
    val CHANNEL_NAME = "org.blokada/back"

    lateinit var channel: MethodChannel;

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(
            messenger,
            CHANNEL_NAME
        )
    }

    fun onBackPressed() {
        channel.invokeMethod("onBackPressed", null);
    }
}