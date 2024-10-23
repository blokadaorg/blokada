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

import android.text.Spannable
import android.text.SpannableStringBuilder
import android.text.style.RelativeSizeSpan
import android.text.style.TextAppearanceSpan
import androidx.core.text.bold
import androidx.core.text.color
import androidx.core.text.inSpans
import androidx.core.text.scale
import androidx.core.text.toSpannable
import org.blokada.R
import service.ContextService

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
