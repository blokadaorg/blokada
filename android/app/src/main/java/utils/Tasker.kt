/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package utils

import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import model.BlokadaException
import model.TimeoutException
import repository.Repos

val DEFAULT_USER_INTERACTION_DEBOUNCE = 300L

internal data class TaskResult<T, Y> (
    val ordinal: Long,
    val argument: T,
    val result: Y?,
    val error: BlokadaException?
)

/**
 * This class is an almost-direct port of the same class from our iOS code. This is far from ideal
 * and I'm sure it can be done better with Kotlin coroutines.
 */
open class Tasker<T, Y>(
    internal val owner: String,
    internal val debounce: Long = DEFAULT_USER_INTERACTION_DEBOUNCE,
    internal val errorIsMajor: Boolean = false,
    internal val timeoutMs: Long = 10000
) {

    internal val processingRepo by lazy { Repos.processing }

    internal val writeRequests = MutableSharedFlow<T?>()
    private val requests = writeRequests.filterNotNull()

    private val writeResponses = MutableSharedFlow<TaskResult<T, Y>?>()
    internal val responses = writeResponses.filterNotNull()

    internal var onError: suspend (BlokadaException) -> Any = {}

    internal var ordinal = 0L
        @Synchronized get
        @Synchronized set

    // This will block coroutine for lifetime of this task handler.
    fun setTask(task: suspend (T) -> Y) {
        GlobalScope.launch {
            var publisher = requests
            if (debounce > 0) {
                publisher = requests.debounce(debounce)
            }
            publisher.collect {
                try {
                    ordinal += 1
                    Logger.v("Tasker", "$owner: $it, ordinal: $ordinal")
                    val result = task(it)
                    writeResponses.emit(TaskResult(ordinal, it, result, null))
                    processingRepo.notify(owner, ongoing = false)
                } catch (ex: BlokadaException) {
                    writeResponses.emit(TaskResult(ordinal, it, null, ex))
                    processingRepo.notify(owner, ex, major = errorIsMajor)
                } catch (err: Throwable) {
                    val ex = BlokadaException("task error: $owner", err)
                    writeResponses.emit(TaskResult(ordinal, it, null, ex))
                    processingRepo.notify(owner, ex, major = errorIsMajor)
                }
            }
        }
    }

    fun setOnError(onError: suspend (BlokadaException) -> Any) {
        this.onError = onError
    }

    suspend fun get(argument: T): Y {
        processingRepo.notify(owner, ongoing = true)

        val lastTask = ordinal

        val resp = GlobalScope.async {
            try {
                withTimeout(timeoutMs) {
                    // Just return first future result if debounce is set, as it's used for cases when we
                    // only care about the latest invocation in a short time.
                    responses.first { ordinal > lastTask && (debounce != 0L || argument == it.argument) }
                }
            } catch (ex: Exception) {
                val ex = TimeoutException(owner)
                processingRepo.notify(owner, ex, major = errorIsMajor)
                TaskResult(lastTask + 1, argument, null, ex)
            }
        }
        writeRequests.emit(argument)
        val r = resp.await()

        val error = r.error
        if (error != null) {
            onError(error)
            throw error
        }

        return r.result as Y
    }

    suspend fun send(argument: T) {
        try {
            get(argument)
        } catch (ex: BlokadaException) { }
    }

}

class SimpleTasker<Y>(
    owner: String,
    debounce: Long = DEFAULT_USER_INTERACTION_DEBOUNCE,
    errorIsMajor: Boolean = false,
    timeoutMs: Long = 10000
) : Tasker<Ignored, Y>(owner, debounce, errorIsMajor, timeoutMs) {

    suspend fun get(): Y {
        processingRepo.notify(owner, ongoing = true)

        val lastTask = ordinal

        val resp = GlobalScope.async {
            try {
                withTimeout(timeoutMs) {
                    responses.first { ordinal > lastTask }
                }
            } catch (ex: Exception) {
                val ex = TimeoutException(owner)
                processingRepo.notify(owner, ex, major = errorIsMajor)
                TaskResult(lastTask + 1, true, null, ex)
            }
        }
        writeRequests.emit(true)
        val r = resp.await()

        val error = r.error
        if (error != null) {
            onError(error)
            throw error
        }

        return r.result as Y
    }

    suspend fun send() {
        try {
            get()
        } catch (ex: BlokadaException) { }
    }

}