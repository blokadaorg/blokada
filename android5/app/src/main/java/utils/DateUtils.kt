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

package utils

import java.text.SimpleDateFormat
import java.util.*

val blockaDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
val blockaDateFormatNoNanos = "yyyy-MM-dd'T'HH:mm:ssZ"

val userDateFormatSimple = "d MMMM yyyy"
val userDateFormatFull = "yyyyMMd jms"
val userDateFormatChat = "E., MMd, jms"

private val simpleFormat = SimpleDateFormat(userDateFormatSimple)
fun Date.toSimpleString(): String {
    return simpleFormat.format(this)
}
