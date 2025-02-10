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

import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.*

val blockaDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
val blockaDateFormatShort = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
val blockaDateFormatNoNanos = "yyyy-MM-dd'T'HH:mm:ss'Z'"

private val simpleFormat = DateFormat.getDateInstance(DateFormat.LONG, Locale.US).apply {
    timeZone = TimeZone.getTimeZone("GMT")
}
private val blockaFormat = SimpleDateFormat(blockaDateFormat).apply {
    timeZone = TimeZone.getTimeZone("GMT")
}
private val blockaFormat2 = SimpleDateFormat(blockaDateFormatShort).apply {
    timeZone = TimeZone.getTimeZone("GMT")
}

private val blockaFormat3 = SimpleDateFormat(blockaDateFormatNoNanos).apply {
    timeZone = TimeZone.getTimeZone("GMT")
}

fun Date.toSimpleString(): String {
    return simpleFormat.format(this)
}

fun String.toBlockaDate(): Date {
    return blockaFormat.runCatching { parse(this@toBlockaDate) }.getOrNull() ?:
    blockaFormat2.runCatching { parse(this@toBlockaDate) }.getOrNull() ?:
    blockaFormat3.runCatching { parse(this@toBlockaDate) }.getOrThrow()
}