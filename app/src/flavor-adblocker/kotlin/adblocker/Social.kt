package adblocker

import android.content.Context
import com.github.salomonbrys.kodein.instance
import core.*
import gs.environment.inject
import org.blokada.R
import android.content.Intent

val DASH_ID_SHARE_COUNT = "social_share"

class SocialShareCount(
        val ctx: Context,
        val t: Tunnel = ctx.inject().instance()
) : Dash(DASH_ID_SHARE_COUNT,
        R.drawable.ic_share,
        text = ctx.resources.getString(R.string.social_share_count),
        onClick = {
            val sharingIntent = Intent(Intent.ACTION_SEND)
            sharingIntent.type = "text/plain"
            sharingIntent.putExtra(Intent.EXTRA_SUBJECT, ctx.resources.getString(R.string.social_share_sub))
            sharingIntent.putExtra(Intent.EXTRA_TEXT, getMessage(ctx, t.tunnelDropStart.invoke(), t.tunnelDropCount.invoke()))

            val chooserIntent = Intent.createChooser(sharingIntent, ctx.resources.getString(R.string.social_share_with))
            chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.applicationContext.startActivity(chooserIntent)
            true }
) {
    init {
    }
}

fun getMessage(ctx: Context, timeStamp: Long, dropCount: Int): String {
    var elapsed: Long = System.currentTimeMillis() - timeStamp
    elapsed /= 60000
    if(elapsed < 120) {
        return ctx.resources.getString(R.string.social_share_bodym, dropCount, elapsed)
    }
    elapsed /= 60
    if(elapsed < 48) {
        return ctx.resources.getString(R.string.social_share_bodyh, dropCount, elapsed)
    }
    elapsed /= 24
    if(elapsed < 28) {
        return ctx.resources.getString(R.string.social_share_bodyd, dropCount, elapsed)
    }
    elapsed /= 7
    return ctx.resources.getString(R.string.social_share_bodyw, dropCount, elapsed)
}
