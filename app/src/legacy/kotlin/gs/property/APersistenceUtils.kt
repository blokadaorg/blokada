package gs.property

import java.io.BufferedReader
import java.io.FileReader

/**
 * Finds a reliable path to store persistence under.
 *
 * TODO: make more reliable.
 */
fun getPersistencePath(ctx: android.content.Context): java.io.File {
    val files = ctx.filesDir
    if (files != null) return files
    return ctx.cacheDir
}

/**
 * Find a path to store data under, that is accessible to all apps (and the user), null otherwise.
 */
fun getPublicPersistencePath(publicName: String): java.io.File? {
    return if (gs.property.isExternalStorageWritable()) {
        val file = java.io.File(android.os.Environment.getExternalStoragePublicDirectory(
                android.os.Environment.DIRECTORY_DOWNLOADS), publicName)
        if (!file.exists()) file.mkdirs()
        file
    } else null
}

fun saveToCache(hosts: Collection<String>, cache: java.io.File) {
    try { cache.createNewFile() } catch (e: Exception) {}
    val w = java.io.PrintWriter(cache)
    w.print(hosts.joinToString("\n"))
    if (w.checkError()) throw Exception("could not save cache")
}

fun readFromCache(cache: java.io.File): Set<String> {
    val bf = BufferedReader(FileReader(cache))
    return bf.lineSequence().toSet()
}

fun isCacheValid(cache: java.io.File, ttlMillis: Long, nowMillis: Long): Boolean {
    try {
        return nowMillis - cache.lastModified() - ttlMillis < 0
    } catch (e: Exception) {
        return false
    }
}

private fun isExternalStorageWritable(): Boolean {
    val state = android.os.Environment.getExternalStorageState()
    if (android.os.Environment.MEDIA_MOUNTED.equals(state)) {
        return true
    }
    return false
}
