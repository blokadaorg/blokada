package blocka

import core.e
import core.v
import core.w
import retrofit2.Call
import retrofit2.Response

class ResponseCodeException(val code: Int) : Exception()

fun <T> simpleRetrofitHandler(
    call: Call<T>
): T {
    val response = call.execute()
    return when {
        response.code() != 200 -> {
            e("request failed", call.request().url(), response.code())
            throw ResponseCodeException(response.code())
        }
        response.body() == null && call.request().method() != "DELETE" -> {
            e(
                "request failed", call.request().url(), response.errorBody()?.string()
                    ?: "null"
            )
            throw Exception("failed request: empty body")
        }
        else -> {
            v("request ok", call.request().url())
            response.body()!!
        }
    }
}

@Deprecated("will become private")
val MAX_RETRIES = 3

class RetryingRetrofitHandler<T>(
    private val call: Call<T>
) {

    private var retries = 0

    fun execute(): T {
        return try {
            simpleRetrofitHandler(call)
        } catch (ex: Exception) {
            when {
                ex is ResponseCodeException && ex.code == 500 && ++retries < MAX_RETRIES -> {
                    w("retrying failed request", retries, call.request().url(), ex.code)
                    execute()
                }
                else -> throw ex
            }
        }
    }
}

class SimpleRetrofitCallback<T>(
    val ok: (T) -> Any,
    val fail: (Int) -> Any
) : retrofit2.Callback<T> {

    override fun onResponse(call: Call<T>, response: Response<T>) {
        when {
            response.code() != 200 -> {
                e("request failed", call.request().url(), response.code())
                fail(response.code())
            }
            response.body() == null && call.request().method() != "DELETE" -> {
                e(
                    "request failed", call.request().url(), response.errorBody()?.string()
                        ?: "null"
                )
                fail(0)
            }
            else -> {
                v("request ok", call.request().url())
                ok(response.body()!!)
            }
        }
    }

    override fun onFailure(call: Call<T>, t: Throwable) {
        e("request failed", call.request().url(), t)
        fail(-1)
    }

}

class RetryingRetrofitCallback<T>(
    val ok: (T) -> Any,
    val fail: (Int) -> Any
) : retrofit2.Callback<T> {

    val MAX_RETRIES = 3
    private var retries = 0

    private val callback = SimpleRetrofitCallback(ok, fail)

    override fun onResponse(call: Call<T>, response: Response<T>) {
        when {
            response.code() == 500 && ++retries < MAX_RETRIES -> {
                w("retrying failed request", retries, call.request().url(), response.code())
                call.enqueue(this)
            }
            else -> {
                retries = 0
                callback.onResponse(call, response)
            }
        }
    }

    override fun onFailure(call: Call<T>, t: Throwable) {
        if (++retries < MAX_RETRIES) {
            w("retrying failed request", retries, call.request().url(), t)
            call.enqueue(this)
        } else {
            retries = 0
            callback.onFailure(call, t)
        }
    }

}
