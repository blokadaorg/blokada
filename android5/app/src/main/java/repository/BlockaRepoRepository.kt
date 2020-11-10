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

package repository

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import model.BlockaRepo
import service.HttpService
import service.JsonSerializationService
import utils.Logger

object BlockaRepoRepository {

    private val log = Logger("BlockaRepo")
    private val serializer = JsonSerializationService
    private val http = HttpService

    suspend fun fetch(): BlockaRepo {
        return coroutineScope {
            async(Dispatchers.IO) {
                log.v("Fetching Blocka repo to check for updates and configuration")
                val content = http.makeRequest(REPO_URL)
                serializer.deserialize(
                    content,
                    BlockaRepo::class
                )
            }
        }.await()
    }

}

private const val REPO_URL = "https://blokada.org/api/v5/repo.json"