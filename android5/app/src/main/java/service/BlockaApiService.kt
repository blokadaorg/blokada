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

import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import model.*
import retrofit2.Call
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.*


object BlockaApiService {

    private val http = HttpService
    private val scope = GlobalScope

    private val retrofit = Retrofit.Builder()
        .baseUrl("https://api.blocka.net")
        .addConverterFactory(MoshiConverterFactory.create(JsonSerializationService.moshi))
        .client(http.getClient())
        .build()

    private val api = retrofit.create(BlockaRestApi::class.java)

    suspend fun getAccount(id: AccountId): Account {
        return async {
            api.getAccount(id).execute().resultOrThrow().account
        }
    }

    suspend fun postNewAccount(): Account {
        return async {
            api.postNewAccount().execute().resultOrThrow().account
        }
    }

    suspend fun getDevice(id: AccountId): DevicePayload {
        return async {
            api.getDevice(id).execute().resultOrThrow()
        }
    }

    suspend fun putDevice(request: DeviceRequest): Void {
        return async {
            api.putDevice(request).execute().resultOrThrow()
        }
    }

    suspend fun getActivity(id: AccountId): List<Activity> {
        return async {
            api.getActivity(id).execute().resultOrThrow().activity
        }
    }

    suspend fun getCustomList(id: AccountId): List<CustomListEntry> {
        return async {
            api.getCustomList(id).execute().resultOrThrow().customlist
        }
    }

    suspend fun postCustomList(request: CustomListRequest): Void {
        return async {
            api.postCustomList(request).execute().resultOrThrow()
        }
    }

    suspend fun deleteCustomList(request: CustomListRequest): Void {
        return async {
            api.deleteCustomList(request).execute().resultOrThrow()
        }
    }

    suspend fun getStats(id: AccountId): CounterStats {
        return async {
            api.getStats(id).execute().resultOrThrow()
        }
    }

    suspend fun getBlocklists(id: AccountId): List<Blocklist> {
        return async {
            api.getBlocklists(id).execute().resultOrThrow().lists
        }
    }

    suspend fun getGateways(): List<Gateway> {
        return async {
            api.getGateways().execute().resultOrThrow().gateways
        }
    }

    suspend fun getLeases(id: AccountId): List<Lease> {
        return async {
            api.getLeases(id).execute().resultOrThrow().leases
        }
    }

    suspend fun postLease(request: LeaseRequest): Lease {
        return async {
            api.postLease(request).execute().resultOrThrow().lease
        }
    }

    suspend fun deleteLease(request: LeaseRequest) {
        return async {
            api.deleteLease(request).execute()
        }
    }

    private fun <T> Response<T>.resultOrThrow(): T {
        if (!isSuccessful) when (code()) {
            403 -> throw TooManyDevices()
            else -> throw BlokadaException("Response: ${code()}: ${errorBody()}")
        } else return body()!!
    }

    private suspend fun <T> async(block: () -> T): T {
        return scope.async {
            mapException(block)
        }.await()
    }

    private fun <T> mapException(block: () -> T): T {
        try {
            return block()
        } catch (ex: BlokadaException) {
            throw ex
        } catch (ex: Exception) {
            throw BlokadaException("Api request failed", ex)
        }
    }
}

interface BlockaRestApi {

    @GET("/v1/account")
    fun getAccount(@Query("account_id") id: AccountId): Call<AccountWrapper>

    @POST("/v1/account")
    fun postNewAccount(): Call<AccountWrapper>

    @GET("/v1/device")
    fun getDevice(@Query("account_id") id: AccountId): Call<DevicePayload>

    @PUT("/v1/device")
    fun putDevice(@Body request: DeviceRequest): Call<Void>

    @GET("/v1/activity")
    fun getActivity(@Query("account_id") id: AccountId): Call<ActivityWrapper>

    @GET("/v1/customlist")
    fun getCustomList(@Query("account_id") id: AccountId): Call<CustomListWrapper>

    @POST("/v1/customlist")
    fun postCustomList(@Body request: CustomListRequest): Call<Void>

    @HTTP(method = "DELETE", path = "v1/customlist", hasBody = true)
    fun deleteCustomList(@Body request: CustomListRequest): Call<Void>

    @GET("/v1/stats")
    fun getStats(@Query("account_id") id: AccountId): Call<CounterStats>

    @GET("/v1/lists")
    fun getBlocklists(@Query("account_id") id: AccountId): Call<BlocklistWrapper>

    @GET("/v2/gateway")
    fun getGateways(): Call<Gateways>

    @GET("/v1/lease")
    fun getLeases(@Query("account_id") accountId: AccountId): Call<Leases>

    @POST("/v1/lease")
    fun postLease(@Body request: LeaseRequest): Call<LeaseWrapper>

    @HTTP(method = "DELETE", path = "v1/lease", hasBody = true)
    fun deleteLease(@Body request: LeaseRequest): Call<Void>

}
