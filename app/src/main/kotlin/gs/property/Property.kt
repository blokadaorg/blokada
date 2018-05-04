package gs.property

import gs.environment.Worker
import nl.komponents.kovenant.task
import nl.komponents.kovenant.ui.promiseOnUi

/**
 * IProperty represents a mutable state, changes of which may be monitored using listeners.
 *
 * This is a core concept which allows to read, write, and act on state changes in a thread-safe
 * way. It's meant to be extremely simple yet flexible enough to replace the basic use cases for
 * much more complex rx observables.
 */
interface IProperty<T> {

    /**
     * Register a new listener to be executed once the value of this property is reassigned.
     * Note that this also includes assigning value equal to the current one. Additionally, a call
     * to the listener is guaranteed once soon after setting it up, if the property already has a
     * value assigned (ie. is initialised). This may or may not be a sync call depending on the
     * Kovenant context of the property.
     *
     * @return An identifier of the listener that can be used to cancel it.
     */
    fun doWhenSet(): IWhen
    fun doOnUiWhenSet(): IWhen

    /**
     * Similar to dowWhenSet(), except that the listener will be called on change of the value, ie.
     * the current value of the property is ignored. Also, if value is set to equal value, the call
     * will NOT happen. If withInit is true, initial setting of this value (ie from null to non-null)
     * also will trigger this callback.
     */
    fun doWhenChanged(withInit: Boolean = false): IWhen
    fun doOnUiWhenChanged(withInit: Boolean = false): IWhen

    /**
     * Register a new listener to be executed once the value of this property is reassigned, and
     * when provided condition is true. Condition is evaluated every time the property is reassigned.
     * This includes the initialisation. Additionally, the condition is evaluated soon after setting
     * up this listener, in case the property is already initialised (has value).
     *
     * @return An identifier of the listener that can be used to cancel it.
     */
    fun doWhen(condition: () -> Boolean): IWhen

    /**
     * Cancel registered listener. Do nothing if doesn't exist.
     */
    fun cancel(existingWhen: IWhen?)

    /**
     * Assign new value to this property. Is used with syntax `property %= value` (unfortunately "="
     * operator cannot be overloaded in Kotlin).
     */
    operator fun remAssign(value: T)

    /**
     * Refresh the property. This executes the refresh logic (if needed, or forced), reassigns the
     * value and fires all relevant listeners. If blocking is true, this call will block until finished.
     */
    fun refresh(force: Boolean = false, blocking: Boolean = false)

    /**
     * Get the current value of this property. Is used with `property()` call with no arguments.
     * This never causes a refresh, but may init if null.
     */
    operator fun invoke(): T

    /**
     * Get the current value of this property, asynchronously. If the refresh logic needs to be
     * executed, it is, asynchronously, and the provided listener is called afterwards. Is used with
     * `property { "value is now $it" }` syntax.
     */
    operator fun invoke(force: Boolean = false, after: (value: T) -> Unit)

    /**
     * Compare current value of this property with provided value(s). If at least one value is equal
     * to the current value of the property, return true. Is used with `if (property("A", "B"))`.
     * This never causes a refresh, but may init if null.
     */
    operator fun invoke(vararg others: T): Boolean

}

/**
 * IWhen is enclosing an action and a condition that has to be true in order to execute it.
 */
interface IWhen {

    /**
     * Set the action to be performed if the condition is true.
     */
    fun then(action: () -> Unit): IWhen

    /**
     * Evaluate the condition. Is used with `when()` syntax.
     */
    operator fun invoke(): Boolean

}

/**
 * Create a new property.
 *
 * @param kctx Context to execute callbacks, conditions and actions on. Note that actions may be
 *      executed on another context, if provided.
 * @param init Creates the initial value of this property. Called on first access.
 * @param refresh Updates the value of this property. Called on every read or refreshNow(), but
 *      only if shouldRefresh() returns true.
 * @param shouldRefresh Decides whether the value should be refreshed with refresh() call or not.
 *      Called on every read.
 */
fun <T> newProperty(
        kctx: Worker,
        zeroValue: () -> T,
        init: () -> T = zeroValue,
        refresh: (value: T) -> T = { init() },
        shouldRefresh: (value: T) -> Boolean = { true }
): IProperty<T> {
    return BaseProperty(kctx, zeroValue, init, refresh, shouldRefresh)
}

/**
 * Create a new property that is synced with persistence. The initial value is read from the
 * persistence, and every write also writes to the persistence.
 */
fun <T> newPersistedProperty(
        kctx: Worker,
        persistence: Persistence<T>,
        zeroValue: () -> T,
        refresh: ((value: T) -> T)? = null,
        shouldRefresh: (value: T) -> Boolean = { true }
 ) : IProperty<T> {
    return PersistedProperty(kctx, persistence, zeroValue, refresh, shouldRefresh)
}

private interface IWhenExecute : IWhen {
    fun execute()
}

/**
 * When is the default implementation of IWhen. It executes the action on provided context. Also
 * it catches any exceptions and reports them using journal.
 */
