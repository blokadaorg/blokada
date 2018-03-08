package tunnel

import android.app.Activity
import android.content.Context
import android.net.VpnService
import nl.komponents.kovenant.Deferred
import nl.komponents.kovenant.deferred


/**
 * ATunnelPermsUtils contains bits and pieces required to ask user for Tunnel
 * permissions using Android APIs.
 */

/**
 * Initiates the procedure causing the OS to display the permission dialog.
 *
 * Returns a deferred object which will be resolved once the flow is finished.
 * If permissions are already granted, the deferred is already resolved.
 */
fun startAskTunnelPermissions(act: Activity): Deferred<Boolean, Exception> {
    val deferred = deferred<Boolean, Exception> { }
    val intent = VpnService.prepare(act)
    when (intent) {
        null -> deferred.resolve(true)
        else -> act.startActivityForResult(intent, 0)
    }
    setDeferred(deferred)
    return deferred
}

/**
 * Finishes the flow. Should be hooked up to onActivityResult() of Activity.
 */
fun stopAskTunnelPermissions(resultCode: Int) {
    val deferred = getDeferred()
    when {
        deferred == null -> return
        resultCode == -1 -> deferred.resolve(true)
        else -> deferred.resolve(false)
    }
    setDeferred(null)
}

/**
 * Checks tunnel permissions and throws exception if not granted.
 */
fun checkTunnelPermissions(ctx: Context) {
    if (VpnService.prepare(ctx) != null) {
        throw Exception("no tunnel permissions")
    }
}

/**
 * TODO: make this thing nicer.
 */
private var deferredActivityResult: Deferred<Boolean, Exception>? = null
@Synchronized private fun setDeferred(deferred: Deferred<Boolean, Exception>?) {
    deferredActivityResult = deferred
}
@Synchronized private fun getDeferred(): Deferred<Boolean, Exception>? {
    return deferredActivityResult
}

