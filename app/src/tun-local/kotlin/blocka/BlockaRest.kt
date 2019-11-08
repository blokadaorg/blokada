package blocka

import android.content.Context
import android.os.Build
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.bind
import com.github.salomonbrys.kodein.singleton
import com.google.gson.FieldNamingPolicy
import com.google.gson.GsonBuilder
import com.google.gson.annotations.SerializedName
import core.ProductType
import core.getActiveContext
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import org.blokada.BuildConfig
import retrofit2.Call
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.*
import tunnel.EXPIRATION_OFFSET
import tunnel.tunnelMain
import java.text.DateFormat
import java.util.*

interface BlockaRestApi {

    @GET("/v1/account")
    fun getAccountInfo(@Query("account_id") accountId: String): Call<BlockaRestModel.Account>

    @POST("/v1/account")
    fun newAccount(): Call<BlockaRestModel.Account>

    @GET("/v2/gateway")
    fun getGateways(): Call<BlockaRestModel.Gateways>

    @GET("/v1/lease")
    fun getLeases(@Query("account_id") accountId: String): Call<BlockaRestModel.Leases>

    @POST("/v1/lease")
    fun newLease(@Body request: BlockaRestModel.LeaseRequest): Call<BlockaRestModel.Lease>

    @HTTP(method = "DELETE", path = "v1/lease", hasBody = true)
    fun deleteLease(@Body request: BlockaRestModel.LeaseRequest): Call<Void>

}

object BlockaRestModel {
    data class Account(val account: AccountInfo)
    data class Lease(val lease: LeaseInfo)
    data class Gateways(val gateways: List<GatewayInfo>)
    data class Leases(val leases: List<LeaseInfo>)
    data class AccountInfo(
            @SerializedName("id")
            val accountId: String,
            @SerializedName("active_until")
            val activeUntil: Date = Date(0)
    ) {
        override fun toString(): String {
            return "AccountInfo(activeUntil=$activeUntil)"
        }
    }
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
            val expires: Date,
            val tags: List<String>?
    ) {
        fun niceName() = location.split('-').map { it.capitalize() }.joinToString(" ")
        fun overloaded() = resourceUsagePercent >= 100
//        fun partner() = location == "stockholm"
        fun partner() = tags?.contains("partner") ?: false
    }
    data class LeaseInfo(
            @SerializedName("account_id")
            val accountId: String,
            @SerializedName("public_key")
            val publicKey: String,
            @SerializedName("gateway_id")
            val gatewayId: String,
            val expires: Date,
            val alias: String?,
            val vip4: String,
            val vip6: String
    ) {
        fun expiresSoon() = expires.before(Date(Date().time + EXPIRATION_OFFSET))
        fun niceName() = if (alias?.isNotBlank() == true) alias else publicKey.take(5)

        override fun toString(): String {
            // No account ID
            return "LeaseInfo(publicKey='$publicKey', gatewayId='$gatewayId', expires=$expires, alias=$alias, vip4='$vip4', vip6='$vip6')"
        }
    }
    data class LeaseRequest(
            @SerializedName("account_id")
            val accountId: String,
            @SerializedName("public_key")
            val publicKey: String,
            @SerializedName("gateway_id")
            val gatewayId: String,
            val alias: String
    ) {
        override fun toString(): String {
            // No account ID
            return "LeaseRequest(publicKey='$publicKey', gatewayId='$gatewayId', alias='$alias')"
        }
    }
    class TooManyDevicesException : Exception()
}

fun blokadaUserAgent(ctx: Context = getActiveContext()!!, viewer: Boolean? = null)
    = "blokada/%s (android-%s %s %s %s %s-%s %s %s %s)".format(
        BuildConfig.VERSION_NAME,
        Build.VERSION.SDK_INT,
        BuildConfig.FLAVOR,
        BuildConfig.BUILD_TYPE,
        Build.SUPPORTED_ABIS[0],
        Build.MANUFACTURER,
        Build.DEVICE,
        if (ctx.packageManager.hasSystemFeature("android.hardware.touchscreen"))
            "touch" else "donttouch",
        if (viewer == true) "chrometab" else if (viewer == false) "webview" else "api",
        if (BoringtunLoader.supported) "compatible" else "incompatible"
)

fun newRestApiModule(ctx: Context): Kodein.Module {
    return Kodein.Module(init = {
        bind<BlockaRestApi>() with singleton {
//            val cp = ConnectionPool(1, 1, TimeUnit.MILLISECONDS)
            val clientBuilder = OkHttpClient.Builder()
//                    .connectionPool(cp)
                    .addNetworkInterceptor { chain ->
                        val request = chain.request()
                        chain.connection()?.socket()?.let {
                            //ctx.ktx("okhttp").v("protecting okhttp socket")
                            tunnelMain.protect(it)
                        }
                        chain.proceed(request)
                    }
                    .addInterceptor { chain ->
                        val request = chain.request().newBuilder().header("User-Agent", blokadaUserAgent(ctx)).build()
                        chain.proceed(request)
                    }
            if (!ProductType.isPublic()) clientBuilder.addInterceptor(HttpLoggingInterceptor().apply { level = HttpLoggingInterceptor.Level.BODY })
            val client = clientBuilder.build()
            val gson = GsonBuilder()
                    .setDateFormat(DateFormat.FULL)
                    .setFieldNamingPolicy(FieldNamingPolicy.LOWER_CASE_WITH_DASHES)
                    .create()
            val retrofit = Retrofit.Builder()
                    .baseUrl("https://api.blocka.net")
                    .addConverterFactory(GsonConverterFactory.create(gson))
                    .client(client)
                    .build()
            retrofit.create(BlockaRestApi::class.java)
        }
    })
}
