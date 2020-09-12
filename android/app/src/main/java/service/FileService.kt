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