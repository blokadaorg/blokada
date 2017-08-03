package org.blokada.framework.android

import android.app.Activity
import java.lang.ref.WeakReference

/**
 * AActivityContext wraps activity context in a weak reference in order to deliver it to interested
 * parties while not leaking it.
 */
class AActivityContext<T: Activity> {
    private var activity: WeakReference<T>? = null

    @Synchronized fun getActivity(): T? {
        return activity?.get()
    }

    @Synchronized fun set(a: T) {
        activity = WeakReference(a)
    }

    @Synchronized fun unset() {
        activity = null
    }
}