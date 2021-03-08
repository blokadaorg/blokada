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

import android.util.Base64.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import model.BlokadaException
import model.Uri
import model.ex
import ui.utils.cause
import utils.Logger

object BlocklistService {

    private const val DEFAULT_BLOCKLIST = "default_blocklist"
    private const val DEFAULT_BLOCKLIST_ZIP = "default_blocklist.zip"
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
            log.w("Initiating default blocklist file")
            val default = file.commonDir().file(DEFAULT_BLOCKLIST)
            try {
                val asset = context.requireAppContext().assets.open(DEFAULT_BLOCKLIST_ZIP)
                val decodedAsset = ZipService.decodeStream(asset, key = DEFAULT_BLOCKLIST)
                file.save(source = decodedAsset, destination = default)
            } catch (ex: Exception) {
                log.w("No zip blocklist, falling back to plaintext one".cause(ex))
                val asset = context.requireAppContext().assets.open(DEFAULT_BLOCKLIST)
                file.save(source = asset, destination = default)
            }
            file.merge(listOf(default), destination)
            sanitize(destination)
        }

        val allowed = file.commonDir().file(USER_ALLOWED)
        val denied = file.commonDir().file(USER_DENIED)
        if (!file.exists(allowed) || !file.exists(denied)) {
            log.w("Initiating empty user allowed and user denied lists")
            file.save(allowed, "")
            file.save(denied, "")
        }
    }

    suspend fun downloadAll(urls: List<Uri>, force: Boolean = false) {
        log.v("Starting download of ${urls.size} urls")
        coroutineScope {
            for (url in urls) {
                if (force || !hasDownloaded(url))
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