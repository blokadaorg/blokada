package core2

//class TunnelKeeper(
//        private val commands: Commands
//) {
//
//    companion object {
//        private val DEFAULT_RETRIES = 3
//
//        val ON = Command("ON")
//        val OFF = Command("OFF")
//        private val RETRY_LATER = Command("RETRY_LATER")
//        private val CHECK_STABILITY = Command("CHECK_STABILITY")
//    }
//
//    init {
//        commands.registerExecutor(ON, ::run)
//        commands.registerExecutor(OFF, ::stop)
//        commands.registerExecutor(RETRY_LATER, ::retryAfterWait, workerId = this)
//        commands.registerExecutor(CHECK_STABILITY, ::checkStabilityAfterWait, workerId = this)
//    }
//
//    private var tunnelPipe: Pipe? = null
//    private var waitPipe: Pipe? = null
//    private var retries = DEFAULT_RETRIES
//
//    private fun run(pipe: Pipe) = runBlocking {
//        tunnelPipe = commands.run(TunnelOperator.WATCH)
//        for (msg in tunnelPipe!!.out) {
//            when (msg) {
//                TunnelState.INACTIVE -> {
//                    waitPipe?.into?.close()
//                    if (--retries > 0) {
//                        pipe.out("keeper: will retry now")
//                        commands.run(TunnelOperator.START)
//                    }
//                    else {
//                        pipe.out("keeper: will wait")
//                        waitPipe = commands.run(RETRY_LATER)
//                    }
//                }
//                TunnelState.ACTIVE -> {
//                    waitPipe = commands.run(CHECK_STABILITY)
//                }
//                is TunnelState -> {
//                    if (waitPipe != null) {
//                        pipe.out("keeper: tunnel state changed, cancelling wait")
//                        waitPipe?.close()
//                        waitPipe = null
//                    }
//                }
//            }
//        }
//    }
//
//    private fun stop(pipe: Pipe) = runBlocking {
//        tunnelPipe?.close()
//        waitPipe?.close()
//        waitPipe = null
//        retries = DEFAULT_RETRIES
//    }
//
//    private fun retryAfterWait(pipe: Pipe) = runBlocking {
//        val retry = async {
//            delay(15 * 1000)
//            pipe.out("keeper: will retry now after wait")
//            retries = DEFAULT_RETRIES - 1
//            commands.run(TunnelOperator.START)
//        }
//
//        try {
//            select<Unit> {
//                retry.onAwait { throw Exception("keeper: waiting done") }
//                waitPipe!!.into.onReceiveOrNull {
//                    throw Exception("keeper: cancelling long wait retry")
//                }
//            }
//        } catch (e: Exception) {
//            pipe.out(e)
//            retry.cancel()
//        }
//    }
//
//    private fun checkStabilityAfterWait(pipe: Pipe) = runBlocking {
//        val stable = async {
//            delay(15 * 1000)
//            pipe.out("keeper: tunnel stable")
//            retries = DEFAULT_RETRIES
//        }
//
//        try {
//            select<Unit> {
//                stable.onAwait { throw Exception("keeper: stability waiting done") }
//                waitPipe!!.into.onReceiveOrNull {
//                    throw Exception("keeper: cancelling stability check")
//                }
//            }
//        } catch (e: Exception) {
//            pipe.out(e)
//            stable.cancel()
//        }
//    }
//}
//
//
//class TunnelOperator(
//        val getPermissions: (Pipe) -> Boolean,
//        val askPermissions: Executor,
//        val startTunnel: Executor,
//        val stopTunnel: Executor,
//        commands: Commands
//) {
//
//    companion object {
//        val START = Command("START")
//        val STOP = Command("STOP")
//        val WATCH = Command("WATCH")
//        val PERMISSION_GET = Command("PERMISSION_GET")
//        val PERMISSION_ASK = Command("PERMISSION_ASK")
//    }
//
//    init {
//        commands.registerExecutor(START, ::start, workerId = this)
//        commands.registerExecutor(STOP, ::stop, workerId = this)
//        commands.registerExecutor(WATCH, ::watch)
//        commands.registerExecutor(PERMISSION_GET, getPermissions)
//        commands.registerExecutor(PERMISSION_ASK, askPermissions)
//    }
//
//    var stateWatcher: Pipe? = null
//    var state = TunnelState.INACTIVE
//        set(value) {
//            launch { stateWatcher?.out(value) }
//        }
//
//    private fun start(pipe: Pipe) = runBlocking {
//        if (state != TunnelState.INACTIVE) throw Exception("tunnel: already started")
//
//        state = TunnelState.ACTIVATING
//        if (!getPermissions(pipe)) {
//            pipe.out("tunnel: asking for permissions")
//            askPermissions(pipe)
//        }
//
//        if (!getPermissions(pipe)) {
//            state = TunnelState.INACTIVE
//            throw Exception("tunnel: could not get permissions")
//        } else try {
//            startTunnel(pipe)
//            state = TunnelState.ACTIVE
//        } catch (e: Exception) {
//            state = TunnelState.DEACTIVATING
//            stopTunnel(pipe)
//            state = TunnelState.INACTIVE
//            throw Exception("tunnel: could not start tunnel", e)
//        }
//    }
//
//    private fun stop(pipe: Pipe) = runBlocking {
//        if (state == TunnelState.INACTIVE) throw Exception("tunnel: already stopped")
//        else {
//            state = TunnelState.DEACTIVATING
//            stopTunnel(pipe)
//            state = TunnelState.INACTIVE
//        }
//    }
//
//    private fun watch(pipe: Pipe) = runBlocking {
//        stateWatcher = pipe
//        select<Unit> {
//            pipe.into.onReceiveOrNull {
//                stateWatcher = null
//            }
//        }
//    }
//}
//
//class Commands {
//
//    private val commands = Channel<Pair<Any, Pipe>>()
//
//    private val executors = mutableMapOf<Any, Channel<Pipe>>()
//    private val executorRegister = Channel<Triple<Any, Executor, Any>>()
//    private val workers = mutableMapOf<Any, Channel<Pipe>>()
//
//    private val monitorChannel = Channel<Any>()
//    private val monitors = mutableListOf<Pipe>()
//
//    init {
//        startExecutorRegister()
//        startMonitorChannel()
//        startDispatcher()
//    }
//
//    fun registerExecutor(cmd: Any, executor: Executor, workerId: Any = cmd) {
//        launch {
//            executorRegister.send(Triple(cmd, executor, workerId))
//        }
//    }
//
//    fun registerMonitor() = {
//        val pipe = newPipe()
//        launch { monitors.add(pipe) }
//        pipe
//    }()
//
//    fun run(msg: Any, output: Boolean = false) = {
//        val pipe = newPipe()
//        runBlocking { commands.send(msg to pipe) }
//        if (!output) {
//            launch {
//                for (drain in pipe.out) {}
//            }
//        }
//        pipe
//    }()
//
//    fun <T> get(msg: Any): T {
//        val pipe = run(msg, output = true)
//        return pipe.get()
//    }
//
//    private fun startExecutorRegister() {
//        launch {
//            for ((cmd, executor, workerId) in executorRegister) {
//                if (executors.containsKey(cmd)) {
//                    monitorChannel.send(Exception("executor already registered for: $cmd"))
//                } else {
//                    val channel = workers.getOrPut(workerId) {
//                        val channel = Channel<Pipe>()
//                        startWorker(executor, channel)
//                        channel
//                    }
//                    executors[cmd] = channel
//                }
//            }
//        }
//    }
//
//    private fun startWorker(executor: Executor, channel: Channel<Pipe>) {
//        launch {
//            monitorChannel.send("worker started: $channel")
//            for (pipe in channel) {
//                val localPipe = newPipe()
//                launch {
//                    for (msg in localPipe.out) {
//                        pipe.out(msg)
//                        monitorChannel.send(msg)
//                    }
//                    pipe.out.close()
//                    pipe.into.close()
//                }
//
//                launch {
//                    for (msg in pipe.into) {
//                        localPipe.into.send(msg)
//                        monitorChannel.send("input: $msg")
//                    }
//                   localPipe.into.close()
//                }
//
//                try {
//                    executor(localPipe)
//                } catch (e: Exception) {
//                    localPipe.out(Exception("fail in worker", e))
//                } finally {
//                    localPipe.out.close()
//                }
//            }
//        }
//    }
//
//    private fun startDispatcher() {
//        launch {
//            for ((cmd, pipe) in commands) {
//                val executor = executors[cmd]
//                if (executor == null) {
//                    monitorChannel.send(Exception("no executor for $cmd"))
//                } else {
//                    executor.send(pipe)
//                }
//            }
//        }
//    }
//
//    private fun startMonitorChannel() {
//        launch {
//            for (msg in monitorChannel) {
//                for (monitor in monitors) {
//                    monitor.out(msg)
//                }
//            }
//        }
//    }
//
//}
//
//class Command (val name: String)
//
//internal fun newPipe(): Pipe {
//    return Pipe()
//}
//
//data class Pipe(
//        internal val into: Channel<Any> = Channel(),
//        internal val out: Channel<Any> = Channel()
//) {
//
//    fun put(msg: Any) = runBlocking {
//        into.send(msg)
//    }
//
//    fun <T> get(): T = runBlocking {
//        out.receive() as T
//    }
//
//    internal fun into() = runBlocking {
//        into.receive()
//    }
//
//    internal fun out(msg: Any) = runBlocking {
//        out.send(msg)
//    }
//
//    fun close() {
//        into.close()
//        out.close()
//    }
//
//}
//
//typealias Executor = (Pipe) -> Any
//

