package buildtype

import android.app.Application
import android.content.Context
import android.content.SharedPreferences
import android.util.Pair
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.IOException
import java.io.UnsupportedEncodingException
import java.util.*
import java.util.concurrent.atomic.AtomicBoolean

class JournalClient(instance: String) {

    protected var context: Context? = null
    protected var httpClient: OkHttpClient? = null
    private var dbHelper: DatabaseHelper? = null
    protected var apiKey: String? = null
    protected var instanceName: String
    private var userIdInternal: String? = null
    private var deviceIdInternal: String? = null
    protected var initialized = false

    var isOptedOut = false
        private set
    private var offline = false
    protected var platform: String? = null

    internal var sessionId: Long = -1
    internal var sequenceNumber: Long = 0
    internal var lastEventIdInternal: Long = -1
    internal var lastIdentifyIdInternal: Long = -1
    internal var lastEventTimeInternal: Long = -1
    internal var previousSessionIdInternal: Long = -1

    private var deviceInfo: DeviceInfo? = null

    private var eventUploadThreshold = Constants.EVENT_UPLOAD_THRESHOLD
    private var eventUploadMaxBatchSize = Constants.EVENT_UPLOAD_MAX_BATCH_SIZE
    private var eventMaxCount = Constants.EVENT_MAX_COUNT
    private var eventUploadPeriodMillis = Constants.EVENT_UPLOAD_PERIOD_MILLIS
    private var minTimeBetweenSessionsMillis = Constants.MIN_TIME_BETWEEN_SESSIONS_MILLIS
    private var sessionTimeoutMillis = Constants.SESSION_TIMEOUT_MILLIS
    private var backoffUpload = false
    private var backoffUploadBatchSize = eventUploadMaxBatchSize
    private var usingForegroundTracking = false
    private var trackingSessionEvents = false
    private var inForeground = false
    private var flushEventsOnClose = true

    private val updateScheduled = AtomicBoolean(false)
    internal var uploadingCurrently = AtomicBoolean(false)

    internal var lastError: Throwable? = null
    internal var url = Constants.EVENT_LOG_URL
    internal var logThread = WorkerThread("logThread")
    internal var httpThread = WorkerThread("httpThread")


    internal val nextSequenceNumber: Long
        get() {
            sequenceNumber++
            dbHelper?.insertOrReplaceKeyLongValue(SEQUENCE_NUMBER_KEY, sequenceNumber)
            return sequenceNumber
        }

    private
    val invalidDeviceIds: Set<String>
        get() {
            val invalidDeviceIds = HashSet<String>()
            invalidDeviceIds.add("")
            invalidDeviceIds.add("9774d56d682e549c")
            invalidDeviceIds.add("unknown")
            invalidDeviceIds.add("000000000000000")
            invalidDeviceIds.add("Android")
            invalidDeviceIds.add("DEFACE")
            invalidDeviceIds.add("00000000-0000-0000-0000-000000000000")

            return invalidDeviceIds
        }


    protected val currentTimeMillis: Long
        get() = System.currentTimeMillis()

    init {
        this.instanceName = Utils.normalizeInstanceName(instance)
        logThread.start()
        httpThread.start()
    }

    @JvmOverloads
    fun initialize(context: Context, apiKey: String, userId: String? = null): JournalClient {
        return initialize(context, apiKey, userId, null)
    }

    @Synchronized
    fun initialize(context: Context, apiKey: String, userId: String?, platform: String?): JournalClient {
        this.context = context.applicationContext
        this.apiKey = apiKey
        this.dbHelper = DatabaseHelper.getDatabaseHelper(context, this.instanceName)
        this.platform = if (Utils.isEmptyString(platform)) "Android" else platform

        val client = this
        runOnLogThread(Runnable {
            if (!initialized) {

                try {
                    if (instanceName == Constants.DEFAULT_INSTANCE) {
                        JournalClient.upgradePrefs(context)
                        JournalClient.upgradeSharedPrefsToDB(context)
                    }
                    val b = OkHttpClient.Builder()
                    b.hostnameVerifier { hostname, session -> true }
                    httpClient = b.build()
                    initializeDeviceInfo()

                    if (userId != null) {
                        client.userIdInternal = userId
                        dbHelper?.insertOrReplaceKeyValue(USER_ID_KEY, userId)
                    } else {
                        client.userIdInternal = dbHelper?.getValue(USER_ID_KEY)
                    }
                    val optOutLong = dbHelper?.getLongValue(OPT_OUT_KEY)
                    isOptedOut = optOutLong != null && optOutLong == 1L


                    previousSessionIdInternal = getLongvalue(PREVIOUS_SESSION_ID_KEY, -1)
                    if (previousSessionIdInternal >= 0) {
                        sessionId = previousSessionIdInternal
                    }

                    sequenceNumber = getLongvalue(SEQUENCE_NUMBER_KEY, 0)
                    lastEventIdInternal = getLongvalue(LAST_EVENT_ID_KEY, -1)
                    lastIdentifyIdInternal = getLongvalue(LAST_IDENTIFY_ID_KEY, -1)
                    lastEventTimeInternal = getLongvalue(LAST_EVENT_TIME_KEY, -1)

                    initialized = true

                } catch (e: CursorWindowAllocationException) {
                    logger.e(TAG, String.format(
                            "Failed to initialize Journal SDK due to: %s", e.message
                    ))
                    client.apiKey = null
                }

            }
        })

        return this
    }

