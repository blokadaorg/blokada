package core2

//fun Context.getPermissions() = VpnService.prepare(this) == null
//
//fun Activity.startAskTunnelPermissions(c: Pipe) = runBlocking {
//    val intent = VpnService.prepare(this@startAskTunnelPermissions)
//    when (intent) {
//        null -> {
//            c.out.send("askPermissions: already granted")
//        }
//        else -> {
//            c.out.send("askPermissions: starting activity")
//            startActivityForResult(intent, 0)
//            if (tunnelPermissionsChannel.receive() != -1)
//                c.out.send("askPermissions: rejected")
//            else
//                c.out.send("askPermissions: granted")
//        }
//    }
//}
//
//fun Activity.stopAskTunnelPermissions(resultCode: Int) = runBlocking {
//    tunnelPermissionsChannel.send(resultCode)
//}
//
//private val tunnelPermissionsChannel = Channel<Int>()

