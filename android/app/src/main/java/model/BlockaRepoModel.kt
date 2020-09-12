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

package model

import com.squareup.moshi.JsonClass


@JsonClass(generateAdapter = true)
data class BlockaRepo(
    val syntaxVersion: Int,
    val common: BlockaRepoConfig,
    val buildConfigs: List<BlockaRepoConfig>
)

@JsonClass(generateAdapter = true)
data class BlockaRepoConfig(
    val name: String,
    val forBuild: String,
    val supportedLanguages: List<String>? = null,
    val update: BlockaRepoUpdate? = null,
    val payload: BlockaRepoPayload? = null,
    val lastRefresh: Long = 0L
) {

    fun supportedLanguages() = supportedLanguages ?: emptyList()

    fun combine(common: BlockaRepoConfig) = copy(
        supportedLanguages = supportedLanguages ?: common.supportedLanguages,
        update = update ?: common.update
    )

}

@JsonClass(generateAdapter = true)
data class BlockaRepoUpdate(
    val mirrors: List<Uri>,
    val infoUrl: Uri,
    val newest: String
)

@JsonClass(generateAdapter = true)
data class BlockaAfterUpdate(
    val dialogShownForVersion: Int? = null
)

@JsonClass(generateAdapter = true)
data class BlockaRepoPayload(
    val cmd: String,
    val version: Int? = null
)