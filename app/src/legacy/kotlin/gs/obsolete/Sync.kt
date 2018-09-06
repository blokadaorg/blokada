package gs.obsolete

import gs.environment.Journal

class Sync<T>(private var value: T) {
    @Synchronized fun get(): T {
        return value
    }

    @Synchronized fun set(newValue: T) {
        value = newValue;
    }
}

fun hasCompleted(j: Journal?, f: () -> Unit): Pair<Boolean, Exception?> {
    return try { f(); true to null } catch (e: Exception) { j?.log(e); false to e }
}

