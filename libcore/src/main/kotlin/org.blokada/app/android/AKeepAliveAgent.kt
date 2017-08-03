package org.blokada.app.android

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder

/**
 *
 */
class AKeepAliveAgent {
    private val serviceConnection = object: ServiceConnection {
        @Synchronized override fun onServiceConnected(name: ComponentName, binder: IBinder) {}
        @Synchronized override fun onServiceDisconnected(name: ComponentName?) {}
    }

    fun bind(ctx: Context) {
        val intent = Intent(ctx, AKeepAliveService::class.java)
        intent.setAction(AKeepAliveService.BINDER_ACTION)
        ctx.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
    }

    fun unbind(ctx: Context) {
        try { ctx.unbindService(serviceConnection) } catch (e: Exception) {}
    }
}