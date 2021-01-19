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

import model.BlokadaException
import net.lingala.zip4j.ZipFile
import net.lingala.zip4j.io.inputstream.ZipInputStream
import java.io.InputStream


object ZipService {

    private val fileService = FileService

    fun decodeStream(stream: InputStream, key: String): InputStream {
        var zipInput: InputStream? = null
        try {
            zipInput = ZipInputStream(stream, key.toCharArray())
            val entry = zipInput.nextEntry ?: throw BlokadaException("Unexpected format of the zip file")
            val decoded = fileService.load(zipInput)
            return decoded.toByteArray().inputStream()
        } catch (ex: Exception) {
            throw BlokadaException("Could not unpack zip file", ex)
        }
    }

}