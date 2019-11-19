package core

import kotlinx.coroutines.experimental.CoroutineExceptionHandler

fun logCoroutineExceptions() = CoroutineExceptionHandler { _, throwable ->
    e("failed coroutine", throwable)
}
