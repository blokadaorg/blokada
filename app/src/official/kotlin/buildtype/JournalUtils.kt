package buildtype

import android.app.Activity
import android.app.Application
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.database.Cursor
import android.database.sqlite.*
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.telephony.TelephonyManager
import android.util.Log
import org.blokada.BuildConfig
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.util.*

class WorkerThread(name: String) : HandlerThread(name) {

    internal var handler: Handler? = null
        private set

    fun post(r: Runnable) {
        waitForInitialization()
        handler!!.post(r)
    }

    fun postDelayed(r: Runnable, delayMillis: Long) {
        waitForInitialization()
        handler!!.postDelayed(r, delayMillis)
    }

    fun removeCallbacks(r: Runnable) {
        waitForInitialization()
        handler!!.removeCallbacks(r)
    }

    @Synchronized
    private fun waitForInitialization() {
        if (handler == null) {
            handler = Handler(looper)
        }
    }
}

object Utils {

    val TAG = "buildtype.Utils"
    private val logger = JournalLog.getLogger()


    fun cloneJSONObject(obj: JSONObject?): JSONObject? {
        if (obj == null) {
            return null
        }


        var nameArray: JSONArray? = null
        try {
            nameArray = obj.names()
        } catch (e: ArrayIndexOutOfBoundsException) {
            logger.e(TAG, e.toString())
        }

        val len = if (nameArray != null) nameArray.length() else 0

        val names = arrayOfNulls<String>(len)
        for (i in 0 until len) {
            names[i] = nameArray!!.optString(i)
        }

        try {
            return JSONObject(obj, names)
        } catch (e: JSONException) {
            logger.e(TAG, e.toString())
            return null
        }

    }

    internal fun compareJSONObjects(o1: JSONObject?, o2: JSONObject?): Boolean {
        try {

            if (o1 === o2) {
                return true
            }

            if (o1 != null && o2 == null || o1 == null && o2 != null) {
                return false
            }

            if (o1!!.length() != o2!!.length()) {
                return false
            }

            val keys = o1.keys()
            while (keys.hasNext()) {
                val key = keys.next() as String
                if (!o2.has(key)) {
                    return false
                }

                val value1 = o1.get(key)
                val value2 = o2.get(key)

                if (value1.javaClass != value2.javaClass) {
                    return false
                }

                if (value1.javaClass == JSONObject::class.java) {
                    if (!compareJSONObjects(value1 as JSONObject, value2 as JSONObject)) {
                        return false
                    }
                } else if (value1 != value2) {
                    return false
                }
            }

            return true
        } catch (e: JSONException) {
        }

        return false
    }

    fun isEmptyString(s: String?): Boolean {
        return s == null || s.length == 0
    }

    fun normalizeInstanceName(instance: String?): String {
        var instance = instance
        if (isEmptyString(instance)) {
            instance = Constants.DEFAULT_INSTANCE
        }
        return instance!!.toLowerCase()
    }
}


class CursorWindowAllocationException(description: String) : RuntimeException(description)

class JournalLog private constructor() {

    @Volatile
    private var enableLogging = true
    @Volatile
    private var logLevel = Log.INFO

    fun setEnableLogging(enableLogging: Boolean): JournalLog {
        this.enableLogging = enableLogging
        return loggerInternal
    }

    fun setLogLevel(logLevel: Int): JournalLog {
        this.logLevel = logLevel
        return loggerInternal
    }

    fun d(tag: String, msg: String): Int {
        return if (enableLogging && logLevel <= Log.DEBUG) Log.d(tag, msg) else 0
    }

    fun d(tag: String, msg: String, tr: Throwable): Int {
        return if (enableLogging && logLevel <= Log.DEBUG) Log.d(tag, msg, tr) else 0
    }

    fun e(tag: String, msg: String): Int {
        return if (enableLogging && logLevel <= Log.ERROR) Log.e(tag, msg) else 0
    }

    fun e(tag: String, msg: String, tr: Throwable): Int {
        return if (enableLogging && logLevel <= Log.ERROR) Log.e(tag, msg, tr) else 0
    }

    fun getStackTraceString(tr: Throwable): String {
        return Log.getStackTraceString(tr)
    }

    fun i(tag: String, msg: String): Int {
        return if (enableLogging && logLevel <= Log.INFO) Log.i(tag, msg) else 0
    }