    fun enableForegroundTracking(app: Application): JournalClient {
        if (usingForegroundTracking || !contextAndApiKeySet("enableForegroundTracking()")) {
            return this
        }

        app.registerActivityLifecycleCallbacks(JournalCallbacks(this))
        return this
    }

    private fun initializeDeviceInfo() {
        deviceInfo = DeviceInfo(context!!)
        deviceIdInternal = initializeDeviceId()
        deviceInfo!!.prefetch()
    }

    fun setEventUploadThreshold(eventUploadThreshold: Int): JournalClient {
        this.eventUploadThreshold = eventUploadThreshold
        return this
    }

    fun setEventUploadMaxBatchSize(eventUploadMaxBatchSize: Int): JournalClient {
        this.eventUploadMaxBatchSize = eventUploadMaxBatchSize
        this.backoffUploadBatchSize = eventUploadMaxBatchSize
        return this
    }

    fun setEventMaxCount(eventMaxCount: Int): JournalClient {
        this.eventMaxCount = eventMaxCount
        return this
    }

    fun setEventUploadPeriodMillis(eventUploadPeriodMillis: Int): JournalClient {
        this.eventUploadPeriodMillis = eventUploadPeriodMillis.toLong()
        return this
    }

    fun setMinTimeBetweenSessionsMillis(minTimeBetweenSessionsMillis: Long): JournalClient {
        this.minTimeBetweenSessionsMillis = minTimeBetweenSessionsMillis
        return this
    }

    fun setSessionTimeoutMillis(sessionTimeoutMillis: Long): JournalClient {
        this.sessionTimeoutMillis = sessionTimeoutMillis
        return this
    }

    fun setOptOut(optOut: Boolean): JournalClient {
        if (!contextAndApiKeySet("setOptOut()")) {
            return this
        }

        val client = this
        runOnLogThread(Runnable {
            if (Utils.isEmptyString(apiKey)) {
                return@Runnable
            }
            client.isOptedOut = optOut
            dbHelper?.insertOrReplaceKeyLongValue(OPT_OUT_KEY, if (optOut) 1L else 0L)
        })
        return this
    }

    fun setOffline(offline: Boolean): JournalClient {
        this.offline = offline

        if (!offline) {
            uploadEvents()
        }

        return this
    }

    fun setFlushEventsOnClose(flushEventsOnClose: Boolean): JournalClient {
        this.flushEventsOnClose = flushEventsOnClose
        return this
    }

    fun trackSessionEvents(trackingSessionEvents: Boolean): JournalClient {
        this.trackingSessionEvents = trackingSessionEvents
        return this
    }

    internal fun useForegroundTracking() {
        usingForegroundTracking = true
    }

    @JvmOverloads
    fun logEvent(eventType: String, eventProperties: JSONObject? = null, outOfSession: Boolean = false) {
        logEvent(eventType, eventProperties, null, outOfSession)
    }

    @JvmOverloads
    fun logEvent(eventType: String, eventProperties: JSONObject?, groups: JSONObject?, outOfSession: Boolean = false) {
        logEvent(eventType, eventProperties, groups, currentTimeMillis, outOfSession)
    }

    fun logEvent(eventType: String, eventProperties: JSONObject?, groups: JSONObject?, timestamp: Long, outOfSession: Boolean) {
        if (validateLogEvent(eventType)) {
            logEventAsync(
                    eventType, eventProperties, null, null, groups, timestamp, outOfSession
            )
        }
    }

    protected fun validateLogEvent(eventType: String): Boolean {
        if (Utils.isEmptyString(eventType)) {
            logger.e(TAG, "Argument eventType cannot be null or blank in logEvent()")
            return false
        }

        return contextAndApiKeySet("logEvent()")
    }

