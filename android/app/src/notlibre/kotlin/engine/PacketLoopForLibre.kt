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

import model.BlokadaException
import utils.FlavorSpecific
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramSocket


internal class PacketLoopForLibre (
    private val deviceIn: FileInputStream,
    private val deviceOut: FileOutputStream,
    private val createSocket: () -> DatagramSocket,
    private val stoppedUnexpectedly: () -> Unit,
    filter: Boolean = true
): Thread("PacketLoopForLibre"), FlavorSpecific {

    override fun run() {
        throw BlokadaException("PacketLoopForLibre not supported in this build")
    }

}
