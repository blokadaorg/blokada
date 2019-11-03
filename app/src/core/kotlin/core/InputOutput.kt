package core

import android.os.Environment
import java.io.BufferedReader
import java.io.File
import java.io.InputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLConnection
import java.util.zip.GZIPInputStream

fun load(opener: () -> InputStream, lineProcessor: (String) -> String? = { it }): List<String> {
    val input = BufferedReader(InputStreamReader(opener()))

    val response = mutableListOf<String>()
    var line: String?

    try {
        do {
            line = input.readLine()
            if (line == null) break
            line = lineProcessor(line)
            if (line != null) response.add(line)
        } while (true)
    } finally {
        input.close()
    }

    return response
}

fun loadGzip(opener: () -> URLConnection, lineProcessor: (String) -> String? = { it }): List<String> {
    val input = createStream(opener())

    val response = mutableListOf<String>()
    var line: String?

    try {
        do {
            line = input.readLine()
            if (line == null) break
            line = lineProcessor(line)
            if (line != null) response.add(line)
        } while (true)
    } finally {
        input.close()
    }

    return response
}


fun loadGzip(opener: () -> URLConnection): String {
    val input = createStream(opener())
    val response: String

    try {
        response = input.readText()
    } finally {
        input.close()
    }

    return response
}

fun loadAsString(opener: () -> URLConnection): String {
    val input = createStream(opener())

    return try {
        input.readText()
    } catch (ex: Exception) {
        e("failed loading stream as string", ex)
        ""
    } finally {
        input.close()
    }
}

fun createStream(con: URLConnection) = {
    val charset = "UTF-8"
    if (con.contentEncoding == "gzip" || con.url.file.endsWith(".gz")) {
        "http".ktx().v("using gzip download", con.url)
        BufferedReader(InputStreamReader(GZIPInputStream(con.getInputStream()), charset))
    } else {
        BufferedReader(InputStreamReader(con.getInputStream(), charset))
    }
}()

fun openUrl(url: URL, timeoutMillis: Int) = {
    val c = url.openConnection() as HttpURLConnection
    c.setRequestProperty("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.155 Safari/537.36");
    c.setRequestProperty("Accept-Encoding", "gzip")
    c.connectTimeout = timeoutMillis
    c.readTimeout = timeoutMillis
    c.instanceFollowRedirects = true
    c
}

internal fun openFile(file: File): InputStream {
    return file.inputStream()
}

fun getExternalPath(): String {
    var path = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
    path = File(path, "blokada")
    path.mkdirs()
    return path.canonicalPath
}