    protected fun logEventAsync(eventType: String, eventProperties: JSONObject?,
                                apiProperties: JSONObject?, userProperties: JSONObject?,
                                groups: JSONObject?, timestamp: Long, outOfSession: Boolean) {
        var eventProperties = eventProperties
        var userProperties = userProperties
        var groups = groups





        if (eventProperties != null) {
            eventProperties = Utils.cloneJSONObject(eventProperties)
        }

        if (userProperties != null) {
            userProperties = Utils.cloneJSONObject(userProperties)
        }

        if (groups != null) {
            groups = Utils.cloneJSONObject(groups)
        }

        val copyEventProperties = eventProperties
        val copyUserProperties = userProperties
        val copyGroups = groups
        runOnLogThread(Runnable {
            if (Utils.isEmptyString(apiKey)) {
                return@Runnable
            }
            logEvent(
                    eventType, copyEventProperties, apiProperties,
                    copyUserProperties, copyGroups, timestamp, outOfSession
            )
        })
    }

    protected fun logEvent(eventType: String, eventProperties: JSONObject?, apiProperties: JSONObject?,
                           userProperties: JSONObject?, groups: JSONObject?, timestamp: Long, outOfSession: Boolean): Long {
        var apiProperties = apiProperties
        logger.d(TAG, "Logged event to Journal: $eventType")

        if (isOptedOut) {
            return -1
        }


        val loggingSessionEvent = trackingSessionEvents && (eventType == START_SESSION_EVENT || eventType == END_SESSION_EVENT)

        if (!loggingSessionEvent && !outOfSession) {

            if (!inForeground) {
                startNewSessionIfNeeded(timestamp)
            } else {
                refreshSessionTime(timestamp)
            }
        }

        var result: Long = -1
        val event = JSONObject()
        try {
            event.put("event_type", replaceWithJSONNull(eventType))
            event.put("timestamp", timestamp)
            event.put("user_id", replaceWithJSONNull(userIdInternal))
            event.put("device_id", replaceWithJSONNull(deviceIdInternal))
            event.put("session_id", if (outOfSession) -1 else sessionId)
            event.put("version_name", replaceWithJSONNull(deviceInfo!!.versionName))
            event.put("os_name", replaceWithJSONNull(deviceInfo!!.osName))
            event.put("os_version", replaceWithJSONNull(deviceInfo!!.osVersion))
            event.put("device_brand", replaceWithJSONNull(deviceInfo!!.brand))
            event.put("device_manufacturer", replaceWithJSONNull(deviceInfo!!.manufacturer))
            event.put("device_model", replaceWithJSONNull(deviceInfo!!.model))
            event.put("carrier", replaceWithJSONNull(deviceInfo!!.carrier))
            event.put("country", replaceWithJSONNull(deviceInfo!!.country))
            event.put("language", replaceWithJSONNull(deviceInfo!!.language))
            event.put("platform", platform)
            event.put("uuid", UUID.randomUUID().toString())
            event.put("sequence_number", nextSequenceNumber)

            val library = JSONObject()
            library.put("name", Constants.LIBRARY)
            library.put("version", Constants.VERSION)
            event.put("library", library)

            apiProperties = if (apiProperties == null) JSONObject() else apiProperties
            apiProperties.put("gps_enabled", false)

            event.put("api_properties", apiProperties)
            event.put("event_properties", if (eventProperties == null)
                JSONObject()
            else
                truncate(eventProperties))
            event.put("user_properties", if (userProperties == null)
                JSONObject()
            else
                truncate(userProperties))
            event.put("groups", if (groups == null) JSONObject() else truncate(groups))

            result = saveEvent(eventType, event)
        } catch (e: JSONException) {
            logger.e(TAG, String.format(
                    "JSON Serialization of event type %s failed, skipping: %s", eventType, e.toString()
            ))
        }

        return result
    }

    protected fun saveEvent(eventType: String, event: JSONObject): Long {
        val eventString = event.toString()
        if (Utils.isEmptyString(eventString)) {
            logger.e(TAG, String.format(
                    "Detected empty event string for event type %s, skipping", eventType
            ))
            return -1
        }

        if (eventType == Constants.IDENTIFY_EVENT) {
            lastIdentifyIdInternal = dbHelper?.addIdentify(eventString) ?: -1
            setLastIdentifyId(lastIdentifyIdInternal)
        } else {
            lastEventIdInternal = dbHelper?.addEvent(eventString) ?: -1
            setLastEventId(lastEventIdInternal)
        }

        val numEventsToRemove = Math.min(
                Math.max(1, eventMaxCount / 10),
                Constants.EVENT_REMOVE_BATCH_SIZE
        )
        if (dbHelper?.eventCount ?: 0 > eventMaxCount) {
            dbHelper?.removeEvents(dbHelper?.getNthEventId(numEventsToRemove.toLong()) ?: -1)
        }
        if (dbHelper?.identifyCount ?: 0 > eventMaxCount) {
            dbHelper?.removeIdentifys(dbHelper?.getNthIdentifyId(numEventsToRemove.toLong()) ?: -1)
        }

        val totalEventCount = dbHelper?.totalEventCount ?: 0
        if (totalEventCount % eventUploadThreshold == 0L && totalEventCount >= eventUploadThreshold) {
            updateServer()
        } else {
            updateServerLater(eventUploadPeriodMillis)
        }

        return if (eventType == Constants.IDENTIFY_EVENT) lastIdentifyIdInternal else lastEventIdInternal
    }

