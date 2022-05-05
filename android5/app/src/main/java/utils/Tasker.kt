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
import model.BlokadaException
import repository.Repos

val DEFAULT_USER_INTERACTION_DEBOUNCE = 300L

internal data class TaskResult<T, Y> (
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
    private val debounce: Long = DEFAULT_USER_INTERACTION_DEBOUNCE,
    private val errorIsMajor: Boolean = false
) {

    internal val processingRepo by lazy { Repos.processing }

    internal val writeRequests = MutableSharedFlow<T?>()
    private val requests = writeRequests.filterNotNull()

    private val writeResponses = MutableSharedFlow<TaskResult<T, Y>?>()
    internal val responses = writeResponses.filterNotNull()

    // This will block coroutine for lifetime of this task handler.
    suspend fun setTask(task: suspend (T) -> Y) {
        var publisher = requests
        if (debounce > 0) {
            publisher = requests.debounce(debounce)
        }
        publisher.collect {
            try {
                Logger.v("Tasker", "$owner: $it")
                val result = task(it)
                writeResponses.emit(TaskResult(it, result, null))
                processingRepo.notify(owner, ongoing = false)
            } catch (ex: BlokadaException) {
                writeResponses.emit(TaskResult(it, null, ex))
                processingRepo.notify(owner, ex, major = errorIsMajor)
            } catch (err: Throwable) {
                val ex = BlokadaException("task error: $owner", err)
                writeResponses.emit(TaskResult(it, null, ex))
                processingRepo.notify(owner, ex, major = errorIsMajor)
            }
        }
    }

    suspend fun send(argument: T): Y {
        processingRepo.notify(owner, ongoing = true)
        val resp = GlobalScope.async {
            // Just return first result if debounce is set, as it's used for cases when we
            // only care about the latest invocation in a short time.
            responses.first { debounce != 0L || argument == it.argument }
        }
        writeRequests.emit(argument)
        val r = resp.await()

        val error = r.error
        if (error != null) {
            throw error
        }

        return r.result as Y
    }

}

class SimpleTasker<Y>(
    owner: String,
    debounce: Long = DEFAULT_USER_INTERACTION_DEBOUNCE,
    errorIsMajor: Boolean = false
) : Tasker<Ignored, Y>(owner, debounce, errorIsMajor) {

    suspend fun send(): Y {
        processingRepo.notify(owner, ongoing = true)
        val resp = GlobalScope.async {
            responses.first()
        }
        writeRequests.emit(true)
        val r = resp.await()

        val error = r.error
        if (error != null) {
            throw error
        }

        return r.result as Y
    }

}