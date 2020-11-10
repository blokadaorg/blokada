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
private const val SEPARATOR = "         "

private fun tag(tag: String) = "$LOG_DEFAULT_TAG:${Thread.currentThread().name}"

private fun format(priority: Int, msg: Any, params: String) = "$msg$SEPARATOR$params"

private val logcatWriter = { priority: Int, tag: String, line: String ->
    android.util.Log.println(priority, tag, line)
}

val systemWriter = { priority: Int, tag: String, line: String ->
    if (priority == LOG_ERROR) System.err.println("$tag $line")
    else System.out.println("$tag $line")
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
//        try {
//            val path = File(ctx.filesDir, "blokada.log")
//            val writer = PrintWriter(FileOutputStream(path, true), true)
//            if (path.length() > 4 * 1024 * 1024) path.delete()
//            logcatWriter(LOG_VERBOSE, LOG_DEFAULT_TAG, "writing logs to file: ${path.canonicalPath}")
//            writer
//        } catch (ex: Exception) {
//            logcatWriter(LOG_WARNING, LOG_DEFAULT_TAG, "fail opening log file: ${ex.message}")
//            null
//        }
    }

    @Synchronized
    internal fun writer(priority: Int, tag: String, line: String) {
//        Result.of { file!!.println(time() + priority(priority) + tag + line) }
        logcatWriter(priority, tag, line)
    }

    @Synchronized
    internal fun exceptionWriter(priority: Int, tag: String, ex: Throwable) {
//        Result.of { ex.printStackTrace(file) }
        logcatExceptionWriter(priority, tag, ex)
    }

    private val formatter = SimpleDateFormat("MM-dd HH:mm:ss.SSS")
    private fun time() = formatter.format(Date())

    private fun priority(priority: Int) = when (priority) {
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

fun e(vararg msgs: Any) {
    write(PRIORITY_ERROR, tag(), line(msgs[0], params(*msgs)))
    msgs.filter { it is Throwable }.forEach {
        writeException(PRIORITY_ERROR, tag(), it as Throwable)
    }
}

fun w(vararg msgs: Any) {
    write(PRIORITY_WARNING, tag(), line(msgs[0], params(*msgs)))
    msgs.filter { it is Throwable }.forEach {
        writeException(PRIORITY_WARNING, tag(), it as Throwable)
    }
}

fun v(vararg msgs: Any) {
    write(PRIORITY_VERBOSE, tag(), line(msgs[0], params(*msgs)))
}

private const val TAG_TEMPLATE = "b4:%s"
private const val LINE_TEMPLATE = "%s    %s"
private const val FILE_LINE_TEMPLATE = "%s %s %s %s"
private const val PRIORITY_ERROR = 6
private const val PRIORITY_WARNING = 5
private const val PRIORITY_VERBOSE = 2

private fun tag() = TAG_TEMPLATE.format(Thread.currentThread().name)

private fun line(msg: Any, params: String) = LINE_TEMPLATE.format(msg, params)

private fun params(vararg msgs: Any) = msgs
        .drop(1)
        .map { it.toString() }
        .joinToString(", ")

var LOGGER_TEST = false

private fun write(priority: Int, tag: String, line: String) {
    if (!LOGGER_TEST) {
        android.util.Log.println(priority, tag, line)
        try {
            logFile?.println(FILE_LINE_TEMPLATE.format(
                    time(), priorityToLetter(priority), tag, line
            ))
        } catch (ex: Exception) {
        }
    } else systemWriter(priority, tag, line)
}

private fun writeException(priority: Int, tag: String, ex: Throwable) {
    if (!LOGGER_TEST) {
        android.util.Log.println(priority, tag, android.util.Log.getStackTraceString(ex))
        try {
            ex.printStackTrace(logFile)
        } catch (e: Exception) {
        }
    } else systemExceptionWriter(priority, tag, ex)
}


private val logFile by lazy {
    try {
        val path = File(getActiveContext()!!.filesDir, "blokada.log")
        val writer = PrintWriter(FileOutputStream(path, true), true)
        if (path.length() > 4 * 1024 * 1024) path.delete()
        android.util.Log.println(android.util.Log.VERBOSE, tag(),
                "writing logs to file: ${path.canonicalPath}")
        writer
    } catch (ex: Exception) {
        android.util.Log.println(android.util.Log.WARN, tag(), "failed to open log file")
        android.util.Log.println(android.util.Log.WARN, tag(),
                android.util.Log.getStackTraceString(ex)
        )
        null
    }
}

private val dateFormatter = SimpleDateFormat("MM-dd HH:mm:ss.SSS")

private fun priorityToLetter(priority: Int) = when (priority) {
    PRIORITY_ERROR -> "E"
    PRIORITY_WARNING -> "W"
    else -> "V"
}

private fun time() = dateFormatter.format(Date())
