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
import okhttp3.Dns
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.HttpUrl
import okhttp3.logging.HttpLoggingInterceptor
import utils.Logger
import java.net.InetAddress
import java.net.UnknownHostException
import java.util.concurrent.TimeUnit

object HttpService {

    private val env = EnvironmentService
    private val log = Logger("Http")
    private const val DNS_CACHE_TTL_MS = 10 * 60 * 1000L
    private val firstPartyHosts = setOf("api.blocka.net", "family.api.blocka.net")

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
        return clientFor(request.url).newCall(request).execute().body!!.string()
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

        val builtRequest = request.build()
        val response = clientFor(builtRequest.url).newCall(builtRequest).execute()

        if (response.code != 200) {
            throw Exception("code:${response.code}")
        }

        return response.body!!.string()
    }

    private fun clientFor(url: HttpUrl): OkHttpClient {
        if (!isFirstPartyHost(url.host)) return httpClient

        val network = ConnectivityService.getUnderlyingNetwork()
        if (network == null) {
            log.w("No underlying network for ${url.host}, falling back to default client")
            return httpClient.newBuilder()
                .dns(CachingDns(null))
                .build()
        }

        log.v("Binding ${url.host} to underlying network ${network.networkHandle}")
        return httpClient.newBuilder()
            .socketFactory(network.socketFactory)
            .dns(CachingDns(network))
            .build()
    }

    private fun isFirstPartyHost(host: String): Boolean {
        return host in firstPartyHosts
    }

    private class CachingDns(private val network: android.net.Network?) : Dns {
        override fun lookup(hostname: String): List<InetAddress> {
            if (!HttpService.isFirstPartyHost(hostname)) {
                return Dns.SYSTEM.lookup(hostname)
            }

            val resolved = tryResolve(hostname)
            if (resolved.isNotEmpty()) {
                ResolutionCache.store(hostname, resolved)
                return resolved
            }

            val cached = ResolutionCache.load(hostname)
            if (cached.isNotEmpty()) {
                HttpService.log.w("Using cached DNS entries for $hostname")
                return cached
            }

            throw UnknownHostException("Unable to resolve host \"$hostname\" on bound network")
        }

        private fun tryResolve(hostname: String): List<InetAddress> {
            return try {
                val addresses = network?.getAllByName(hostname)?.toList() ?: Dns.SYSTEM.lookup(hostname)
                addresses.filter { it.hostAddress != null }
            } catch (ex: UnknownHostException) {
                emptyList()
            }
        }
    }

    private object ResolutionCache {
        private val entries = mutableMapOf<String, CacheEntry>()

        @Synchronized
        fun store(hostname: String, addresses: List<InetAddress>) {
            entries[hostname] = CacheEntry(
                addresses = addresses,
                expiresAt = System.currentTimeMillis() + DNS_CACHE_TTL_MS
            )
        }

        @Synchronized
        fun load(hostname: String): List<InetAddress> {
            val entry = entries[hostname] ?: return emptyList()
            if (entry.expiresAt < System.currentTimeMillis()) {
                entries.remove(hostname)
                return emptyList()
            }
            return entry.addresses
        }
    }

    private data class CacheEntry(
        val addresses: List<InetAddress>,
        val expiresAt: Long
    )
}
