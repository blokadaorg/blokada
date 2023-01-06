/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import model.*
import repository.Repos
import retrofit2.Call
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.*
import utils.Logger
import java.io.IOException
import java.net.UnknownHostException


object BlockaApiService {

    private val http = HttpService

    private val processingRepo by lazy { Repos.processing }

    private val retrofit = Retrofit.Builder()
        .baseUrl("https://20221208t152901-dot-blokada-vpn.uc.r.appspot.com/")
        .addConverterFactory(MoshiConverterFactory.create(JsonSerializationService.moshi))
        .client(http.getClient())
        .build()

    private val api = retrofit.create(BlockaRestApi::class.java)

    suspend fun getAccount(id: AccountId): Account {
        return runOnBgAndMapException {
            api.getAccount(id).responseOrThrow().body()!!.account
        }
    }

    suspend fun postNewAccount(): Account {
        return runOnBgAndMapException {
            api.postNewAccount().responseOrThrow().body()!!.account
        }
    }

    suspend fun getDevice(id: AccountId): DevicePayload {
        return runOnBgAndMapException {
            if (EnvironmentService.isLibre()) {
                // Save requests by not doing this irrelevant request for v5
                Logger.v("BlockaApiService", "Not fetching device for libre")
                DevicePayload(
                    lists = emptyList(),
                    retention = "",
                    paused = true,
                    device_tag = ""
                )
            } else api.getDevice(id).responseOrThrow().body()!!
        }
    }

    suspend fun putDevice(request: DeviceRequest) {
        return runOnBgAndMapException {
            api.putDevice(request).responseOrThrow()
        }
    }

    suspend fun getActivity(id: AccountId): List<Activity> {
        return runOnBgAndMapException {
            api.getActivity(id).responseOrThrow().body()!!.activity
        }
    }

    suspend fun getCustomList(id: AccountId): List<CustomListEntry> {
        return runOnBgAndMapException {
            api.getCustomList(id).responseOrThrow().body()!!.customlist
        }
    }

    suspend fun postCustomList(request: CustomListRequest) {
        return runOnBgAndMapException {
            api.postCustomList(request).responseOrThrow()
        }
    }

    suspend fun deleteCustomList(request: CustomListRequest) {
        return runOnBgAndMapException {
            api.deleteCustomList(request).responseOrThrow()
        }
    }

    suspend fun getStats(id: AccountId): CounterStats {
        return runOnBgAndMapException {
            if (EnvironmentService.isLibre()) {
                // Save requests by not doing this irrelevant request for v5
                Logger.v("BlockaApiService", "Not fetching stats for libre")
                CounterStats(
                    total_allowed = "0",
                    total_blocked = "0"
                )
            } else api.getStats(id).responseOrThrow().body()!!
        }
    }

    suspend fun getBlocklists(id: AccountId): List<Blocklist> {
        return runOnBgAndMapException {
            api.getBlocklists(id).responseOrThrow().body()!!.lists
        }
    }

    suspend fun getGateways(): List<Gateway> {
        return runOnBgAndMapException {
            api.getGateways().responseOrThrow().body()!!.gateways
        }
    }

    suspend fun getLeases(id: AccountId): List<Lease> {
        return runOnBgAndMapException {
            api.getLeases(id).responseOrThrow().body()!!.leases
        }
    }

    suspend fun postLease(request: LeaseRequest): Lease {
        return runOnBgAndMapException {
            api.postLease(request).responseOrThrow().body()!!.lease
        }
    }

    suspend fun deleteLease(request: LeaseRequest) {
        return runOnBgAndMapException {
            api.deleteLease(request).responseOrThrow()
        }
    }

    suspend fun postGplayCheckout(request: GoogleCheckoutRequest): Account {
        return runOnBgAndMapException {
            api.postGplayCheckout(request).responseOrThrow().body()!!.account
        }
    }

    // Will retry failed requests 3 times (with 3s delay in between)
    private suspend fun <T> Call<T>.responseOrThrow(attempt: Int = 1): Response<T> {
        try {
            if (attempt > 1) Logger.w("Api", "Retrying request (attempt: $attempt): ${this.request().url()}")
            val r = this.clone().execute()
            return if (r.isSuccessful) r else when {
                r.code() == 403 -> throw TooManyDevices()
                r.code() in 500..599 && attempt < 3 -> {
                    // Retry on API server error
                    delay(3000)
                    this.responseOrThrow(attempt = attempt + 1)
                }
                else -> throw BlokadaException("Api response: ${r.code()}: ${r.errorBody()}")
            }
        } catch (ex: IOException) {
            // Network connectivity problem, also retry
            delay(3000)
            if (attempt < 3) return this.responseOrThrow(attempt = attempt + 1)
            else throw ex
        }
    }

    private fun <T> Response<T>.resultOrThrow(): T {
        if (!isSuccessful) when (code()) {
            403 -> throw TooManyDevices()
            else -> throw BlokadaException("Response: ${code()}: ${errorBody()}")
        } else return body()!!
    }

    private suspend fun <T> runOnBgAndMapException(block: suspend () -> T): T {
        try {
            val result = withContext(Dispatchers.IO) {
                block()
            }
            processingRepo.reportConnIssues("api", false)
            processingRepo.reportConnIssues("timeout", false)
            return result
        } catch (ex: UnknownHostException) {
            processingRepo.reportConnIssues("api", true)
            throw BlokadaException("Connection problems", ex)
        } catch (ex: BlokadaException) {
            throw ex
        } catch (ex: Exception) {
            throw BlokadaException("Api request failed", ex)
        }
    }
}

interface BlockaRestApi {

    @GET("/v2/account")
    fun getAccount(@Query("account_id") id: AccountId): Call<AccountWrapper>

    @POST("/v2/account")
    fun postNewAccount(): Call<AccountWrapper>

    @GET("/v2/device")
    fun getDevice(@Query("account_id") id: AccountId): Call<DevicePayload>

    @PUT("/v2/device")
    fun putDevice(@Body request: DeviceRequest): Call<Void>

    @GET("/v2/activity")
    fun getActivity(@Query("account_id") id: AccountId): Call<ActivityWrapper>

    @GET("/v2/customlist")
    fun getCustomList(@Query("account_id") id: AccountId): Call<CustomListWrapper>

    @POST("/v2/customlist")
    fun postCustomList(@Body request: CustomListRequest): Call<Void>

    @HTTP(method = "DELETE", path = "v1/customlist", hasBody = true)
    fun deleteCustomList(@Body request: CustomListRequest): Call<Void>

    @GET("/v2/stats")
    fun getStats(@Query("account_id") id: AccountId): Call<CounterStats>

    @GET("/v2/list")
    fun getBlocklists(@Query("account_id") id: AccountId): Call<BlocklistWrapper>

    @GET("/v2/gateway")
    fun getGateways(): Call<Gateways>

    @GET("/v2/lease")
    fun getLeases(@Query("account_id") accountId: AccountId): Call<Leases>

    @POST("/v2/lease")
    fun postLease(@Body request: LeaseRequest): Call<LeaseWrapper>

    @HTTP(method = "DELETE", path = "v1/lease", hasBody = true)
    fun deleteLease(@Body request: LeaseRequest): Call<Void>

    @POST("/v2/gplay/checkout")
    fun postGplayCheckout(@Body request: GoogleCheckoutRequest): Call<AccountWrapper>

}