    private fun getLongvalue(key: String, defaultValue: Long): Long {
        val value = dbHelper?.getLongValue(key)
        return value ?: defaultValue
    }

    internal fun setLastEventTime(timestamp: Long) {
        lastEventTimeInternal = timestamp
        dbHelper?.insertOrReplaceKeyLongValue(LAST_EVENT_TIME_KEY, timestamp)
    }


    internal fun setLastEventId(eventId: Long) {
        lastEventIdInternal = eventId
        dbHelper?.insertOrReplaceKeyLongValue(LAST_EVENT_ID_KEY, eventId)
    }


    internal fun setLastIdentifyId(identifyId: Long) {
        lastIdentifyIdInternal = identifyId
        dbHelper?.insertOrReplaceKeyLongValue(LAST_IDENTIFY_ID_KEY, identifyId)
    }

    fun getSessionId(): Long {
        return sessionId
    }

    internal fun setPreviousSessionId(timestamp: Long) {
        previousSessionIdInternal = timestamp
        dbHelper?.insertOrReplaceKeyLongValue(PREVIOUS_SESSION_ID_KEY, timestamp)
    }

    internal fun startNewSessionIfNeeded(timestamp: Long): Boolean {
        if (inSession()) {

            if (isWithinMinTimeBetweenSessions(timestamp)) {
                refreshSessionTime(timestamp)
                return false
            }

            startNewSession(timestamp)
            return true
        }

        if (isWithinMinTimeBetweenSessions(timestamp)) {
            if (previousSessionIdInternal == -1L) {
                startNewSession(timestamp)
                return true
            }

            setSessionId(previousSessionIdInternal)
            refreshSessionTime(timestamp)
            return false
        }

        startNewSession(timestamp)
        return true
    }

    private fun startNewSession(timestamp: Long) {

        if (trackingSessionEvents) {
            sendSessionEvent(END_SESSION_EVENT)
        }

        setSessionId(timestamp)
        refreshSessionTime(timestamp)
        if (trackingSessionEvents) {
            sendSessionEvent(START_SESSION_EVENT)
        }
    }

    private fun inSession(): Boolean {
        return sessionId >= 0
    }

    private fun isWithinMinTimeBetweenSessions(timestamp: Long): Boolean {
        val sessionLimit = if (usingForegroundTracking)
            minTimeBetweenSessionsMillis
        else
            sessionTimeoutMillis
        return timestamp - lastEventTimeInternal < sessionLimit
    }

    private fun setSessionId(timestamp: Long) {
        sessionId = timestamp
        setPreviousSessionId(timestamp)
    }

    internal fun refreshSessionTime(timestamp: Long) {
        if (!inSession()) {
            return
        }

        setLastEventTime(timestamp)
    }

    private fun sendSessionEvent(sessionEvent: String) {
        if (!contextAndApiKeySet(String.format("sendSessionEvent('%s')", sessionEvent))) {
            return
        }

        if (!inSession()) {
            return
        }

        val apiProperties = JSONObject()
        try {
            apiProperties.put("special", sessionEvent)
        } catch (e: JSONException) {
            return
        }

        logEvent(sessionEvent, null, apiProperties, null, null, lastEventTimeInternal, false)
    }

    internal fun onExitForeground(timestamp: Long) {
        runOnLogThread(Runnable {
            if (Utils.isEmptyString(apiKey)) {
                return@Runnable
            }
            refreshSessionTime(timestamp)
            inForeground = false
            if (flushEventsOnClose) {
                updateServer()
            }
        })
    }

    internal fun onEnterForeground(timestamp: Long) {
        runOnLogThread(Runnable {
            if (Utils.isEmptyString(apiKey)) {
                return@Runnable
            }
            startNewSessionIfNeeded(timestamp)
            inForeground = true
        })
    }

    fun clearUserProperties() {
        val identify = Identify().clearAll()
        identify(identify)
    }

    @JvmOverloads
    fun identify(identify: Identify?, outOfSession: Boolean = false) {
        if (identify == null || identify.getUserPropertiesOperations().length() == 0 ||
                !contextAndApiKeySet("identify()"))
            return
        logEventAsync(
                Constants.IDENTIFY_EVENT, null, null, identify.getUserPropertiesOperations(), null, currentTimeMillis, outOfSession
        )
    }

