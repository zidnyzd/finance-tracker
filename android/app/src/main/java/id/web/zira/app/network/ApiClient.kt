package id.web.zira.app.network

import com.google.gson.Gson
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

object ApiClient {
    const val BASE_URL = "https://zira.web.id"
    private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
    private val gson = Gson()

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .build()

    fun <T> post(
        path: String,
        bodyData: Any,
        token: String? = null,
        responseClass: Class<T>,
        callback: (Boolean, T?, String?) -> Unit
    ) {
        val url = "$BASE_URL$path"
        val json = gson.toJson(bodyData)
        val body = json.toRequestBody(JSON_MEDIA_TYPE)

        val builder = Request.Builder()
            .url(url)
            .post(body)
            .addHeader("Content-Type", "application/json")
            .addHeader("User-Agent", "ZiRa-Native-Android/1.0")

        if (!token.isNullOrEmpty()) {
            builder.addHeader("Authorization", "Bearer $token")
        }

        client.newCall(builder.build()).enqueue(object : okhttp3.Callback {
            override fun onFailure(call: okhttp3.Call, e: IOException) {
                callback(false, null, "Koneksi gagal: ${e.localizedMessage}")
            }

            override fun onResponse(call: okhttp3.Call, response: okhttp3.Response) {
                val respStr = response.body?.string() ?: ""
                try {
                    val parsed = gson.fromJson(respStr, responseClass)
                    if (response.isSuccessful && parsed != null) {
                        callback(true, parsed, null)
                    } else {
                        callback(false, parsed, "Error (${response.code})")
                    }
                } catch (e: Exception) {
                    callback(false, null, "Format data server tidak valid: $respStr")
                }
            }
        })
    }

    fun <T> get(
        path: String,
        token: String,
        responseClass: Class<T>,
        callback: (Boolean, T?, String?) -> Unit
    ) {
        val url = "$BASE_URL$path"
        val request = Request.Builder()
            .url(url)
            .get()
            .addHeader("Authorization", "Bearer $token")
            .addHeader("User-Agent", "ZiRa-Native-Android/1.0")
            .build()

        client.newCall(request).enqueue(object : okhttp3.Callback {
            override fun onFailure(call: okhttp3.Call, e: IOException) {
                callback(false, null, "Koneksi gagal: ${e.localizedMessage}")
            }

            override fun onResponse(call: okhttp3.Call, response: okhttp3.Response) {
                val respStr = response.body?.string() ?: ""
                try {
                    val parsed = gson.fromJson(respStr, responseClass)
                    if (response.isSuccessful && parsed != null) {
                        callback(true, parsed, null)
                    } else {
                        callback(false, parsed, "Error (${response.code})")
                    }
                } catch (e: Exception) {
                    callback(false, null, "Format data server tidak valid")
                }
            }
        })
    }
}
