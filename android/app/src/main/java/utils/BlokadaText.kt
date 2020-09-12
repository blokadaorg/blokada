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

import android.text.Spannable
import android.text.SpannableStringBuilder
import android.text.style.RelativeSizeSpan
import android.text.style.TextAppearanceSpan
import androidx.core.text.*
import org.blokada.R
import service.ContextService
import ui.utils.cause
import ui.utils.getColorFromAttr

fun String.toBlokadaPlusText(): Spannable {
    val text = "BLOKADA+"
    val output = SpannableStringBuilder()
    if (startsWith(text)) {
        output.getBlokadaPlusText()
        output.append(replace(text, ""))
    } else if (endsWith(text)) {
        output.append(replace(text, ""))
        output.getBlokadaPlusText()
    } else if (contains(text)) {
        val parts = split(text)
        output.append(parts[0])
        output.getBlokadaPlusText()
        output.append(parts[1])
    } else output.append(this)
    return output.toSpannable()
}

private fun blokadaSpan() = {
    val context = ContextService.requireContext()
    try {
        TextAppearanceSpan(context, R.style.Text_Plus_Primary)
    } catch (ex: Exception) {
        // Just Android things, something to do with not using AppCompat themes
        Logger.w("TextFormat", "Failed formatting text".cause(ex))
        RelativeSizeSpan(1.05f)
    }
}()

private fun SpannableStringBuilder.getBlokadaPlusText() {
    inSpans(blokadaSpan()) {
        this.append("BLOKADA+")
    }
}

fun String.toBlokadaText(): Spannable {
    val text = "BLOKADA"
    val output = SpannableStringBuilder()
    if (startsWith(text)) {
        output.getBlokadaText()
        output.append(replace(text, ""))
    } else if (endsWith(text)) {
        output.append(replace(text, ""))
        output.getBlokadaText()
    } else if (contains(text)) {
        val parts = split(text)
        output.append(parts[0])
        output.getBlokadaText()
        output.append(parts[1])
    } else output.append(this)
    return output.toSpannable()
}

private fun SpannableStringBuilder.getBlokadaText() {
    inSpans(blokadaSpan()) {
        this.append("BLOKADA")
    }
}

fun String.withBoldSections(color: Int, scale: Float = 1.0f): Spannable {
    val parts = split("*")
    val output = SpannableStringBuilder(parts[0])
    var shouldBold = true
    for (part in parts.drop(1)) {
        if (shouldBold) {
            output.bold {
                output.color(color) {
                    output.scale(scale) {
                        append(part)
                    }
                }
            }
        } else {
            output.append(part)
        }
        shouldBold = !shouldBold
    }
    return output.toSpannable()
}
