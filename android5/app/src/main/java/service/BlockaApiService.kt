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

package repository

import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import model.*
import retrofit2.Call
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.*
import service.HttpService
import service.JsonSerializationService


object BlockaDataSource {

    private val http = HttpService
    private val scope = GlobalScope

    private val retrofit = Retrofit.Builder()
        .baseUrl("https://api.blocka.net")
        .addConverterFactory(MoshiConverterFactory.create(JsonSerializationService.moshi))
        .client(http.getClient())
        .build()

    private val api = retrofit.create(BlockaRestApi::class.java)

    suspend fun postAccount(): Account {
        return async {
            api.newAccount().execute().resultOrThrow().account
        }
    }

    suspend fun getAccount(id: AccountId): Account {
        return async {
            api.getAccountInfo(id).execute().resultOrThrow().account
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
            api.newLease(request).execute().resultOrThrow().lease
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
    fun getAccountInfo(@Query("account_id") accountId: String): Call<AccountWrapper>

    @POST("/v1/account")
    fun newAccount(): Call<AccountWrapper>

    @GET("/v2/gateway")
    fun getGateways(): Call<Gateways>

    @GET("/v1/lease")
    fun getLeases(@Query("account_id") accountId: String): Call<Leases>

    @POST("/v1/lease")
    fun newLease(@Body request: LeaseRequest): Call<LeaseWrapper>

    @HTTP(method = "DELETE", path = "v1/lease", hasBody = true)
    fun deleteLease(@Body request: LeaseRequest): Call<Void>

}