    fun i(tag: String, msg: String, tr: Throwable): Int {
        return if (enableLogging && logLevel <= Log.INFO) Log.i(tag, msg, tr) else 0
    }

    fun isLoggable(tag: String, level: Int): Boolean {
        return Log.isLoggable(tag, level)
    }

    fun println(priority: Int, tag: String, msg: String): Int {
        return Log.println(priority, tag, msg)
    }

    fun v(tag: String, msg: String): Int {
        return if (enableLogging && logLevel <= Log.VERBOSE) Log.v(tag, msg) else 0
    }

    fun v(tag: String, msg: String, tr: Throwable): Int {
        return if (enableLogging && logLevel <= Log.VERBOSE) Log.v(tag, msg, tr) else 0
    }

    fun w(tag: String, msg: String): Int {
        return if (enableLogging && logLevel <= Log.WARN) Log.w(tag, msg) else 0
    }

    fun w(tag: String, tr: Throwable): Int {
        return if (enableLogging && logLevel <= Log.WARN) Log.w(tag, tr) else 0
    }

    fun w(tag: String, msg: String, tr: Throwable): Int {
        return if (enableLogging && logLevel <= Log.WARN) Log.w(tag, msg, tr) else 0
    }

    fun wtf(tag: String, msg: String): Int {
        return if (enableLogging && logLevel <= Log.ASSERT) Log.wtf(tag, msg) else 0
    }

    fun wtf(tag: String, tr: Throwable): Int {
        return if (enableLogging && logLevel <= Log.ASSERT) Log.wtf(tag, tr) else 0
    }

    fun wtf(tag: String, msg: String, tr: Throwable): Int {
        return if (enableLogging && logLevel <= Log.ASSERT) Log.wtf(tag, msg, tr) else 0
    }

    companion object {
        private var loggerInternal = JournalLog()

        fun getLogger(): JournalLog {
            return loggerInternal
        }
    }
}

internal class JournalCallbacks(val clientInstance: JournalClient?) : Application.ActivityLifecycleCallbacks {

    protected val currentTimeMillis: Long
        get() = System.currentTimeMillis()

    init {
        if (clientInstance == null) {
            logger.e(TAG, NULLMSG)
        } else {
            clientInstance.useForegroundTracking()
        }
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}

    override fun onActivityDestroyed(activity: Activity) {}

    override fun onActivityPaused(activity: Activity) {
        if (clientInstance == null) {
            logger.e(TAG, NULLMSG)
            return
        }

        clientInstance.onExitForeground(currentTimeMillis)
    }

    override fun onActivityResumed(activity: Activity) {
        if (clientInstance == null) {
            logger.e(TAG, NULLMSG)
            return
        }

        clientInstance.onEnterForeground(currentTimeMillis)
    }

    override fun onActivitySaveInstanceState(activity: Activity, outstate: Bundle) {}

    override fun onActivityStarted(activity: Activity) {}

    override fun onActivityStopped(activity: Activity) {}

    companion object {

        val TAG = "buildtype.JournalCallbacks"
        private val NULLMSG = "Need to initialize JournalCallbacks with JournalClient instance"
        private val logger = JournalLog.getLogger()
    }
}

class DeviceInfo(private val context: Context) {
    private var cachedInfo: CachedInfo? = null

    val versionName: String?
        get() = getCachedInfo().versionName

    val osName: String
        get() = getCachedInfo().osName

    val osVersion: String
        get() = getCachedInfo().osVersion

    val brand: String
        get() = getCachedInfo().brand

    val manufacturer: String
        get() = getCachedInfo().manufacturer

    val model: String
        get() = getCachedInfo().model

    val carrier: String?
        get() = getCachedInfo().carrier

    val country: String?
        get() = getCachedInfo().country

    val language: String
        get() = getCachedInfo().language

