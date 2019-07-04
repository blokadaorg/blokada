package core

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.io.PrintWriter
import java.text.SimpleDateFormat
import java.util.*

interface Log {
    fun e(vararg msgs: Any)
    fun w(vararg msgs: Any)
    fun v(vararg msgs: Any)
}

private const val LOG_DEFAULT_TAG = "b4"
private const val LOG_ERROR = 6
private const val LOG_WARNING = 5
private const val LOG_VERBOSE = 2
private const val SEPARATOR = "   <--   "

private fun tag(tag: String) = "$LOG_DEFAULT_TAG:$tag"

private fun format(priority: Int, msg: Any, params: String)
        = "${indent(priority)}$msg$SEPARATOR$params"

private fun params(vararg msgs: Any) = msgs.drop(1).map { it.toString() }
                .plus(Thread.currentThread())
                .joinToString(", ")

private fun indent(priority: Int, level: Int = 0): String {
    var indent = 3
    if (priority == LOG_VERBOSE) indent += 4
    indent += 4 * level
    return " ".repeat(indent)
}

private val logcatWriter = { priority: Int, tag: String, line: String ->
    android.util.Log.println(priority, tag, line)
}

val systemWriter = { priority: Int, tag: String, line: String ->
    if (priority == LOG_ERROR) System.err.println(tag + line)
    else System.out.println(tag + line)
}

val systemExceptionWriter = { priority: Int, tag: String, ex: Throwable ->
    ex.printStackTrace(if (priority == LOG_ERROR) System.err else System.out)
}

private val logcatExceptionWriter = { priority: Int, tag: String, ex: Throwable ->
    android.util.Log.println(priority, tag, android.util.Log.getStackTraceString(ex))
}

val defaultWriter by lazy { FileLogWriter() }

class FileLogWriter {

    lateinit var ctx: Context

    private val file by lazy {
        try {
            val path = File(ctx.filesDir, "blokada.log")
            val writer = PrintWriter(FileOutputStream(path, true), true)
            if (path.length() > 4 * 1024 * 1024) path.delete()
            logcatWriter(LOG_VERBOSE, LOG_DEFAULT_TAG, "writing logs to file: ${path.canonicalPath}")
            writer
        } catch (ex: Exception) {
            logcatWriter(LOG_WARNING, LOG_DEFAULT_TAG, "fail opening log file: ${ex.message}")
            null
        }
    }

    @Synchronized internal fun writer(priority: Int, tag: String, line: String) {
        Result.of { file!!.println(time() + priority(priority) + tag + line) }
        logcatWriter(priority, tag, line)
    }

    @Synchronized internal fun exceptionWriter(priority: Int, tag: String, ex: Throwable) {
        Result.of { ex.printStackTrace(file) }
        logcatExceptionWriter(priority, tag, ex)
    }

    private val formatter = SimpleDateFormat("MM-dd HH:mm:ss.SSS")
    private fun time() = formatter.format(Date())

    private fun priority(priority: Int) = when(priority) {
        6 -> " E "
        5 -> " W "
        else -> " V "
    }
}

class DefaultLog(
        private val tag: String,
        private val writer: (Int, String, String) -> Any = defaultWriter::writer,
        private val exceptionWriter: (Int, String, Throwable) -> Any = defaultWriter::exceptionWriter
) : Log {

    override fun e(vararg msgs: Any) {
        writer(LOG_ERROR, tag(tag), format(LOG_ERROR, msgs[0], params(*msgs)))
        msgs.filter { it is Throwable }.forEach {
            exceptionWriter(LOG_ERROR, tag(tag), it as Throwable)
        }
    }

    override fun w(vararg msgs: Any) {
        writer(LOG_WARNING, tag(tag), format(LOG_WARNING, msgs[0], params(*msgs)))
        msgs.filter { it is Throwable }.forEach {
            exceptionWriter(LOG_WARNING, tag(tag), it as Throwable)
        }
    }

    override fun v(vararg msgs: Any) {
        writer(LOG_VERBOSE, tag(tag), format(LOG_VERBOSE, msgs[0], params(*msgs)))
    }
}

