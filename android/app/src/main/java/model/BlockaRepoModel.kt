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

import kotlinx.serialization.Serializable


@Serializable
data class BlockaRepo(
    val syntaxVersion: Int,
    val common: BlockaRepoConfig,
    val buildConfigs: List<BlockaRepoConfig>
)

@Serializable
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

@Serializable
data class BlockaRepoUpdate(
    val mirrors: List<Uri>,
    val infoUrl: Uri,
    val newest: String
)

@Serializable
data class BlockaAfterUpdate(
    val dialogShownForVersion: Int? = null
)

@Serializable
data class BlockaRepoPayload(
    val cmd: String,
    val version: Int? = null
)