package tunnel

import android.content.Context
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.bind
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.singleton
import com.google.gson.FieldNamingPolicy
import com.google.gson.GsonBuilder
import com.google.gson.annotations.SerializedName
import okhttp3.OkHttpClient
import retrofit2.Call
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Query
import java.text.DateFormat
import java.util.*

interface RestApi {

    @GET("/v1/account")
    fun getAccountInfo(@Query("account_id") accountId: String): Call<RestModel.Account>

    @POST("/v1/account")
    fun newAccount(): Call<RestModel.Account>

    @GET("/v1/gateway")
    fun getGateways(): Call<RestModel.Gateways>

    @GET("/v1/lease")
    fun getLeases(@Query("account_id") accountId: String): Call<RestModel.Leases>

    @POST("/v1/lease")
    fun newLease(@Body request: RestModel.LeaseRequest): Call<RestModel.Lease>

}

object RestModel {
    data class Account(val account: AccountInfo)
    data class Lease(val lease: LeaseInfo)
    data class Gateways(val gateways: List<GatewayInfo>)
    data class Leases(val leases: List<LeaseInfo>)
    data class AccountInfo(
            @SerializedName("id")
            val accountId: String,
            @SerializedName("active_until")
            val activeUntil: Date,
            @SerializedName("active_leases")
            val activeLeases: Int
    )
    data class GatewayInfo(
            @SerializedName("public_key")
            val publicKey: String,
            val region: String,
            val location: String,
            @SerializedName("resource_usage_percent")
            val resourceUsagePercent: Int,
            val ipv4: String,
            val ipv6: String,
            val port: Int,
            val expires: Date
    ) {
        fun niceName() = location.split('-').map { it.capitalize() }.joinToString(" ")
    }
    data class LeaseInfo(
            @SerializedName("account_id")
            val accountId: String,
            @SerializedName("public_key")
            val publicKey: String,
            @SerializedName("gateway_id")
            val gatewayId: String,
            val expires: Date,
            val vip4: String,
            val vip6: String
    )
    data class LeaseRequest(
            @SerializedName("account_id")
            val accountId: String,
            @SerializedName("public_key")
            val publicKey: String,
            @SerializedName("gateway_id")
            val gatewayId: String
    )
}

fun newRestApiModule(ctx: Context): Kodein.Module {
    return Kodein.Module(init = {
        bind<RestApi>() with singleton {
            val tun: tunnel.Main = instance()
            val client = OkHttpClient.Builder()
                    .addNetworkInterceptor { chain ->
                        val request = chain.request()
                        chain.connection()?.socket()?.let {
                            tun.protect(it)
                        }
                        chain.proceed(request)
                    }
                    .build()
            val gson = GsonBuilder()
                    .setDateFormat(DateFormat.FULL)
                    .setFieldNamingPolicy(FieldNamingPolicy.LOWER_CASE_WITH_DASHES)
                    .create()
            val retrofit = Retrofit.Builder()
                    .baseUrl("https://api.blocka.net")
                    .addConverterFactory(GsonConverterFactory.create(gson))
                    .client(client)
                    .build()
            retrofit.create(RestApi::class.java)
        }
    })
}
