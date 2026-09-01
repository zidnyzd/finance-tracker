package id.web.zira.app.network

import android.content.Context
import androidx.work.*
import com.google.gson.Gson
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

class SyncWorker(context: Context, workerParams: WorkerParameters) : Worker(context, workerParams) {

    override fun doWork(): Result {
        val payloadJson = inputData.getString("payload") ?: return Result.failure()
        val token = inputData.getString("token") ?: return Result.failure()

        val client = OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .build()

        val mediaType = "application/json; charset=utf-8".toMediaType()
        val body = payloadJson.toRequestBody(mediaType)
        val request = Request.Builder()
            .url("https://zira.web.id/api/v1/sync-notification")
            .header("Authorization", "Bearer $token")
            .post(body)
            .build()

        return try {
            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                Result.success()
            } else if (response.code in 400..499) {
                Result.failure() // Client error, don't retry endlessly
            } else {
                Result.retry() // Server 5xx error, retry
            }
        } catch (e: Exception) {
            Result.retry() // Network failure, retry when connected
        }
    }
}
