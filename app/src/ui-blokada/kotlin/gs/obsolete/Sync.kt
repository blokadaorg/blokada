package gs.obsolete

import core.w

class Sync<T>(private var value: T) {
    @Synchronized fun get(): T {
        return value
    }

    @Synchronized fun set(newValue: T) {
        value = newValue;
    }
}

fun hasCompleted(f: () -> Unit): Pair<Boolean, Exception?> {
    return try { f(); true to null } catch (e: Exception) { w(e); false to e }
}

