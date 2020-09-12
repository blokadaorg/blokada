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

import engine.EngineService
import model.Uri
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.logging.HttpLoggingInterceptor

object HttpService {

    private val engine = EngineService
    private val env = EnvironmentService

    private val httpClient = OkHttpClient.Builder().apply {
        addNetworkInterceptor { chain ->
            val request = chain.request()
            chain.connection()?.socket()?.let {
                engine.protectSocket(it)
            }
            chain.proceed(request)
        }
        addInterceptor { chain ->
            val request = chain.request().newBuilder().header("User-Agent", env.getUserAgent()).build()
            chain.proceed(request)
        }

        if (!env.isPublicBuild()) addInterceptor(HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        })
    }.build()

    fun getClient() = httpClient

    fun makeRequest(url: Uri): String {
        val request = Request.Builder()
            .url(url)
            .build()
        return httpClient.newCall(request).execute().body()!!.string()
    }

}