private class When(
        private val kctx: Worker?,
        private val condition: () -> Boolean,
        private val immediate: Boolean = true,
        private var action: () -> Unit = {}
): IWhenExecute {

    override fun then(action: () -> Unit): IWhen {
        this.action = action
        if (immediate && condition()) execute()
        return this
    }

    override operator fun invoke(): Boolean {
        return condition()
    }

    override fun execute() {
        if (kctx == null) {
            promiseOnUi(alwaysSchedule = true) { action() } fail { throw it }
        } else {
            task(kctx) {
                if (condition()) {
                    action()
                }
            } fail { throw it }
        }
    }

}

/**
 * Fires only when the value of the property is set to something not equal to the current value.
 * Also, the value is changed from null to something else, we consider it an initial read, and
 * hence not a "change".
 */
private class WhenChanged<T>(
        private var property: BaseProperty<T>,
        private val withInit: Boolean,
        private val w: IWhenExecute
): IWhenExecute {

    private var lastValue: T? = property.value

    override fun invoke(): Boolean {
        val v = property()
        val changed = (lastValue != null || withInit) && v != lastValue
        lastValue = v
        return changed
    }

    override fun then(action: () -> Unit): IWhen {
        w.then(action)
        return this
    }

    override fun execute() {
        return w.execute()
    }

}

/**
 * BaseProperty is the default implementation of IProperty. For asynchronous calls, it catches all
 * exceptions and reports them using journal. For the synchronous getter, it does not.
 */
private open class BaseProperty<T>(
        private val kctx: Worker,
        private val zeroValue: () -> T,
        private val init: () -> T = zeroValue,
        private val refresh: (value: T) -> T = { init() },
        private val shouldRefresh: (value: T) -> Boolean = { true }
): IProperty<T> {

    private val listeners: MutableList<IWhenExecute> = mutableListOf()

    init {
        refresh()
    }

    internal var value: T? = null
        @Synchronized get
        @Synchronized set(value) {
            field = value
            task(kctx) {
                listeners.forEach { aWhen ->
                    if (aWhen()) aWhen.execute()
                }
            }
        }

    override fun doWhen(condition: () -> Boolean): IWhen {
        val newWhen = When(kctx, condition, immediate = value != null)
        task(kctx) {
            listeners.add(newWhen)
        }
        return newWhen
    }

    override fun doWhenSet(): IWhen {
        return doWhen { true }
    }

    override fun doOnUiWhenSet(): IWhen {
        val newWhen = When(null, { true }, immediate = value != null)
        task(kctx) {
            listeners.add(newWhen)
        }
        return newWhen
    }

    override fun doWhenChanged(withInit: Boolean): IWhen {
        val newWhen = WhenChanged(this, withInit, When(kctx, { true }, immediate = false))
        task(kctx) {
            listeners.add(newWhen)
        }
        return newWhen
    }

    override fun doOnUiWhenChanged(withInit: Boolean): IWhen {
        val newWhen = WhenChanged(this, withInit, When(null, { true }, immediate = false))
        task(kctx) {
            listeners.add(newWhen)
        }
        return newWhen
    }

    override fun cancel(existingWhen: IWhen?) {
        task(kctx) {
            listeners.remove(existingWhen)
        }
    }

    override operator fun remAssign(value: T) {
        this.value = value
    }

    override fun refresh(force: Boolean, blocking: Boolean) {
        val value = this.value
        if (blocking) {
            if (value == null) {
                try {
                    this.value = init()
                } catch (e: Exception) {
                    kctx.workerContext.errorHandler(e)
                }
                return
            }

            if (force or shouldRefresh(value)) {
                try {
                    this.value = refresh(value)
                } catch (e: Exception) {
                    kctx.workerContext.errorHandler(e)
                }
            }
        } else {
            if (value == null) {
                task(kctx) {
                    if (this.value == null) {
                        val v = init()
                        this.value = v
                    }
                } fail { throw it }
            } else if (force or shouldRefresh(value)) {
                task(kctx) {
                    if (force or shouldRefresh(value)) {
                        val v = refresh(value)
                        this.value = v
                    }
                }
            }
        }
    }

    override operator fun invoke(): T {
        return value ?: zeroValue()
    }

    override fun invoke(force: Boolean, after: (value: T) -> Unit) {
        val value = this.value
        if (value == null) {
            task(kctx) {
                if (this.value == null) {
                    val v = init()
                    this.value = v
                    v
                } else this.value!!
            } success {
                after(it)
            } fail { throw it }
        } else if (force) {
            task(kctx) {
                val v = refresh(value)
                this.value = v
                v
            } success {
                after(it)
            } fail { throw it }
        } else after(value)
    }

    override operator fun invoke(vararg others: T): Boolean {
        return others.any { it == (value ?: zeroValue) }
    }

    override fun toString(): String {
        return value.toString()
    }

}

private class PersistedProperty<T>(
        private val kctx: Worker,
        private val persistence: Persistence<T>,
        private val zeroValue: () -> T,
        private val refresh: ((value: T) -> T)? = null,
        private val shouldRefresh: (value: T) -> Boolean = { false }
): BaseProperty<T>(
        kctx = kctx,
        zeroValue = { persistence.read(zeroValue()) },
        refresh = refresh ?: { persistence.read(it) },
        shouldRefresh = shouldRefresh
) {

    init {
        doWhenSet().then {
            persistence.write(value!!)
        }
        refresh()
    }

}
