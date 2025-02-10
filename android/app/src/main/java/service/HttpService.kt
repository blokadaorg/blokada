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
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.logging.HttpLoggingInterceptor
import java.util.concurrent.TimeUnit

object HttpService {

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
        return httpClient.newCall(request).execute().body!!.string()
    }

    fun makeRequest(url: Uri, method: String, body: String?, headers: Map<String, String>? = null): String {
        var request = Request.Builder().url(url)

        request = if (body != null) {
            request.method(method, RequestBody.create(
                "application/json; charset=utf-8".toMediaType(), body)
            )
        } else {
            // Retrofit doesn't allow a null body for POST
            val emptyBody = if (method == "POST") RequestBody.create(null, "") else null
            request.method(method, emptyBody)
        }

        headers?.forEach { (key, value) ->
            request.addHeader(key, value)
        }

        val response = httpClient.newCall(request.build()).execute()

        if (response.code != 200) {
            throw Exception("code:${response.code}")
        }

        return response.body!!.string()
    }

}