    inner class CachedInfo {
        val country: String?
        val versionName: String?
        val osName: String
        val osVersion: String
        val brand: String
        val manufacturer: String
        val model: String
        val carrier: String?
        val language: String

        private val countryFromNetwork: String?
            get() {
                try {
                    val manager = context
                            .getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                    if (manager.phoneType != TelephonyManager.PHONE_TYPE_CDMA) {
                        val country = manager.networkCountryIso
                        if (country != null) {
                            return country.toUpperCase(Locale.US)
                        }
                    }
                } catch (e: Exception) {
                }

                return null
            }

        private val countryFromLocale: String
            get() = Locale.getDefault().country

        init {
            versionName = getVersionNameInternal()
            osName = getOsNameInternal()
            osVersion = getOsVersionInternal()
            brand = getBrandInternal()
            manufacturer = getManufacturerInternal()
            model = getModelInternal()
            carrier = getCarrierInternal()
            country = getCountryInternal()
            language = getLanguageInternal()
        }

        private fun getVersionNameInternal(): String? {
            val packageInfo: PackageInfo
            try {
                packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
                return packageInfo.versionName
            } catch (e: PackageManager.NameNotFoundException) {
            }

            return null
        }

        private fun getOsNameInternal(): String {
            return "android"
        }

        private fun getOsVersionInternal(): String {
            return Build.VERSION.RELEASE
        }

        private fun getBrandInternal(): String {
            return Build.BRAND
        }

        private fun getManufacturerInternal(): String {
            return Build.MANUFACTURER
        }

        private fun getModelInternal(): String {
            return Build.MODEL
        }

        private fun getCarrierInternal(): String? {
            try {
                val manager = context
                        .getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                return manager.networkOperatorName
            } catch (e: Exception) {
                // Failed to get network operator name from network
            }

            return null
        }

        private fun getCountryInternal(): String? {
            val country = countryFromNetwork
            return if (!Utils.isEmptyString(country)) {
                country
            } else countryFromLocale
        }

        private fun getLanguageInternal(): String {
            return Locale.getDefault().language
        }

    }

    private fun getCachedInfo(): CachedInfo {
        if (cachedInfo == null) {
            cachedInfo = CachedInfo()
        }
        return cachedInfo!!
    }

    fun prefetch() {
        getCachedInfo()
    }

    companion object {

        fun generateUUID(): String {
            return UUID.randomUUID().toString()
        }
    }

}

object Constants {

    val EVENT_LOG_URL = "https://journal.blokada.org/"
    val PACKAGE_NAME = "org.blokada"
    val LIBRARY = BuildConfig.FLAVOR
    val VERSION = "v3"

    val API_VERSION = 2
    val DATABASE_NAME = PACKAGE_NAME
    val DATABASE_VERSION = 3
    val DEFAULT_INSTANCE = "\$default_instance"

    val EVENT_UPLOAD_THRESHOLD = 30
    val EVENT_UPLOAD_MAX_BATCH_SIZE = 100
    val EVENT_MAX_COUNT = 1000
    val EVENT_REMOVE_BATCH_SIZE = 20
    val EVENT_UPLOAD_PERIOD_MILLIS = (30 * 1000).toLong() // 30s
    val MIN_TIME_BETWEEN_SESSIONS_MILLIS = (5 * 60 * 1000).toLong() // 5m
    val SESSION_TIMEOUT_MILLIS = (30 * 60 * 1000).toLong() // 30m
    val MAX_STRING_LENGTH = 1024
    val MAX_PROPERTY_KEYS = 1000

    val PREFKEY_LAST_EVENT_ID = "$PACKAGE_NAME.lastEventId"
    val PREFKEY_LAST_EVENT_TIME = "$PACKAGE_NAME.lastEventTime"
    val PREFKEY_LAST_IDENTIFY_ID = "$PACKAGE_NAME.lastIdentifyId"
    val PREFKEY_PREVIOUS_SESSION_ID = "$PACKAGE_NAME.previousSessionId"
    val PREFKEY_DEVICE_ID = "$PACKAGE_NAME.deviceId"
    val PREFKEY_USER_ID = "$PACKAGE_NAME.userId"
    val PREFKEY_OPT_OUT = "$PACKAGE_NAME.optOut"

    val IDENTIFY_EVENT = "\$identify"
    val AMP_OP_CLEAR_ALL = "\$clearAll"
    val AMP_OP_SET = "\$set"

}

class Identify {

    private var userPropertiesOperationsInternal = JSONObject()
    protected var userProperties: MutableSet<String> = HashSet()

    fun clearAll(): Identify {
        if (userPropertiesOperationsInternal.length() > 0) {
            if (!userProperties.contains(Constants.AMP_OP_CLEAR_ALL)) {
                JournalLog.getLogger().w(TAG, String.format(
                        "Need to send \$clearAll on its own Identify object without any other operations, ignoring \$clearAll"
                ))
            }
            return this
        }

        try {
            userPropertiesOperationsInternal.put(Constants.AMP_OP_CLEAR_ALL, "-")
        } catch (e: JSONException) {
            JournalLog.getLogger().e(TAG, e.toString())
        }

        return this
    }


