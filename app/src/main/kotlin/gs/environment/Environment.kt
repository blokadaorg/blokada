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

//fun newWorkerModule(): Kodein.Module {
//    return Kodein.Module {
//        // Kovenant context (one instance per prefix name)
//        bind<Worker>() with multiton { it: String ->
//            newSingleThreadedWorker(j = instance(), prefix = it)
//        }
//        bind<Worker>(3) with multiton { it: String ->
//            newConcurrentWorker(j = instance(), prefix = it, tasks = 3)
//        }
//        bind<Worker>(10) with multiton { it: String ->
//            newConcurrentWorker(j = instance(), prefix = it, tasks = 10)
//        }
//    }
//}

//fun newEnvironmentModule(ctx: android.content.Context): Kodein.Module {
//    return Kodein.Module {
//        // Various components
//        bind<Time>() with singleton { SystemTime() }
//        bind<AConnectivityReceiver>() with singleton { AConnectivityReceiver() }
//        bind<AScreenOnReceiver>() with singleton { AScreenOnReceiver() }
//        bind<ALocaleReceiver>() with singleton { ALocaleReceiver() }
//
//        onReady {
//            // Register various Android listeners to receive events
//            task {
//                // In a task because we are in DI and using DI can lead to stack overflow
//                AConnectivityReceiver.register(ctx)
//                AScreenOnReceiver.register(ctx)
//                ALocaleReceiver.register(ctx)
//                registerUncaughtExceptionHandler(ctx)
//            }
//        }
//    }
//}