    fun setGroup(groupType: String, groupName: Any) {
        if (!contextAndApiKeySet("setGroup()") || Utils.isEmptyString(groupType)) {
            return
        }
        var group: JSONObject? = null
        try {
            group = JSONObject().put(groupType, groupName)
        } catch (e: JSONException) {
            logger.e(TAG, e.toString())
        }

        val identify = Identify().setUserProperty(groupType, groupName)
        logEventAsync(Constants.IDENTIFY_EVENT, null, null, identify.getUserPropertiesOperations(),
                group, currentTimeMillis, false)
    }

    fun truncate(`object`: JSONObject?): JSONObject {
        if (`object` == null) {
            return JSONObject()
        }

        if (`object`.length() > Constants.MAX_PROPERTY_KEYS) {
            logger.w(TAG, "Warning: too many properties (more than 1000), ignoring")
            return JSONObject()
        }

        val keys = `object`.keys()
        while (keys.hasNext()) {
            val key = keys.next() as String

            try {
                val value = `object`.get(key)
                if (value.javaClass == String::class.java) {
                    `object`.put(key, truncate(value as String))
                } else if (value.javaClass == JSONObject::class.java) {
                    `object`.put(key, truncate(value as JSONObject))
                } else if (value.javaClass == JSONArray::class.java) {
                    `object`.put(key, truncate(value as JSONArray))
                }
            } catch (e: JSONException) {
                logger.e(TAG, e.toString())
            }

        }

        return `object`
    }

    @Throws(JSONException::class)
    fun truncate(array: JSONArray?): JSONArray {
        if (array == null) {
            return JSONArray()
        }

        for (i in 0 until array.length()) {
            val value = array.get(i)
            if (value.javaClass == String::class.java) {
                array.put(i, truncate(value as String))
            } else if (value.javaClass == JSONObject::class.java) {
                array.put(i, truncate(value as JSONObject))
            } else if (value.javaClass == JSONArray::class.java) {
                array.put(i, truncate(value as JSONArray))
            }
        }
        return array
    }

    fun truncate(value: String): String {
        return if (value.length <= Constants.MAX_STRING_LENGTH)
            value
        else
            value.substring(0, Constants.MAX_STRING_LENGTH)
    }

    fun getUserId(): String? {
        return userIdInternal
    }

    fun setUserId(userId: String): JournalClient {
        if (!contextAndApiKeySet("setUserId()")) {
            return this
        }

        val client = this
        runOnLogThread(Runnable {
            if (Utils.isEmptyString(client.apiKey)) {
                return@Runnable
            }
            client.userIdInternal = userId
            dbHelper?.insertOrReplaceKeyValue(USER_ID_KEY, userId)
        })
        return this
    }

    fun setDeviceId(deviceId: String): JournalClient {
        val invalidDeviceIds = invalidDeviceIds
        if (!contextAndApiKeySet("setDeviceId()") || Utils.isEmptyString(deviceId) ||
                invalidDeviceIds.contains(deviceId)) {
            return this
        }

        val client = this
        runOnLogThread(Runnable {
            if (Utils.isEmptyString(client.apiKey)) {
                return@Runnable
            }
            client.deviceIdInternal = deviceId
            dbHelper?.insertOrReplaceKeyValue(DEVICE_ID_KEY, deviceId)
        })
        return this
    }

    fun regenerateDeviceId(): JournalClient {
        if (!contextAndApiKeySet("regenerateDeviceId()")) {
            return this
        }

        val client = this
        runOnLogThread(Runnable {
            if (Utils.isEmptyString(client.apiKey)) {
                return@Runnable
            }
            val randomId = DeviceInfo.generateUUID() + "R"
            setDeviceId(randomId)
        })
        return this
    }


    fun uploadEvents() {
        if (!contextAndApiKeySet("uploadEvents()")) {
            return
        }

        logThread.post(Runnable {
            if (Utils.isEmptyString(apiKey)) {
                return@Runnable
            }
            updateServer()
        })
    }

    private fun updateServerLater(delayMillis: Long) {
        if (updateScheduled.getAndSet(true)) {
            return
        }

        logThread.postDelayed(Runnable {
            updateScheduled.set(false)
            updateServer()
        }, delayMillis)
    }


