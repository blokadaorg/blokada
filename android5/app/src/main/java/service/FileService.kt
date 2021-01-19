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

import model.Uri
import utils.Logger
import java.io.BufferedReader
import java.io.File
import java.io.InputStream
import java.lang.Exception
import kotlin.math.max

// TODO: make an implementation of this that doesn't use so much memory
object FileService {

    private val log = Logger("File")
    private val context = ContextService

    fun exists(uri: Uri): Boolean {
        return File(uri).exists()
    }

    fun remove(uri: Uri) {
        try {
            File(uri).delete()
        } catch (ex: Exception) {}
    }

    fun commonDir(): Uri {
        return context.requireAppContext().filesDir.canonicalPath
    }

    suspend fun merge(uris: List<Uri>, destination: Uri) {
        val merged = mutableListOf<String>()
        for (uri in uris) {
            val content = load(uri)
            merged.addAll(content)
        }
        save(destination, merged)
    }

    fun load(source: Uri): List<String> {
        return File(source).useLines { it.toList() }
    }

    fun load(source: InputStream): String {
        return source.use { input ->
            val reader = BufferedReader(input.reader())
            reader.readText()
        }
    }

    fun save(destination: Uri, content: List<String>) {
        log.v("Saving ${content.size} lines to file: $destination")
        return File(destination).bufferedWriter().use { out ->
            for (line in content) {
                out.write(line + "\n")
            }
        }
    }

    fun save(destination: Uri, content: String) {
        log.v("Saving file: $destination")
        return File(destination).writeText(content)
    }

    fun save(destination: Uri, source: InputStream) {
        log.v("Saving file from input stream to: $destination")
        source.use { input ->
            File(destination).outputStream().use { output ->
                input.copyTo(output)
            }
        }
    }

    fun append(destination: Uri, line: String, maxSizeKb: Int = 0) {
        val file = File(destination)
        if (maxSizeKb > 0) {
            val sizeKb = file.length()
            if (sizeKb / 1024 >= maxSizeKb || sizeKb == 0L) {
                file.writeText(line)
                return
            }
        }
        file.appendText("\n$line")
    }
}

fun Uri.file(filename: String): Uri {
    return "$this/$filename"
}