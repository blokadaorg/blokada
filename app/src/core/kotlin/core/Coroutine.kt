package core

import kotlinx.coroutines.experimental.newFixedThreadPoolContext

val COMMON = newFixedThreadPoolContext(Runtime.getRuntime().availableProcessors(), "common")
