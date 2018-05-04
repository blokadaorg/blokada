package gs.environment

import java.io.BufferedReader
import java.io.File
import java.io.InputStream
import java.io.InputStreamReader
import java.net.URL

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

fun openUrl(url: URL, timeoutMillis: Int): InputStream {
    val c = url.openConnection()
    c.setRequestProperty("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.155 Safari/537.36");
    c.connectTimeout = timeoutMillis
    return c.getInputStream()
}

internal fun openFile(file: File): InputStream {
    return file.inputStream()
}