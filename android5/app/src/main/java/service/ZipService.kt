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

import model.BlokadaException
import java.io.InputStream
import android.util.Base64
import java.io.BufferedInputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream


object ZipService {

    private val fileService = FileService

    fun decodeStream(stream: InputStream, key: String): InputStream {
        var zipInput: InputStream? = null
        try {
            zipInput = ZipInputStream(stream)
            val entry = zipInput.nextEntry ?: throw BlokadaException("Unexpected format of the zip file")
            val decoded = fileService.load(zipInput)
            return decoded.toByteArray().inputStream()
        } catch (ex: Exception) {
            throw BlokadaException("Could not unpack zip file", ex)
        }
    }

}