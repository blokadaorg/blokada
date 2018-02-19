package org.blokada.main

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import com.github.salomonbrys.kodein.instance
import gs.environment.Journal
import gs.environment.inject
import org.blokada.property.State


class AKeepAliveService : Service() {

    companion object Statics {
        val BINDER_ACTION = "AKeepAliveService"
    }

    class KeepAliveBinder : Binder()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val j: Journal = inject().instance()
        val s: State = inject().instance()

        j.log("KeepAliveService start command")
        return Service.START_STICKY
    }

    private var binder: KeepAliveBinder? = null
    override fun onBind(intent: Intent?): IBinder? {
        if (BINDER_ACTION.equals(intent?.action)) {
            binder = KeepAliveBinder()
            return binder
        }
        return null
    }

    override fun onUnbind(intent: Intent?): Boolean {
        binder = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        sendBroadcast(Intent("org.blokada.keepAlive"))
    }

}
