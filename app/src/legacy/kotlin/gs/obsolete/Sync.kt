package gs.obsolete

import core.Kontext

class Sync<T>(private var value: T) {
    @Synchronized fun get(): T {
        return value
    }

    @Synchronized fun set(newValue: T) {
        value = newValue;
    }
}

fun hasCompleted(ktx: Kontext, f: () -> Unit): Pair<Boolean, Exception?> {
    return try { f(); true to null } catch (e: Exception) { ktx.w(e); false to e }
}