    @JvmOverloads
    protected fun updateServer(limit: Boolean = false) {
        if (isOptedOut || offline) {
            return
        }

        if (!uploadingCurrently.getAndSet(true)) {
            val totalEventCount = dbHelper?.totalEventCount ?: 0
            val batchSize = Math.min(
                    (if (limit) backoffUploadBatchSize else eventUploadMaxBatchSize).toLong(),
                    totalEventCount
            )

            if (batchSize <= 0) {
                uploadingCurrently.set(false)
                return
            }

            try {
                val events = dbHelper!!.getEvents(lastEventIdInternal, batchSize)
                val identifys = dbHelper!!.getIdentifys(lastIdentifyIdInternal, batchSize)

                val merged = mergeEventsAndIdentifys(
                        events, identifys, batchSize)
                val mergedEvents = merged.second
                if (mergedEvents.length() == 0) {
                    uploadingCurrently.set(false)
                    return
                }
                val maxEventId = merged.first.first
                val maxIdentifyId = merged.first.second
                val mergedEventsString = merged.second.toString()

                httpThread.post(Runnable { makeEventUploadPostRequest(httpClient!!, mergedEventsString, maxEventId, maxIdentifyId) })
            } catch (e: JSONException) {
                uploadingCurrently.set(false)
                logger.e(TAG, e.toString())


            } catch (e: CursorWindowAllocationException) {
                uploadingCurrently.set(false)
                logger.e(TAG, String.format(
                        "Caught Cursor window exception during event upload, deferring upload: %s",
                        e.message
                ))
            }

        }
    }

    @Throws(JSONException::class)
    protected fun mergeEventsAndIdentifys(events: MutableList<JSONObject>,
                                          identifys: MutableList<JSONObject>, numEvents: Long): Pair<Pair<Long, Long>, JSONArray> {
        val merged = JSONArray()
        var maxEventId: Long = -1
        var maxIdentifyId: Long = -1

        while (merged.length() < numEvents) {
            val noEvents = events.isEmpty()
            val noIdentifys = identifys.isEmpty()

            if (noEvents && noIdentifys) {
                logger.w(TAG, String.format(
                        "mergeEventsAndIdentifys: number of events and identifys " + "less than expected by %d", numEvents - merged.length())
                )
                break

            } else if (noIdentifys) {
                val event = events.removeAt(0)
                maxEventId = event.getLong("event_id")
                merged.put(event)

            } else if (noEvents) {
                val identify = identifys.removeAt(0)
                maxIdentifyId = identify.getLong("event_id")
                merged.put(identify)

            } else {
                if (!events[0].has("sequence_number") || events[0].getLong("sequence_number") < identifys[0].getLong("sequence_number")) {
                    val event = events.removeAt(0)
                    maxEventId = event.getLong("event_id")
                    merged.put(event)
                } else {
                    val identify = identifys.removeAt(0)
                    maxIdentifyId = identify.getLong("event_id")
                    merged.put(identify)
                }
            }
        }

        return Pair(Pair(maxEventId, maxIdentifyId), merged)
    }


    protected fun makeEventUploadPostRequest(client: OkHttpClient, events: String, maxEventId: Long, maxIdentifyId: Long) {
        val apiVersionString = "" + Constants.API_VERSION
        val timestampString = "" + currentTimeMillis

        var checksumString = ""
        try {
            val preimage = apiVersionString + apiKey + events + timestampString

            val messageDigest = buildtype.MD5()
            checksumString = bytesToHexString(messageDigest.digest(preimage.toByteArray(charset("UTF-8"))))
        } catch (e: UnsupportedEncodingException) {
            logger.e(TAG, e.toString())
        }

        val body = FormBody.Builder()
                .add("v", apiVersionString)
                .add("client", apiKey!!)
                .add("e", events)
                .add("upload_time", timestampString)
                .add("checksum", checksumString)
                .build()

        val request: Request
        try {
            request = Request.Builder()
                    .url(url)
                    .post(body)
                    .build()
        } catch (e: IllegalArgumentException) {
            logger.e(TAG, e.toString())
            uploadingCurrently.set(false)
            return
        }

        var uploadSuccess = false

        try {
            val response = client.newCall(request).execute()
            val stringResponse = response.body()!!.string()
            if (stringResponse == "success") {
                uploadSuccess = true
                logThread.post(Runnable {
                    if (maxEventId >= 0) dbHelper?.removeEvents(maxEventId)
                    if (maxIdentifyId >= 0) dbHelper?.removeIdentifys(maxIdentifyId)
                    uploadingCurrently.set(false)
                    if (dbHelper?.totalEventCount ?: 0 > eventUploadThreshold) {
                        logThread.post(Runnable { updateServer(backoffUpload) })
                    } else {
                        backoffUpload = false
                        backoffUploadBatchSize = eventUploadMaxBatchSize
                    }
                })
            } else if (stringResponse == "invalid_api_key") {
                logger.e(TAG, "Invalid API key, make sure your API key is correct in initialize()")
            } else if (stringResponse == "bad_checksum") {
                logger.w(TAG,
                        "Bad checksum, post request was mangled in transit, will attempt to reupload later")
            } else if (stringResponse == "request_db_write_failed") {
                logger.w(TAG,
                        "Couldn't write to request database on server, will attempt to reupload later")
            } else if (response.code() == 413) {

                if (backoffUpload && backoffUploadBatchSize == 1) {
                    if (maxEventId >= 0) dbHelper!!.removeEvent(maxEventId)
                    if (maxIdentifyId >= 0) dbHelper!!.removeIdentify(maxIdentifyId)
                }

                backoffUpload = true
                val numEvents = Math.min(dbHelper!!.eventCount.toInt(), backoffUploadBatchSize)
                backoffUploadBatchSize = Math.ceil(numEvents / 2.0).toInt()
                logger.w(TAG, "Request too large, will decrease size and attempt to reupload")
                logThread.post(Runnable {
                    uploadingCurrently.set(false)
                    updateServer(true)
                })
            } else {
                logger.w(TAG, "Upload failed, " + stringResponse
                        + ", will attempt to reupload later")
            }
        } catch (e: java.net.ConnectException) {
            lastError = e
        } catch (e: java.net.UnknownHostException) {
            lastError = e
        } catch (e: IOException) {
            logger.e(TAG, e.toString())
            lastError = e
        } catch (e: AssertionError) {
            logger.e(TAG, "Exception:", e)
            lastError = e
        } catch (e: Exception) {
            logger.e(TAG, "Exception:", e)
            lastError = e
        }

        if (!uploadSuccess) {
            uploadingCurrently.set(false)
        }

    }

