package gs.environment

import com.github.salomonbrys.kodein.LazyKodein
import nl.komponents.kovenant.buildDispatcher

typealias Environment = LazyKodein

interface Time {
    fun now(): Long
}

class SystemTime : gs.environment.Time {
    override fun now(): Long {
        return System.currentTimeMillis()
    }
}

typealias Worker = nl.komponents.kovenant.Context

fun newSingleThreadedWorker(j: gs.environment.Journal, prefix: String): gs.environment.Worker {
    return nl.komponents.kovenant.Kovenant.createContext {
        callbackContext.dispatcher = buildDispatcher {
            name = "$prefix-callback"
            concurrentTasks = 1
            errorHandler = { j.log(it) }
            exceptionHandler = { j.log(it) }
        }
        workerContext.dispatcher = buildDispatcher {
            name = "$prefix-worker"
            concurrentTasks = 1
            errorHandler = { j.log(it) }
            exceptionHandler = { j.log(it) }
        }
    }
}

fun newConcurrentWorker(j: gs.environment.Journal?, prefix: String, tasks: Int): gs.environment.Worker {
    return nl.komponents.kovenant.Kovenant.createContext {
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

