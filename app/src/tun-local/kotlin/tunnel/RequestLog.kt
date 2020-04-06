package tunnel

import adblocker.CsvLogWriter
import android.util.Log
import com.github.michaelbull.result.getOr
import core.PaperSource
import core.Register
import core.Register.set
import core.emit
import core.get
import java.io.Closeable
import java.lang.IndexOutOfBoundsException
import java.net.InetAddress
import java.util.*

data class LogConfig(
        val logActive: Boolean = true,
        val csvLogAllowed: Boolean = false,
        val csvLogDenied: Boolean = false,
        val dropCount: Int = 0,
        val dropStart: Long = System.currentTimeMillis()
)

class RequestLog() : /*MutableList<ExtendedRequest>,*/ Closeable {

    private data class RequestLogBatch(
            var list: List<ExtendedRequest>,
            val minSize: Int,
            var loaded: Boolean
    )

    val size
        get() = totalSize

    companion object{
        private const val REQUEST_LOG_CATEGORY = "log-batch"
        private var batch0: MutableList<ExtendedRequest> = Persistence.request.load(REQUEST_LOG_CATEGORY, 0).getOr { emptyList()}.toMutableList()
        var lastDomain = if(batch0.isEmpty()) { "" } else { batch0[0].domain }
            private set
        var lastBlockedDomain = batch0.find { it.blocked }?.domain ?: ""
            private set
        var dropCount: Int = get(LogConfig::class.java).dropCount
            private set
        var dropStart: Long = get(LogConfig::class.java).dropStart
            private set
        private val batches: MutableList<RequestLogBatch> = mutableListOf(
                RequestLogBatch(batch0, 50, true),
                RequestLogBatch(emptyList(), 125, false),
                RequestLogBatch(emptyList(), 500, false))
        private val csvLogWriter = CsvLogWriter()
        private var totalSize: Int = 0

        private fun getBatch(index: Int): List<ExtendedRequest> {
            if (index >= batches.size) {
                throw IndexOutOfBoundsException()
            }
            return if (batches[index].loaded) {
                    batches[index].list
                } else {
                    Persistence.request.load(REQUEST_LOG_CATEGORY, index).getOr { emptyList() }
                }
        }

        private fun rollIfNeeded() {
            val loggerConfig = get(LogConfig::class.java)
            val smartConfig = get(SmartListConfig::class.java)
            for (i in batches.indices) {
                if(loggerConfig.logActive) {
                    var batch = getBatch(i)
                    val batchLoaded = batches[i].loaded
                    val minSize = batches[i].minSize
                    val maxSize = minSize * 2

                    if (batch.size > maxSize) {
                        if (i < batches.size - 1) {
                            val nextBatchLoaded = batches[i + 1].loaded
                            val nextBatch = batch.subList(minSize, batch.size) + getBatch(i + 1)
                            Persistence.request.saveBatch(REQUEST_LOG_CATEGORY, i + 1, nextBatch)
                            if (nextBatchLoaded) {
                                batches[i + 1].list = nextBatch
                            }
                        } else if (smartConfig.state != SmartListState.DEACTIVATED) {
                            SmartListLogger.log(batch.subList(minSize, batch.size))
                        }
                        batch = batch.subList(0, minSize)
                        if (i == 0) {
                            batch0 = batch.toMutableList()
                            batches[0].list = batch0
                            csvLogWriter.log(batch0)
                        } else if (batchLoaded) {
                            batches[i].list = batch
                        }
                        Persistence.request.saveBatch(REQUEST_LOG_CATEGORY, i, batch)
                    } else {
                        Persistence.request.saveBatch(REQUEST_LOG_CATEGORY, i, batch)
                        break
                    }
                } else {
                    var batch = batches[i].list
                    val minSize = batches[i].minSize
                    val maxSize = minSize * 2

                    if (batch.size > maxSize) {
                        if (i < batches.size - 1) {
                            batches[i + 1].list = batch.subList(minSize, batch.size) + getBatch(i + 1)
                        }
                        batch = batch.subList(0, minSize)
                        if (i == 0) {
                            batch0 = batch.toMutableList()
                            batches[0].list = batch0
                        } else {
                            batches[i].list = batch
                        }
                    } else {
                        break
                    }

                }
            }
            var newSize = 0
            batches.forEach { newSize += it.list.size }
            totalSize = newSize
        }

        fun getRecentHistory(): List<ExtendedRequest>{
            return batch0
        }

        fun get(index: Int): ExtendedRequest {
            return batch0[index]
        }

        fun isEmpty(): Boolean {
            return batch0.isEmpty()
        }

        fun add(element: ExtendedRequest) {
            if(element.domain != lastDomain) {
                batch0.add(0, element)
                lastDomain = element.domain
                if (element.blocked) {
                    dropCount++
                    set(LogConfig::class.java, get(LogConfig::class.java).copy(dropCount = dropCount))
                    lastBlockedDomain = element.domain
                }
                rollIfNeeded()
                emit(TunnelEvents.REQUEST_UPDATE, RequestUpdate(null, element, -1))
            }
            return
        }

        fun resetDropCount(){
            dropCount = 0
            dropStart = System.currentTimeMillis()
            set(LogConfig::class.java, get(LogConfig::class.java).copy(dropCount = 0, dropStart = dropStart))
        }

        fun findIndex(lambda: (request: ExtendedRequest) -> Boolean): Int {
            val iterator = batch0.iterator().withIndex()
            while (iterator.hasNext()) {
                val next = iterator.next()
                if (lambda(next.value)) {
                    return next.index
                }
            }
            return -1
        }

        fun update(lambda: (request: ExtendedRequest) -> Boolean, state: RequestState): Boolean {
            val index = batch0.indexOfFirst(lambda)
            val current = batch0[index]
            if ((state == RequestState.BLOCKED_ANSWER || state == RequestState.BLOCKED_CNAME) && current.state == RequestState.ALLOWED_APP_UNKNOWN){
                val newState = current.copy(state = state)
                batch0[index] = newState
                emit(TunnelEvents.REQUEST_UPDATE, RequestUpdate(current, newState, index))
                return true
            }
            return false
        }

        fun update(lambda: (request: ExtendedRequest) -> Boolean, ip: InetAddress): Boolean {
            val index = batch0.indexOfFirst(lambda)
            val current = batch0[index]
            if(current.ip == null && !current.blocked) {
                val newState = current.copy(ip = ip)
                batch0[index] = newState
                emit(TunnelEvents.REQUEST_UPDATE, RequestUpdate(current, newState, index))
                return true
            }
            return false
        }

        fun update(lambda: (request: ExtendedRequest) -> Boolean, appId: String): Boolean {
            val index = batch0.indexOfFirst(lambda)
            val current = batch0[index]
            if(current.appId == null && !current.blocked) {
                val newState = current.copy(appId = appId, state = RequestState.ALLOWED_APP_KNOWN)
                batch0[index] = newState
                emit(TunnelEvents.REQUEST_UPDATE, RequestUpdate(current, newState, index))
                return true
            }
            return false
        }

        fun deleteAll() {
            flushHistory()
            batch0 = emptyList<ExtendedRequest>().toMutableList()
            batches[0].list = batch0
            totalSize = 0
            Persistence.request.clear(REQUEST_LOG_CATEGORY, batches.size)

        }

        fun flushHistory(){
            for (i in 1 until batches.size ){
                batches[i].loaded = false
                batches[i].list = emptyList()
            }
        }

    }