    private fun addToUserProperties(operation: String, property: String, value: Any?) {
        if (Utils.isEmptyString(property)) {
            JournalLog.getLogger().w(TAG,
                    "Attempting to perform operation $operation with a null or empty string property, ignoring"
            )
            return
        }

        if (value == null) {
            JournalLog.getLogger().w(TAG,
                    "Attempting to perform operation $operation with null value for property $property, ignoring"
            )
            return
        }

        // check that clearAll wasn't already used in this Identify
        if (userPropertiesOperationsInternal.has(Constants.AMP_OP_CLEAR_ALL)) {
            JournalLog.getLogger().w(TAG,
                    "This Identify already contains a \$clearAll operation, ignoring operation $operation"
            )
            return
        }

        // check if property already used in previous operation
        if (userProperties.contains(property)) {
            JournalLog.getLogger().w(TAG,
                    "Already used property $property in previous operation, ignoring operation $operation"
            )
            return
        }

        try {
            if (!userPropertiesOperationsInternal.has(operation)) {
                userPropertiesOperationsInternal.put(operation, JSONObject())
            }
            userPropertiesOperationsInternal.getJSONObject(operation).put(property, value)
            userProperties.add(property)
        } catch (e: JSONException) {
            JournalLog.getLogger().e(TAG, e.toString())
        }

    }

    fun setUserProperty(property: String, value: Any): Identify {
        addToUserProperties(Constants.AMP_OP_SET, property, value)
        return this
    }

    fun getUserPropertiesOperations(): JSONObject {
        try {
            return JSONObject(userPropertiesOperationsInternal.toString())
        } catch (e: JSONException) {
            JournalLog.getLogger().e(TAG, e.toString())
        }

        return JSONObject()
    }

    companion object {
        val TAG = "buildtype.Identify"
    }
}

internal class DatabaseHelper protected constructor(context: Context, instance: String) : SQLiteOpenHelper(context, getDatabaseName(instance), null, Constants.DATABASE_VERSION) {

    private val file: File
    private val instanceName: String

    val eventCount: Long
        @Synchronized get() = getEventCountFromTable(EVENT_TABLE_NAME)

    val identifyCount: Long
        @Synchronized get() = getEventCountFromTable(IDENTIFY_TABLE_NAME)

    val totalEventCount: Long
        @Synchronized get() = eventCount + identifyCount

    init {
        file = context.getDatabasePath(getDatabaseName(instance))
        instanceName = Utils.normalizeInstanceName(instance)
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(CREATE_STORE_TABLE)
        db.execSQL(CREATE_LONG_STORE_TABLE)



        db.execSQL(CREATE_EVENTS_TABLE)
        db.execSQL(CREATE_IDENTIFYS_TABLE)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion > newVersion) {
            logger.e(TAG, "onUpgrade() with invalid oldVersion and newVersion")
            resetDatabase(db)
            return
        }

        if (newVersion <= 1) {
            return
        }

