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

package service

import androidx.core.os.LocaleListCompat
import com.akexorcist.localizationactivity.ui.LocalizationActivity
import repository.TranslationRepository
import repository.getFirstSupportedLocale
import repository.getTranslationRepository
import ui.utils.cause
import utils.Logger
import java.util.*

object TranslationService {

    private val log = Logger("Translation")

    /**
     * Localization lib we use puts a limitation on us, that it requires Activity to be started to
     * provide actual user locale. So, we default to English for before that moment. This may lead
     * to wrong strings in some scenarios (I imagine: a notification while Activity is not started).
     *
     * Also check the comment in TranslationRepository's LocaleListCompat.
     */

    private var locale: Locale = Locale.ROOT
    private lateinit var repo: TranslationRepository
    private var initialized = false

    private val untranslated = mutableListOf<Localised>()

    fun setup() {
        log.v("Translation service set up, locale: $locale")
        initialized = true
        reload(skipUpdatingActivity = true)
    }

    fun setLocale(locale: String?) {
        try {
            this.locale = Locale.forLanguageTag(locale!!)
        } catch (ex: NullPointerException) {
            // Just use default
            this.locale = findDefaultLocale()
        } catch (ex: Exception) {
            log.w("Could not use configured locale: $locale".cause(ex))
            this.locale = findDefaultLocale()
        }
        log.v("Setting locale to: ${this.locale}")
        reload()
    }

    private fun findDefaultLocale(): Locale {
        val supported = LocaleListCompat.getAdjustedDefault()
        log.v("Supported locales are: ${supported.toLanguageTags()} (size: ${supported.size()})")
        return supported.getFirstSupportedLocale()
    }

    fun getLocale(): Locale {
        return locale
    }

    fun get(string: Localised): String {
        return repo.getText(string) ?: run {
            if (!untranslated.contains(string)) {
                // Show warning once per string
                log.w("No translation for: $string")
                untranslated.add(string)
            }

            if (!EnvironmentService.isPublicBuild()) "@$string@"
            else string
        }
    }

    private fun reload(skipUpdatingActivity: Boolean = false) {
        if (initialized) {
            log.v("Reloading translations repositories")
            if (!skipUpdatingActivity) applyLocaleToActivity()
            repo = getTranslationRepository(this.locale)
        }
    }

    private fun applyLocaleToActivity() {
        try {
            val ctx = ContextService.requireContext() as LocalizationActivity
            ctx.setLanguage(locale)
            log.v("Applied locale to activity")
        } catch (ex: Exception) {
            log.e("Could not apply locale to activity".cause(ex))
        }
    }

}

/// Localised are strings that are supposed to be localised (translated)
typealias Localised = String

fun Localised.tr(): String {
    return TranslationService.get(this)
}