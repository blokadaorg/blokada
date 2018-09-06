package tunnel

import android.app.Activity
import android.net.VpnService
import core.AndroidKontext
import core.Kontext
import kotlinx.coroutines.experimental.CompletableDeferred

private var deferred = CompletableDeferred<Boolean>()

fun askTunnelPermission(ktx: Kontext, act: Activity) = {
    ktx.v("asking for tunnel permissions")
    deferred.completeExceptionally(Exception("new permission request"))
    deferred = CompletableDeferred()
    val intent = VpnService.prepare(act)
    when (intent) {
        null -> deferred.complete(true)
        else -> act.startActivityForResult(intent, 0)
    }
    deferred
}()

fun tunnelPermissionResult(ktx: Kontext, code: Int) = {
    ktx.v("received tunnel permissions response", code)
    when {
        deferred.isCompleted -> Unit
        code == -1 -> deferred.complete(true)
        else -> deferred.completeExceptionally(Exception("permission result: $code"))
    }
}()

fun checkTunnelPermissions(ktx: AndroidKontext) {
    if (VpnService.prepare(ktx.ctx) != null) {
        throw Exception("no tunnel permissions")
    }
}
