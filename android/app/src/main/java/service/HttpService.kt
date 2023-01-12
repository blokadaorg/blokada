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

import engine.EngineService
import model.Uri
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.logging.HttpLoggingInterceptor
import java.util.concurrent.TimeUnit

object HttpService {

    private val engine = EngineService
    private val env = EnvironmentService

    private val httpClient = OkHttpClient.Builder().apply {
        addNetworkInterceptor { chain ->
            val request = chain.request()
//            chain.connection()?.socket()?.let {
//                engine.protectSocket(it)
//            }
            chain.proceed(request)
        }
        addInterceptor { chain ->
            val request = chain.request().newBuilder().header("User-Agent", env.getUserAgent()).build()
            chain.proceed(request)
        }

        if (!env.isPublicBuild()) addInterceptor(HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        })

        // Probably DNS is messing up with those timeouts as we can still see hanging requests
        // As a workaround we now bypass our own app from VPN
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
    }.build()

    fun getClient() = httpClient

    fun makeRequest(url: Uri): String {
        val request = Request.Builder()
            .url(url)
            .build()
        return httpClient.newCall(request).execute().body()!!.string()
    }

}