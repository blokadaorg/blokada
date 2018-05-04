package gs.main

import com.github.salomonbrys.kodein.instance
import gs.environment.inject

/**
 *
 */
class AUpdateDownloader(
        private val ctx: android.content.Context
) {

    private val dm by lazy { ctx.inject().instance<android.app.DownloadManager>() }
    private val j by lazy { ctx.inject().instance<gs.environment.Journal>() }

    private var enqueue: Long? = null
    private var links: List<java.net.URL> = emptyList()
    private var listener = { uri: android.net.Uri? -> }

    private val receiver: android.content.BroadcastReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: android.content.Context, intent: android.content.Intent) {
            unregister()
            if (enqueue == null) return
            val action = intent.action
            if (android.app.DownloadManager.ACTION_DOWNLOAD_COMPLETE == action) {
                val downloadId = intent.getLongExtra(android.app.DownloadManager.EXTRA_DOWNLOAD_ID, 0)
                val query = android.app.DownloadManager.Query()
                query.setFilterById(enqueue!!)
                enqueue = null
                val c = dm.query(query)
                if (c.moveToFirst()) {
                    val columnIndex = c.getColumnIndex(android.app.DownloadManager.COLUMN_STATUS)
                    if (android.app.DownloadManager.STATUS_SUCCESSFUL == c.getInt(columnIndex)) {
                        val uriString = c.getString(c.getColumnIndex(android.app.DownloadManager.COLUMN_LOCAL_URI))
                        links = emptyList()
                        listener(android.net.Uri.parse(uriString))
                    } else if (links.size > 1) {
                        downloadUpdate(links.subList(1, links.size), listener)
                    } else {
                        links = emptyList()
                        listener(null)
//                        j.event(Events.UPDATE_DOWNLOAD_FAIL)
                    }
                }
            }
        }
    }

    fun downloadUpdate(links: List<java.net.URL>, listener: (android.net.Uri?) -> Unit) {
        try { unregister() } catch (e: Exception) {}
        register()
        this.listener = listener
        this.links = links
        val request = android.app.DownloadManager.Request(android.net.Uri.parse(links[0].toExternalForm()))
        request.setDestinationInExternalFilesDir(ctx, null, "blokada-update.apk")
        enqueue = dm.enqueue(request)
//        j.event(Events.UPDATE_DOWNLOAD_START)
    }

    fun openInstall(uri: android.net.Uri) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            val openFileIntent = android.content.Intent(android.content.Intent.ACTION_VIEW)
            openFileIntent.addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
            openFileIntent.addFlags(android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
            openFileIntent.data = android.support.v4.content.FileProvider.getUriForFile(ctx, "${ctx.packageName}.update",
                    java.io.File(uri.path))
            ctx.startActivity(openFileIntent)
        } else {
            val fileUri = android.net.Uri.fromFile(java.io.File(uri.path)) // Because Android
            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW)
            intent.setDataAndType(fileUri, "application/vnd.android.package-archive")
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(intent)
        }
//        j.event(Events.UPDATE_INSTALL_ASK)
    }

    private fun register() {
        ctx.registerReceiver(receiver, android.content.IntentFilter(android.app.DownloadManager.ACTION_DOWNLOAD_COMPLETE))
    }

    private fun unregister() {
        ctx.unregisterReceiver(receiver)
    }
}

