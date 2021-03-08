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

package model

import com.squareup.moshi.JsonClass
import service.Localised
import utils.Logger

/**
 * This file is copypasted from the iOS version and adapted to Kotlin.
 */

typealias PackId = String
typealias PackSourceId = String

/// Tags help the user choose among interesting packs and may indicate
/// various things about the pack. They are used in the UI for filtering.
/// Examples: ads, trackers, porn, ipv6, regional, Poland, China
typealias Tag = Localised

/// SourceType tells the app how to use the source data.
/// Examples: hostlist, iplist, easylist, safariplugin
typealias SourceType = String

typealias Uri = String

/// A Pack may define zero to many PackConfigs which define its
/// behavior. For example, some hostlists exist in several variants,
/// from small to big size.
typealias PackConfig = String

@JsonClass(generateAdapter = true)
data class Pack(
    val id: PackId,
    val tags: List<Tag>,
    val sources: List<PackSource>,
    val meta: PackMetadata,
    val configs: List<PackConfig>,
    val status: PackStatus
) {
    companion object {
        val recommended = "recommended"
        val official = "official"
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as Pack

        if (id != other.id) return false

        return true
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }

}

@JsonClass(generateAdapter = true)
data class PackMetadata(
    val title: String,
    val slugline: Localised,
    val description: Localised,
    val creditName: String,
    val creditUrl: Uri,
    val rating: Int?
)

@JsonClass(generateAdapter = true)
data class PackSource(
    val id: PackSourceId,
    val urls: List<Uri>,
    val liveUpdateUrl: Uri?,
    val applyFor: List<PackConfig>?,
    val whitelist: Boolean
) {
    companion object {}
}

@JsonClass(generateAdapter = true)
data class PackStatus(
    val installed: Boolean,
    val updatable: Boolean,
    @Transient var installing: Boolean = false,
    val badge: Boolean,
    val config: List<PackConfig>,
    val hits: Int
)

@JsonClass(generateAdapter = true)
data class Packs(
    val packs: List<Pack>,
    val version : Int?,
    val lastRefreshMillis: Long
) {
    fun replace(pack: Pack): Packs {
        return Packs(
            packs = packs.map { if (it == pack) pack else it },
            version = Defaults.PACKS_VERSION,
            lastRefreshMillis = this.lastRefreshMillis
        )
    }
}

fun Pack.Companion.mocked(
    id: PackId, tags: List<Tag> = emptyList(),
    title: String, slugline: String = "", description: String = "",
    creditName: String = "", creditUrl: String = "",
    configs: List<PackConfig> = emptyList()
): Pack {
    return Pack(
        id, tags, sources = emptyList(), meta = PackMetadata(
            title, slugline, description, creditName, creditUrl, rating = null
        ), configs = configs, status = PackStatus(
            installed = false, updatable = false,
            installing = false, badge = false, config = emptyList(), hits = 0
        )
    )
}

fun Pack.allTagsCommaSeparated(): String {
    return if (tags.isEmpty()) {
        "None"
        //return L10n.packTagsNone
    } else {
        tags.joinToString().capitalize()
    }
}

fun Pack.changeStatus(installed: Boolean? = null, updatable: Boolean? = null, installing: Boolean? = null,
                                               badge: Boolean? = null, enabledConfig: List<PackConfig>? = null,
                                               config: PackConfig? = null, hits: Int? = null): Pack {
    return Pack(
        this.id,
        this.tags,
        this.sources,
        this.meta,
        this.configs,
        status = PackStatus(
            installed = installed ?: this.status.installed,
            updatable = updatable ?: this.status.updatable,
            installing = installing ?: this.status.installing,
            badge = badge ?: this.status.badge,
            config = enabledConfig ?: switchConfig(config = config),
            hits = hits ?: this.status.hits
        )
    )
}

private fun Pack.switchConfig(config: PackConfig?): List<PackConfig> {
    var newConfig = (if (config == null) this.status.config else
    if (this.status.config.contains(config)) this.status.config.filter { it != config } else this.status.config + listOf(config))

    if (newConfig.isEmpty()) {
        // Dont allow to have empty config (unless originally it's empty)
        newConfig = this.status.config
    }

    return newConfig
}

fun Pack.withSource(source: PackSource): Pack {
    return Pack(
        id = this.id, tags = this.tags, sources = this.sources + listOf(source), meta = this.meta,
        configs = this.configs, status = this.status
    )
}

fun PackSource.Companion.new(url: Uri, applyFor: PackConfig): PackSource {
    return PackSource(
        id = "xxx", urls = listOf(url), liveUpdateUrl = null, applyFor = listOf(applyFor),
        whitelist = false
    )
}

fun Pack.getUrls(): List<Uri> {
    if (configs.isEmpty()) {
        // For packs without configs, just take all sources
        return sources.flatMap { it.urls }.distinct()
    } else {
        val activeSources = sources.filter {
            if (it.applyFor == null) {
                false
            } else {
                it.applyFor.intersect(status.config).isNotEmpty()
            }
        }

        if (activeSources.isEmpty()) {
            Logger.w("Pack", "No matching sources for chosen configuration, choosing first")
            return sources.first().urls
        } else {
            return activeSources.flatMap { it.urls }.distinct()
        }
    }
}
