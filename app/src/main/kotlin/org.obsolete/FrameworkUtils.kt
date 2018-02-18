package org.obsolete

import gs.environment.Journal
import nl.komponents.kovenant.Kovenant
import nl.komponents.kovenant.buildDispatcher
import java.io.BufferedReader
import java.io.File
import java.io.InputStream
import java.io.InputStreamReader
import java.net.URL

class Sync<T>(private var value: T) {
    @Synchronized fun get(): T {
        return value
    }

    @Synchronized fun set(newValue: T) {
        value = newValue
    }
}

fun String.nullIfEmpty(): String? {
    return if (this.isEmpty()) null else this
}

internal fun hasCompleted(j: Journal?, f: () -> Unit): Pair<Boolean, Exception?> {
    return try { f(); true to null } catch (e: Exception) { j?.log(e); false to e }
}

internal fun load(opener: () -> InputStream, lineProcessor: (String) -> String? = { it }): List<String> {
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

internal fun openUrl(url: URL, timeoutMillis: Int): InputStream {
    val c = url.openConnection()
    c.setRequestProperty("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.155 Safari/537.36")
    c.connectTimeout = timeoutMillis
    return c.getInputStream()
}

fun newConcurrentKContext(j: Journal?, prefix: String, tasks: Int): KContext {
    return Kovenant.createContext {
        callbackContext.dispatcher = buildDispatcher {
            name = "$prefix-callbackX"
            concurrentTasks = 1
            errorHandler = { j?.log(it) }
            exceptionHandler = { j?.log(it) }
        }
        workerContext.dispatcher = buildDispatcher {
            name = "$prefix-workerX"
            concurrentTasks = tasks
            errorHandler = { j?.log(it) }
            exceptionHandler = { j?.log(it) }
        }
    }
}

fun <T> Sequence<T>.batch(n: Int): Sequence<List<T>> {
    return BatchingSequence(this, n)
}

private class BatchingSequence<T>(val source: Sequence<T>, val batchSize: Int) : Sequence<List<T>> {
    override fun iterator(): Iterator<List<T>> = object : AbstractIterator<List<T>>() {
        val iterate = if (batchSize > 0) source.iterator() else emptyList<T>().iterator()
        override fun computeNext() {
            if (iterate.hasNext()) setNext(iterate.asSequence().take(batchSize).toList())
            else done()
        }
    }
}