        when (oldVersion) {
            1 -> {
                db.execSQL(CREATE_STORE_TABLE)
                if (newVersion > 2) onUpgrade(db, 2, newVersion)
            }
            2 -> {
                db.execSQL(CREATE_IDENTIFYS_TABLE)
                db.execSQL(CREATE_LONG_STORE_TABLE)
                if (newVersion > 3) onUpgrade(db, 3, newVersion)
            }
            3 -> {
            }
            else -> {
                logger.e(TAG, "onUpgrade() with unknown oldVersion $oldVersion")
                resetDatabase(db)
            }
        }
    }

    private fun resetDatabase(db: SQLiteDatabase) {
        db.execSQL("DROP TABLE IF EXISTS $STORE_TABLE_NAME")
        db.execSQL("DROP TABLE IF EXISTS $LONG_STORE_TABLE_NAME")
        db.execSQL("DROP TABLE IF EXISTS $EVENT_TABLE_NAME")
        db.execSQL("DROP TABLE IF EXISTS $IDENTIFY_TABLE_NAME")
        onCreate(db)
    }

    @Synchronized
    fun insertOrReplaceKeyValue(key: String, value: String?): Long {
        return if (value == null)
            deleteKeyFromTable(STORE_TABLE_NAME, key)
        else
            insertOrReplaceKeyValueToTable(STORE_TABLE_NAME, key, value)
    }

    @Synchronized
    fun insertOrReplaceKeyLongValue(key: String, value: Long?): Long {
        return if (value == null)
            deleteKeyFromTable(LONG_STORE_TABLE_NAME, key)
        else
            insertOrReplaceKeyValueToTable(LONG_STORE_TABLE_NAME, key, value)
    }

    @Synchronized
    fun insertOrReplaceKeyValueToTable(table: String, key: String, value: Any): Long {
        var result: Long = -1
        try {
            val db = writableDatabase
            val contentValues = ContentValues()
            contentValues.put(KEY_FIELD, key)
            if (value is Long) {
                contentValues.put(VALUE_FIELD, value)
            } else {
                contentValues.put(VALUE_FIELD, value as String)
            }
            result = db.insertWithOnConflict(
                    table, null,
                    contentValues,
                    SQLiteDatabase.CONFLICT_REPLACE
            )
            if (result == -1L) {
                logger.w(TAG, "Insert failed")
            }
        } catch (e: SQLiteException) {
            logger.e(TAG, String.format("insertOrReplaceKeyValue in %s failed", table), e)

            delete()
        } catch (e: StackOverflowError) {
            logger.e(TAG, String.format("insertOrReplaceKeyValue in %s failed", table), e)

            delete()
        } finally {
            close()
        }
        return result
    }

    @Synchronized
    fun deleteKeyFromTable(table: String, key: String): Long {
        var result: Long = -1
        try {
            val db = writableDatabase
            result = db.delete(table, "$KEY_FIELD=?", arrayOf(key)).toLong()
        } catch (e: SQLiteException) {
            logger.e(TAG, String.format("deleteKey from %s failed", table), e)

            delete()
        } catch (e: StackOverflowError) {
            logger.e(TAG, String.format("deleteKey from %s failed", table), e)

            delete()
        } finally {
            close()
        }
        return result
    }

    @Synchronized
    fun addEvent(event: String): Long {
        return addEventToTable(EVENT_TABLE_NAME, event)
    }

    @Synchronized
    fun addIdentify(identifyEvent: String): Long {
        return addEventToTable(IDENTIFY_TABLE_NAME, identifyEvent)
    }

    @Synchronized
    private fun addEventToTable(table: String, event: String): Long {
        var result: Long = -1
        try {
            val db = writableDatabase
            val contentValues = ContentValues()
            contentValues.put(EVENT_FIELD, event)
            result = db.insert(table, null, contentValues)
            if (result == -1L) {
                logger.w(TAG, String.format("Insert into %s failed", table))
            }
        } catch (e: SQLiteException) {
            logger.e(TAG, String.format("addEvent to %s failed", table), e)

            delete()
        } catch (e: StackOverflowError) {
            logger.e(TAG, String.format("addEvent to %s failed", table), e)

            delete()
        } finally {
            close()
        }
        return result
    }

    @Synchronized
    fun getValue(key: String): String? {
        return getValueFromTable(STORE_TABLE_NAME, key) as String?
    }

    @Synchronized
    fun getLongValue(key: String): Long? {
        return getValueFromTable(LONG_STORE_TABLE_NAME, key) as Long?
    }

    @Synchronized
    protected fun getValueFromTable(table: String, key: String): Any? {
        var value: Any? = null
        var cursor: Cursor? = null
        try {
            val db = readableDatabase
            cursor = queryDb(
                    db, table, arrayOf(KEY_FIELD, VALUE_FIELD), "$KEY_FIELD = ?",
                    arrayOf(key), null, null, null, null
            )
            if (cursor.moveToFirst()) {
                value = if (table == STORE_TABLE_NAME) cursor.getString(1) else cursor.getLong(1)
            }
        } catch (e: SQLiteException) {
            logger.e(TAG, String.format("getValue from %s failed", table), e)

            delete()
        } catch (e: StackOverflowError) {
            logger.e(TAG, String.format("getValue from %s failed", table), e)

            delete()
        } catch (e: RuntimeException) {
            convertIfCursorWindowException(e)
        } finally {
            if (cursor != null) {
                cursor.close()
            }
            close()
        }
        return value
    }

    @Synchronized
    @Throws(JSONException::class)
    fun getEvents(
            upToId: Long, limit: Long): MutableList<JSONObject> {
        return getEventsFromTable(EVENT_TABLE_NAME, upToId, limit).toMutableList()
    }

    @Synchronized
    @Throws(JSONException::class)
    fun getIdentifys(
            upToId: Long, limit: Long): MutableList<JSONObject> {
        return getEventsFromTable(IDENTIFY_TABLE_NAME, upToId, limit).toMutableList()
    }

    @Synchronized
    @Throws(JSONException::class)
    protected fun getEventsFromTable(
            table: String, upToId: Long, limit: Long): List<JSONObject> {
        val events = LinkedList<JSONObject>()
        var cursor: Cursor? = null
        try {
            val db = readableDatabase
            cursor = queryDb(
                    db, table, arrayOf(ID_FIELD, EVENT_FIELD),
                    if (upToId >= 0) "$ID_FIELD <= $upToId" else null, null, null, null,
                    "$ID_FIELD ASC", if (limit >= 0) "" + limit else null
            )

            while (cursor.moveToNext()) {
                val eventId = cursor.getLong(0)
                val event = cursor.getString(1)
                if (Utils.isEmptyString(event)) {
                    continue
                }

                val obj = JSONObject(event)
                obj.put("event_id", eventId)
                events.add(obj)
            }
        } catch (e: SQLiteException) {
            logger.e(TAG, String.format("getEvents from %s failed", table), e)

            delete()
        } catch (e: StackOverflowError) {
            logger.e(TAG, String.format("removeEvent from %s failed", table), e)

            delete()
        } catch (e: RuntimeException) {
            convertIfCursorWindowException(e)
        } finally {
            if (cursor != null) {
                cursor.close()
            }
            close()
        }
        return events
    }

    @Synchronized
    private fun getEventCountFromTable(table: String): Long {
        var numberRows: Long = 0
        var statement: SQLiteStatement? = null
        try {
            val db = readableDatabase
            val query = "SELECT COUNT(*) FROM $table"
            statement = db.compileStatement(query)
            numberRows = statement!!.simpleQueryForLong()
        } catch (e: SQLiteException) {
            logger.e(TAG, String.format("getNumberRows for %s failed", table), e)

            delete()
        } catch (e: StackOverflowError) {
            logger.e(TAG, String.format("getNumberRows for %s failed", table), e)

            delete()
        } finally {
            if (statement != null) {
                statement.close()
            }
            close()
        }
        return numberRows
    }

    @Synchronized
    fun getNthEventId(n: Long): Long {
        return getNthEventIdFromTable(EVENT_TABLE_NAME, n)
    }

    @Synchronized
    fun getNthIdentifyId(n: Long): Long {
        return getNthEventIdFromTable(IDENTIFY_TABLE_NAME, n)
    }

    @Synchronized
    private fun getNthEventIdFromTable(table: String, n: Long): Long {
        var nthEventId: Long = -1
        var statement: SQLiteStatement? = null
        try {
            val db = readableDatabase
            val query = ("SELECT " + ID_FIELD + " FROM " + table + " LIMIT 1 OFFSET "
                    + (n - 1))
            statement = db.compileStatement(query)
            nthEventId = -1
            try {
                nthEventId = statement!!.simpleQueryForLong()
            } catch (e: SQLiteDoneException) {
                logger.w(TAG, e)
            }

        } catch (e: SQLiteException) {
            logger.e(TAG, String.format("getNthEventId from %s failed", table), e)

            delete()
        } catch (e: StackOverflowError) {
            logger.e(TAG, String.format("getNthEventId from %s failed", table), e)

            delete()
        } finally {
            if (statement != null) {
                statement.close()
            }
            close()
        }
        return nthEventId
    }

    @Synchronized
    fun removeEvents(maxId: Long) {
        removeEventsFromTable(EVENT_TABLE_NAME, maxId)
    }

    @Synchronized
    fun removeIdentifys(maxId: Long) {
        removeEventsFromTable(IDENTIFY_TABLE_NAME, maxId)
    }

    @Synchronized
    private fun removeEventsFromTable(table: String, maxId: Long) {
        try {
            val db = writableDatabase
            db.delete(table, "$ID_FIELD <= $maxId", null)
        } catch (e: SQLiteException) {
            logger.e(TAG, String.format("removeEvents from %s failed", table), e)

            delete()
        } catch (e: StackOverflowError) {
            logger.e(TAG, String.format("removeEvents from %s failed", table), e)

            delete()
        } finally {
            close()
        }
    }

    @Synchronized
    fun removeEvent(id: Long) {
        removeEventFromTable(EVENT_TABLE_NAME, id)
    }

    @Synchronized
    fun removeIdentify(id: Long) {
        removeEventFromTable(IDENTIFY_TABLE_NAME, id)
    }

    @Synchronized
    private fun removeEventFromTable(table: String, id: Long) {
        try {
            val db = writableDatabase
            db.delete(table, "$ID_FIELD = $id", null)
        } catch (e: SQLiteException) {
            logger.e(TAG, String.format("removeEvent from %s failed", table), e)

            delete()
        } catch (e: StackOverflowError) {
            logger.e(TAG, String.format("removeEvent from %s failed", table), e)

            delete()
        } finally {
            close()
        }
    }

    private fun delete() {
        try {
            close()
            file.delete()
        } catch (e: SecurityException) {
            logger.e(TAG, "delete failed", e)
        }

    }

    fun dbFileExists(): Boolean {
        return file.exists()
    }


    fun queryDb(
            db: SQLiteDatabase, table: String, columns: Array<String>, selection: String?,
            selectionArgs: Array<String>?, groupBy: String?, having: String?, orderBy: String?, limit: String?
    ): Cursor {
        return db.query(table, columns, selection, selectionArgs, groupBy, having, orderBy, limit)
    }

    companion object {

        val instances: MutableMap<String, DatabaseHelper> = HashMap()

        private val TAG = "buildtype.DatabaseHelper"

        protected val STORE_TABLE_NAME = "store"
        protected val LONG_STORE_TABLE_NAME = "long_store"
        private val KEY_FIELD = "key"
        private val VALUE_FIELD = "value"

        protected val EVENT_TABLE_NAME = "events"
        protected val IDENTIFY_TABLE_NAME = "identifys"
        private val ID_FIELD = "id"
        private val EVENT_FIELD = "event"

        private val CREATE_STORE_TABLE = ("CREATE TABLE IF NOT EXISTS "
                + STORE_TABLE_NAME + " (" + KEY_FIELD + " TEXT PRIMARY KEY NOT NULL, "
                + VALUE_FIELD + " TEXT);")
        private val CREATE_LONG_STORE_TABLE = ("CREATE TABLE IF NOT EXISTS "
                + LONG_STORE_TABLE_NAME + " (" + KEY_FIELD + " TEXT PRIMARY KEY NOT NULL, "
                + VALUE_FIELD + " INTEGER);")
        private val CREATE_EVENTS_TABLE = ("CREATE TABLE IF NOT EXISTS "
                + EVENT_TABLE_NAME + " (" + ID_FIELD + " INTEGER PRIMARY KEY AUTOINCREMENT, "
                + EVENT_FIELD + " TEXT);")
        private val CREATE_IDENTIFYS_TABLE = ("CREATE TABLE IF NOT EXISTS "
                + IDENTIFY_TABLE_NAME + " (" + ID_FIELD + " INTEGER PRIMARY KEY AUTOINCREMENT, "
                + EVENT_FIELD + " TEXT);")

        private val logger = JournalLog.getLogger()

        @Synchronized
        fun getDatabaseHelper(context: Context, instance: String?): DatabaseHelper {
            var instance = instance
            instance = Utils.normalizeInstanceName(instance)
            var dbHelper: DatabaseHelper? = instances[instance]
            if (dbHelper == null) {
                dbHelper = DatabaseHelper(context.applicationContext, instance)
                instances[instance] = dbHelper
            }
            return dbHelper
        }

        private fun getDatabaseName(instance: String): String {
            return if (Utils.isEmptyString(instance) || instance == Constants.DEFAULT_INSTANCE) Constants.DATABASE_NAME else Constants.DATABASE_NAME + "_" + instance
        }

        private fun convertIfCursorWindowException(e: RuntimeException) {
            val message = e.message
            if (!Utils.isEmptyString(message) && message!!.startsWith("Cursor window allocation of")) {
                throw CursorWindowAllocationException(message)
            } else {
                throw e
            }
        }
    }
}