    fun getDeviceId(): String? {
        return deviceIdInternal
    }

    private fun initializeDeviceId(): String {
        val invalidIds = invalidDeviceIds

        val deviceId = dbHelper?.getValue(DEVICE_ID_KEY)
        if (!(Utils.isEmptyString(deviceId) || invalidIds.contains(deviceId))) {
            return deviceId!!
        }

        val randomId = DeviceInfo.generateUUID() + "R"
        dbHelper?.insertOrReplaceKeyValue(DEVICE_ID_KEY, randomId)
        return randomId
    }

    protected fun runOnLogThread(r: Runnable) {
        if (Thread.currentThread() !== logThread) {
            logThread.post(r)
        } else {
            r.run()
        }
    }

    protected fun replaceWithJSONNull(obj: Any?): Any {
        return obj ?: JSONObject.NULL
    }

    @Synchronized
    protected fun contextAndApiKeySet(methodName: String): Boolean {
        if (context == null) {
            logger.e(TAG, "context cannot be null, set context with initialize() before calling $methodName")
            return false
        }
        if (Utils.isEmptyString(apiKey)) {
            logger.e(TAG,
                    "apiKey cannot be null or empty, set apiKey with initialize() before calling $methodName")
            return false
        }
        return true
    }

    private val HEX_CHARS = "0123456789ABCDEF".toCharArray()

    fun bytesToHexString(bytes: ByteArray): String {
        val result = StringBuffer()

        bytes.forEach {
            val octet = it.toInt()
            val firstIndex = (octet and 0xF0).ushr(4)
            val secondIndex = octet and 0x0F
            result.append(HEX_CHARS[firstIndex])
            result.append(HEX_CHARS[secondIndex])
        }

        return result.toString()
    }

