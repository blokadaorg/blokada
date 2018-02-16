package org.blokada.framework

import android.content.Context
import android.os.Environment
import java.io.File
import java.util.*

/**
 * Finds a reliable path to store persistence under.
 *
 * TODO: make more reliable.
 */
fun getPersistencePath(ctx: Context): File {
    val files = ctx.filesDir
    if (files != null) return files
    return ctx.cacheDir
}

/**
 * Find a path to store data under, that is accessible to all apps (and the user), null otherwise.
 */
fun getPublicPersistencePath(publicName: String): File? {
    return if (isExternalStorageWritable()) {
        val file = File(Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS), publicName)
        if (!file.exists()) file.mkdirs()
        file
    } else null
}

internal fun saveToCache(hosts: Collection<String>, cache: File) {
    try { cache.createNewFile() } catch (e: Exception) {}
    val w = java.io.PrintWriter(cache)
    w.print(hosts.joinToString("\n"))
    if (w.checkError()) throw Exception("could not save cache")
}

internal fun readFromCache(cache: File): List<String> {
    val hosts = mutableListOf<String>()
    val s = Scanner(cache).useDelimiter("\n")
    while (s.hasNext()) {
        hosts.add(s.next())
    }
    return hosts
}

internal fun isCacheValid(cache: File, ttlMillis: Long, nowMillis: Long): Boolean {
    try {
        return nowMillis - cache.lastModified() - ttlMillis < 0
    } catch (e: Exception) {
        return false
    }
}

private fun isExternalStorageWritable(): Boolean {
    val state = Environment.getExternalStorageState()
    if (Environment.MEDIA_MOUNTED.equals(state)) {
        return true
    }
    return false
}
