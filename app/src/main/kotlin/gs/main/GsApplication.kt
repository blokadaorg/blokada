package gs.main

import android.app.Application

open class GsApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        registerUncaughtExceptionHandler(this)
    }
}