    fun expandHistory(): Boolean{
        for (i in batches.indices){
            if (!batches[i].loaded){
                batches[i].list = Persistence.request.load(REQUEST_LOG_CATEGORY, i).getOr {
                    return false
                }
                batches[i].loaded = batches[i].list.isNotEmpty()
                return true
            }
        }
            return false
    }


    fun contains(element: ExtendedRequest): Boolean {
        for (batch in batches) {
            if (batch.list.contains(element)) {
                return true
            }
        }
        return false
    }

    fun get(i: Int): ExtendedRequest {
        var index = i
        for (batch in batches) {
            if (index < batch.list.size) {
                return batch.list[index]
            }else{
                index -= batch.list.size
            }
        }
        throw IndexOutOfBoundsException()
    }

    fun indexOf(element: ExtendedRequest): Int {
        var sumIndex = 0
        for (batch in batches) {
            val index = batch.list.indexOf(element)
            if (index != -1) {
                return sumIndex + index
            }else{
                sumIndex += batch.list.size
            }
        }
        return -1

    }

    fun isEmpty(): Boolean {
        return batch0.isEmpty()
    }

    fun subList(fromIndex: Int, toIndex: Int): MutableList<ExtendedRequest> {
        throw NotImplementedError("")
    }

    override fun close() {
        flushHistory()
    }

    fun add(element: ExtendedRequest) {
        RequestLog.add(element)
        return
    }

    fun forEach(lambda: (request: ExtendedRequest) -> Unit) {
        for (batch in batches) {
            batch.list.forEach(lambda)
        }
    }

    fun <T> map(lambda: (request: ExtendedRequest) -> T): List<T> {
        val result = emptyList<T>() as MutableList
        for (batch in batches) {
            result.addAll(batch.list.map(lambda))
        }
        return result
    }
}

fun setLogPersistenceSource() {
    Register.sourceFor(LogConfig::class.java, default = LogConfig(),
            source = PaperSource("LogConfig"))
}
