package update

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import com.github.salomonbrys.kodein.instance
import core.emit
import core.newEventOf
import gs.environment.inject
import kotlinx.coroutines.experimental.android.UI
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.delay
import java.io.File
import java.net.URL


val EVENT_UPDATE_PROGRESS = "EVENT_UPDATE_PROGRESS".newEventOf<Int>()
val DOWNLOAD_COMPLETE = 100
val DOWNLOAD_FAIL = -1

/**
 *
 */
class AUpdateDownloader(
        private val ctx: Context
) {

    private val dm by lazy { ctx.inject().instance<DownloadManager>() }

    private var enqueue: Long? = null
    private var links: List<java.net.URL> = emptyList()
    private var listener = { uri: android.net.Uri? -> }

    private val receiver: BroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            unregister()
            if (enqueue == null) return
            val action = intent.action
            if (DownloadManager.ACTION_DOWNLOAD_COMPLETE == action) {
                val query = DownloadManager.Query()
                query.setFilterById(enqueue!!)
                enqueue = null
                val c = dm.query(query)
                if (c.moveToFirst()) {
                    val columnIndex = c.getColumnIndex(DownloadManager.COLUMN_STATUS)
                    if (DownloadManager.STATUS_SUCCESSFUL == c.getInt(columnIndex)) {
                        val uriString = c.getString(c.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI))
                        links = emptyList()
                        listener(Uri.parse(uriString))
                    } else if (links.size > 1) {
                        downloadUpdate(links.subList(1, links.size), listener)
                    } else {
                        links = emptyList()
                        listener(null)
                    }
                }
            }
        }
    }

    fun downloadUpdate(links: List<URL>, listener: (Uri?) -> Unit) {
        try { unregister() } catch (e: Exception) {}
        register()
        this.listener = listener
        this.links = links
        val request = DownloadManager.Request(Uri.parse(links[0].toExternalForm()))
        request.setDestinationInExternalFilesDir(ctx, null, "blokada-update.apk")
        enqueue = dm.enqueue(request)
        monitorDownloadProgress()
    }

    fun openInstall(uri: Uri) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val openFileIntent = Intent(Intent.ACTION_VIEW)
            openFileIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            openFileIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            openFileIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            openFileIntent.data = FileProvider.getUriForFile(ctx, "${ctx.packageName}.files",
                    File(uri.path))
            ctx.startActivity(openFileIntent)
        } else {
            val fileUri = Uri.fromFile(File(uri.path)) // Because Android
            val intent = Intent(Intent.ACTION_VIEW)
            intent.setDataAndType(fileUri, "application/vnd.android.package-archive")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(intent)
        }
    }

    private fun register() {
        ctx.registerReceiver(receiver, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE))
    }

    private fun unregister() {
        ctx.unregisterReceiver(receiver)
    }

    private fun getDownloadPercentage(): Int {
        if (enqueue == null) return DOWNLOAD_COMPLETE

        val query = DownloadManager.Query()
        query.setFilterById(enqueue!!)
        val c = dm.query(query)
        if (c.moveToFirst()) {
            val bytes_downloaded = c.getInt(c.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
            val bytes_total = c.getInt(c.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
            return ((bytes_downloaded / bytes_total.toFloat()) * 100).toInt()
        } else return DOWNLOAD_FAIL
    }

    private fun monitorDownloadProgress() = async {
        var downloading = true
        while (downloading) {
            delay(2000)
            async(UI) {
                val progress = getDownloadPercentage()
                emit(EVENT_UPDATE_PROGRESS, progress)
                if (progress in listOf(DOWNLOAD_FAIL, DOWNLOAD_COMPLETE)) downloading = false
            }
        }
    }
}

