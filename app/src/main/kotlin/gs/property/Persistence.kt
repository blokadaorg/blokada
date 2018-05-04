package gs.property

import android.content.SharedPreferences
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import gs.environment.Environment

interface Persistence<T> {
    fun read(current: T): T
    fun write(source: T)
}

interface Serialiser {
    interface Editor {
        fun putString(key: String, value: String): gs.property.Serialiser.Editor
        fun putStringSet(key: String, values: Set<String>): gs.property.Serialiser.Editor
        fun putInt(key: String, value: Int): gs.property.Serialiser.Editor
        fun putLong(key: String, value: Long): gs.property.Serialiser.Editor
        fun putFloat(key: String, value: Float): gs.property.Serialiser.Editor
        fun putBoolean(key: String, value: Boolean): gs.property.Serialiser.Editor
        fun remove(key: String): gs.property.Serialiser.Editor
        fun clear(): gs.property.Serialiser.Editor
        fun apply()
    }

    val all: Map<String, *>
    fun getString(key: String, defValue: String): String
    fun getStringSet(key: String, defValues: Set<String>): Set<String>
    fun getInt(key: String, defValue: Int): Int
    fun getLong(key: String, defValue: Long): Long
    fun getFloat(key: String, defValue: Float): Float
    fun getBoolean(key: String, defValue: Boolean): Boolean
    operator fun contains(key: String): Boolean
    fun edit(): gs.property.Serialiser.Editor
}

abstract class PersistenceWithSerialiser<T>(val xx: Environment): gs.property.Persistence<T> {
    protected fun serialiser(key: String): gs.property.Serialiser {
        return xx().with(key).instance<Serialiser>()
    }
}

interface HasKey {
    fun key(): String
}

class BasicPersistence<T>(
        xx: Environment,
        val key: String
) : PersistenceWithSerialiser<T>(xx) {

    val p by lazy { serialiser("basic") }

    override fun read(current: T): T {
        return when (current) {
            is Boolean -> p.getBoolean(key, current)
            is Int -> p.getInt(key, current)
            is Long -> p.getLong(key, current)
            is String -> p.getString(key, current)
            is Set<*> -> p.getStringSet(key, current as Set<String>)
            else -> throw Exception("unsupported type for ${key}")
        } as T
    }

    override fun write(source: T) {
        val e = p.edit()
        when(source) {
            is Boolean -> e.putBoolean(key, source)
            is Int -> e.putInt(key, source)
            is Long -> e.putLong(key, source)
            is String -> e.putString(key, source)
            is Set<*> -> e.putStringSet(key, source as Set<String>)
            else -> throw Exception("unsupported type for ${key}")
        }
        e.apply()
    }

}

class SharedPreferencesWrapper(val p: SharedPreferences): Serialiser {

    override val all: Map<String, *> by p.all
    override fun getString(key: String, defValue: String): String {
        return p.getString(key, defValue)
    }

    override fun getStringSet(key: String, defValues: Set<String>): Set<String> {
        return p.getStringSet(key, defValues)
    }

    override fun getInt(key: String, defValue: Int): Int {
        return p.getInt(key, defValue)
    }

    override fun getLong(key: String, defValue: Long): Long {
        return p.getLong(key, defValue)
    }

    override fun getFloat(key: String, defValue: Float): Float {
        return p.getFloat(key, defValue)
    }

    override fun getBoolean(key: String, defValue: Boolean): Boolean {
        return p.getBoolean(key, defValue)
    }

    override fun contains(key: String): Boolean {
        return p.contains(key)
    }

    override fun edit(): Serialiser.Editor {
        return EditorWrapper(p.edit())
    }

    class EditorWrapper(val e: SharedPreferences.Editor): Serialiser.Editor {

        override fun putString(key: String, value: String): Serialiser.Editor {
            e.putString(key, value)
            return this
        }

        override fun putStringSet(key: String, values: Set<String>): Serialiser.Editor {
            e.putStringSet(key, values)
            return this
        }

        override fun putInt(key: String, value: Int): Serialiser.Editor {
            e.putInt(key, value)
            return this
        }

        override fun putLong(key: String, value: Long): Serialiser.Editor {
            e.putLong(key, value)
            return this
        }

        override fun putFloat(key: String, value: Float): Serialiser.Editor {
            e.putFloat(key, value)
            return this
        }

        override fun putBoolean(key: String, value: Boolean): Serialiser.Editor {
            e.putBoolean(key, value)
            return this
        }

        override fun remove(key: String): Serialiser.Editor {
            e.remove(key)
            return this
        }

        override fun clear(): Serialiser.Editor {
            e.clear()
            return this
        }

        override fun apply() {
            e.apply()
        }

    }
}



