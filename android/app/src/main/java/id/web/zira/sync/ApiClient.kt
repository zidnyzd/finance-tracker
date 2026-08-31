package id.web.zira.sync

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

data class SyncRequest(
    @SerializedName("package_name") val packageName: String,
    @SerializedName("app_name") val appName: String,
    @SerializedName("title") val title: String,
    @SerializedName("text") val text: String,
    @SerializedName("post_time") val postTime: Long
)

data class SyncResponse(
    @SerializedName("success") val success: Boolean,
    @SerializedName("status") val status: String,
    @SerializedName("message") val message: String,
    @SerializedName("transaction_id") val transactionId: Long?,
    @SerializedName("amount") val amount: Double?,
    @SerializedName("type") val type: String?,
    @SerializedName("account") val account: String?,
    @SerializedName("category") val category: String?
)

object ApiClient {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .build()

    private val gson = Gson()
    private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

    fun sendNotification(
        serverUrl: String,
        apiToken: String,
        payload: SyncRequest,
        callback: (Boolean, SyncResponse?, String?) -> Unit
    ) {
        val endpoint = "${serverUrl.trimEnd('/')}/api/v1/sync-notification"
        val json = gson.toJson(payload)
        val body = json.toRequestBody(JSON_MEDIA_TYPE)

        val request = Request.Builder()
            .url(endpoint)
            .addHeader("Authorization", "Bearer $apiToken")
            .addHeader("Content-Type", "application/json")
            .addHeader("User-Agent", "ZiRa-Sync-Android/1.0")
            .post(body)
            .build()

        client.newCall(request).enqueue(object : okhttp3.Callback {
            override fun onFailure(call: okhttp3.Call, e: IOException) {
                callback(false, null, "Koneksi gagal: ${e.localizedMessage}")
            }

            override fun onResponse(call: okhttp3.Call, response: okhttp3.Response) {
                val respBody = response.body?.string() ?: ""
                try {
                    val syncResp = gson.fromJson(respBody, SyncResponse::class.java)
                    if (response.isSuccessful && syncResp != null) {
                        callback(true, syncResp, null)
                    } else {
                        val errMsg = syncResp?.message ?: "HTTP ${response.code}: $respBody"
                        callback(false, syncResp, errMsg)
                    }
                } catch (e: Exception) {
                    callback(false, null, "Format balasan salah (${response.code})")
                }
            }
        })
    }
}
