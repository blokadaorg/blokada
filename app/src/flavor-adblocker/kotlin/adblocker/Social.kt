package adblocker

import android.content.Context
import com.github.salomonbrys.kodein.instance
import core.*
import gs.environment.inject
import org.blokada.R
import android.content.Intent
import java.text.SimpleDateFormat
import java.util.*

val DASH_ID_SHARE_COUNT = "social_share"

class SocialShareCount(
        val ctx: Context,
        val t: Tunnel = ctx.inject().instance()
) : Dash(DASH_ID_SHARE_COUNT,
        R.drawable.ic_share,
        text = ctx.resources.getString(R.string.social_share_count),
        onClick = {
            val sharingIntent = Intent(android.content.Intent.ACTION_SEND)
            sharingIntent.type = "text/plain"
            sharingIntent.putExtra(android.content.Intent.EXTRA_SUBJECT, ctx.resources.getString(R.string.social_share_sub))
            sharingIntent.putExtra(android.content.Intent.EXTRA_TEXT, ctx.resources.getString(R.string.social_share_body, t.tunnelDropCount.toString(), getElapsedTime(ctx, t.tunnelDropStart.invoke())))

            val chooserIntent = Intent.createChooser(sharingIntent, ctx.resources.getString(R.string.social_share_with))
            chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.applicationContext.startActivity(chooserIntent)
            true }
) {
    init {
    }
}

fun getElapsedTime(ctx: Context, timeStamp: Long): String {
    var elapsed: Long = System.currentTimeMillis() - timeStamp
    elapsed /= 60000
    if(elapsed < 120) {
        return elapsed.toString(10) + ' ' + ctx.resources.getStringArray(R.array.social_time_units)[0]
    }
    elapsed /= 60
    if(elapsed < 48) {
        return elapsed.toString(10) + ' ' + ctx.resources.getStringArray(R.array.social_time_units)[1]
    }
    elapsed /= 24
    if(elapsed < 28) {
        return elapsed.toString(10) + ' ' + ctx.resources.getStringArray(R.array.social_time_units)[2]
    }
    elapsed /= 7
    return elapsed.toString(10) + ' ' + ctx.resources.getStringArray(R.array.social_time_units)[3]
}
