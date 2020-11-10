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

import androidx.core.os.LocaleListCompat
import com.akexorcist.localizationactivity.ui.LocalizationActivity
import repository.TranslationRepository
import repository.getFirstSupportedLocale
import repository.getTranslationRepository
import ui.utils.cause
import utils.Logger
import java.lang.NullPointerException
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
        reload()
    }

    fun setLocale(locale: String?) {
        try {
            this.locale = Locale.forLanguageTag(locale!!)
        } catch (ex: NullPointerException) {
            // Just use default
            this.locale = LocaleListCompat.getAdjustedDefault().getFirstSupportedLocale()
        } catch (ex: Exception) {
            log.w("Could not use configured locale: $locale".cause(ex))
            this.locale = LocaleListCompat.getAdjustedDefault().getFirstSupportedLocale()
        }
        log.v("Setting locale to: ${this.locale}")
        reload()
    }

    fun setLocale(locale: Locale) {
        log.v("Setting locale to: $locale")
        this.locale = LocaleListCompat.getAdjustedDefault().getFirstSupportedLocale()
        reload()
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

    private fun reload() {
        if (initialized) {
            log.v("Reloading translations repositories")
            applyLocaleToActivity()
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