    companion object {

        val TAG = "buildtype.JournalClient"
        private val logger = JournalLog.getLogger()

        val START_SESSION_EVENT = "session_start"
        val END_SESSION_EVENT = "session_end"
        val DEVICE_ID_KEY = "device_id"
        val USER_ID_KEY = "user_id"
        val OPT_OUT_KEY = "opt_out"
        val SEQUENCE_NUMBER_KEY = "sequence_number"
        val LAST_EVENT_TIME_KEY = "last_event_time"
        val LAST_EVENT_ID_KEY = "last_event_id"
        val LAST_IDENTIFY_ID_KEY = "last_identify_id"
        val PREVIOUS_SESSION_ID_KEY = "previous_session_id"

        @JvmOverloads
        internal fun upgradePrefs(context: Context, sourcePkgName: String? = null, targetPkgName: String? = null): Boolean {
            var sourcePkgName = sourcePkgName
            var targetPkgName = targetPkgName
            try {
                if (sourcePkgName == null) {
                    sourcePkgName = Constants.PACKAGE_NAME
                    try {
                        sourcePkgName = Constants::class.java.`package`.name
                    } catch (e: Exception) {
                    }

                }

                if (targetPkgName == null) {
                    targetPkgName = Constants.PACKAGE_NAME
                }

                if (targetPkgName == sourcePkgName) {
                    return false
                }

                val sourcePrefsName = sourcePkgName + "." + context!!.packageName
                val source = context.getSharedPreferences(sourcePrefsName, Context.MODE_PRIVATE)

                if (source.all.size == 0) {
                    return false
                }

                val prefsName = targetPkgName + "." + context.packageName
                val targetPrefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                val target = targetPrefs.edit()

                if (source.contains(sourcePkgName!! + ".previousSessionId")) {
                    target.putLong(Constants.PREFKEY_PREVIOUS_SESSION_ID,
                            source.getLong("$sourcePkgName.previousSessionId", -1))
                }
                if (source.contains("$sourcePkgName.deviceId")) {
                    target.putString(Constants.PREFKEY_DEVICE_ID,
                            source.getString("$sourcePkgName.deviceId", null))
                }
                if (source.contains("$sourcePkgName.userId")) {
                    target.putString(Constants.PREFKEY_USER_ID,
                            source.getString("$sourcePkgName.userId", null))
                }
                if (source.contains("$sourcePkgName.optOut")) {
                    target.putBoolean(Constants.PREFKEY_OPT_OUT,
                            source.getBoolean("$sourcePkgName.optOut", false))
                }

                target.apply()
                source.edit().clear().apply()

                logger.i(TAG, "Upgraded shared preferences from $sourcePrefsName to $prefsName")
                return true

            } catch (e: Exception) {
                logger.e(TAG, "Error upgrading shared preferences", e)
                return false
            }

        }

        @JvmOverloads
        internal fun upgradeSharedPrefsToDB(context: Context, sourcePkgName: String? = null): Boolean {
            var sourcePkgName = sourcePkgName
            if (sourcePkgName == null) {
                sourcePkgName = Constants.PACKAGE_NAME
            }

            val dbHelper = DatabaseHelper.getDatabaseHelper(context, null)
            val deviceId = dbHelper.getValue(DEVICE_ID_KEY)
            val previousSessionId = dbHelper.getLongValue(PREVIOUS_SESSION_ID_KEY)
            val lastEventTime = dbHelper.getLongValue(LAST_EVENT_TIME_KEY)
            if (!Utils.isEmptyString(deviceId) && previousSessionId != null && lastEventTime != null) {
                return true
            }

            val prefsName = sourcePkgName + "." + context!!.packageName
            val preferences = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)

            migrateStringValue(
                    preferences, Constants.PREFKEY_DEVICE_ID, null, dbHelper, DEVICE_ID_KEY
            )

            migrateLongValue(
                    preferences, Constants.PREFKEY_LAST_EVENT_TIME, -1, dbHelper, LAST_EVENT_TIME_KEY
            )

            migrateLongValue(
                    preferences, Constants.PREFKEY_LAST_EVENT_ID, -1, dbHelper, LAST_EVENT_ID_KEY
            )

            migrateLongValue(
                    preferences, Constants.PREFKEY_LAST_IDENTIFY_ID, -1, dbHelper, LAST_IDENTIFY_ID_KEY
            )

            migrateLongValue(
                    preferences, Constants.PREFKEY_PREVIOUS_SESSION_ID, -1,
                    dbHelper, PREVIOUS_SESSION_ID_KEY
            )

            migrateStringValue(
                    preferences, Constants.PREFKEY_USER_ID, null, dbHelper, USER_ID_KEY
            )

            migrateBooleanValue(
                    preferences, Constants.PREFKEY_OPT_OUT, false, dbHelper, OPT_OUT_KEY
            )

            return true
        }

        private fun migrateLongValue(prefs: SharedPreferences, prefKey: String, defValue: Long, dbHelper: DatabaseHelper, dbKey: String) {
            val value = dbHelper.getLongValue(dbKey)
            if (value != null) {
                return
            }
            val oldValue = prefs.getLong(prefKey, defValue)
            dbHelper.insertOrReplaceKeyLongValue(dbKey, oldValue)
            prefs.edit().remove(prefKey).apply()
        }

        private fun migrateStringValue(prefs: SharedPreferences, prefKey: String, defValue: String?, dbHelper: DatabaseHelper, dbKey: String) {
            val value = dbHelper.getValue(dbKey)
            if (!Utils.isEmptyString(value)) {
                return
            }
            val oldValue = prefs.getString(prefKey, defValue)
            if (!Utils.isEmptyString(oldValue)) {
                dbHelper.insertOrReplaceKeyValue(dbKey, oldValue)
                prefs.edit().remove(prefKey).apply()
            }
        }

        private fun migrateBooleanValue(prefs: SharedPreferences, prefKey: String, defValue: Boolean, dbHelper: DatabaseHelper, dbKey: String) {
            val value = dbHelper.getLongValue(dbKey)
            if (value != null) {
                return
            }
            val oldValue = prefs.getBoolean(prefKey, defValue)
            dbHelper.insertOrReplaceKeyLongValue(dbKey, if (oldValue) 1L else 0L)
            prefs.edit().remove(prefKey).apply()
        }
    }
}
