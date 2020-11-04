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

import android.util.Base64.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import model.BlokadaException
import model.Uri
import utils.Logger

object BlocklistService {

    private const val DEFAULT_BLOCKLIST = "default_blocklist.zip"
    const val MERGED_BLOCKLIST = "merged_blocklist"
    const val USER_ALLOWED = "allowed"
    const val USER_DENIED = "denied"

    private val log = Logger("Blocklist")
    private val http = HttpService
    private val file = FileService
    private val context = ContextService

    suspend fun setup() {
        val destination = file.commonDir().file(MERGED_BLOCKLIST)
        if (!file.exists(destination)) {
            log.w("Initiating default blocklist files")
            val allowed = file.commonDir().file(USER_ALLOWED)
            file.save(allowed, "")

            val denied = file.commonDir().file(USER_DENIED)
            file.save(denied, "")

            val default = file.commonDir().file(DEFAULT_BLOCKLIST)
            val asset = context.requireAppContext().assets.open(DEFAULT_BLOCKLIST)
            val decodedAsset = ZipService.decodeStream(asset, key = DEFAULT_BLOCKLIST)
            file.save(source = decodedAsset, destination = default)
            file.merge(listOf(default), destination)
            sanitize(destination)
        }
    }

    suspend fun downloadAll(urls: List<Uri>) {
        log.v("Starting download of ${urls.size} urls")
        coroutineScope {
            for (url in urls) {
                if (!hasDownloaded(url))
                    launch(Dispatchers.IO) {
                        download(url)
                        sanitize(getDestination(url))
                    }
            }
        }
        log.v("Done downloading")
    }

    suspend fun mergeAll(urls: List<Uri>) {
        log.v("Merging ${urls.size} blocklists")
        var destinations = urls.map { getDestination(it) }

        if (destinations.isEmpty()) {
            log.w("No selected blocklists, using default")
            destinations += file.commonDir().file(DEFAULT_BLOCKLIST)
        }

        val userDenied = file.commonDir().file(USER_DENIED)
        if (file.exists(userDenied)) {
            // Always include user blocklist (whitelist is included using engine api)
            log.v("Including user denied list")
            destinations += userDenied
        }

        val merged = file.commonDir().file(MERGED_BLOCKLIST)
        file.merge(destinations, merged)
        sanitize(merged)

        log.v("Done merging")
    }

    fun removeAll(urls: List<Uri>) {
        log.v("Removing ${urls.size} blocklists")
        for (url in urls) {
            remove(getDestination(url))
        }
        log.v("Done removing")
    }

    fun loadMerged(): List<String> {
        return file.load(file.commonDir().file(MERGED_BLOCKLIST))
    }

    fun loadUserAllowed(): List<String> {
        return file.load(file.commonDir().file(USER_ALLOWED))
    }

    fun loadUserDenied(): List<String> {
        return file.load(file.commonDir().file(USER_DENIED))
    }

    private fun sanitize(list: Uri) {
        log.v("Sanitizing list: $list")
        val content = file.load(list).sorted().distinct().toMutableList()
        var i = content.count()
        while (--i >= 0) {
            if (!isLineOk(content[i])) content.removeAt(i)
            else content[i] = removeIp(content[i]).trim()
        }
        file.save(list, content)
        log.v("Sanitizing done, left ${content.size} lines")
    }

    private fun isLineOk(line: String) = when {
        line.startsWith("#") -> false
        line.trim().isEmpty() -> false
        else -> true
    }

    private fun removeIp(line: String) = when {
        line.startsWith("127.0.0.1") -> line.removePrefix("127.0.0.1")
        line.startsWith("0.0.0.0") -> line.removePrefix("0.0.0.0")
        else -> line
    }

    private fun hasDownloaded(url: Uri): Boolean {
        return file.exists(getDestination(url))
    }

    private fun remove(url: Uri) {
        log.v("Removing blocklist file for: $url")
        file.remove(getDestination(url))
    }

    private suspend fun download(url: Uri) {
        log.v("Downloading blocklist: $url")
        val destination = getDestination(url)
        try {
            val content = http.makeRequest(url)
            file.save(destination, content)
        } catch (ex: Exception) {
            remove(url)
            throw BlokadaException("Could not fetch domains for: $url")
        }
    }

    private fun getDestination(url: Uri): Uri {
        val filename = encodeToString(url.toByteArray(), NO_WRAP)
        return file.commonDir().file(filename)
    }

}