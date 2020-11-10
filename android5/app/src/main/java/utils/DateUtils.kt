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
