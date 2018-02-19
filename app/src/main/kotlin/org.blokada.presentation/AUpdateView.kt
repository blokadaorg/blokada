package org.blokada.presentation

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.text.Html
import android.text.method.LinkMovementMethod
import android.util.AttributeSet
import android.view.View
import android.widget.ImageView
import android.widget.ScrollView
import android.widget.TextView
import com.github.salomonbrys.kodein.instance
import gs.environment.inject
import gs.property.Version
import org.blokada.R
import java.net.URL


class AUpdateView(
        ctx: Context,
        attributeSet: AttributeSet
) : ScrollView(ctx, attributeSet) {

    var canClick: Boolean = true

    var update: String? = null
        set(value) {
            field = value
            if (value == null) {
                download.visibility = View.GONE
                headerView.text = context.getString(R.string.update_header_noupdate)
                headerView.setTextColor(context.resources.getColor(R.color.colorActive))
                iconView.setColorFilter(context.resources.getColor(R.color.colorActive))
                iconView.setImageResource(R.drawable.ic_info)
            } else {
                download.visibility = View.VISIBLE
                headerView.text = "${context.getString(R.string.update_header)} ${context.getString(R.string.branding_app_name)} ${value    }"
                headerView.setTextColor(context.resources.getColor(R.color.colorAccent))
                iconView.setColorFilter(context.resources.getColor(R.color.colorAccent))
                iconView.setImageResource(R.drawable.ic_new_releases)
            }
        }

    var onClick = {}

    private val currentView by lazy { findViewById(R.id.update_current) as TextView }
    private val creditsView by lazy { findViewById(R.id.update_credits) as TextView }
    private val download by lazy { findViewById(R.id.update_download) as TextView }
    private val headerView by lazy { findViewById(R.id.update_header) as TextView }
    private val iconView by lazy { findViewById(R.id.update_icon) as ImageView }
    private val changelogView by lazy { findViewById(R.id.update_changelog) as View }
    private val makerView by lazy { findViewById(R.id.update_maker) as View }
    private val appInfo by lazy { findViewById(R.id.update_appinfo) as TextView }

    private val ver by lazy { ctx.inject().instance<Version>() }

    override fun onFinishInflate() {
        super.onFinishInflate()
        currentView.text = Html.fromHtml("${ver.appName} ${ver.name}<br/>core: ${ver.nameCore}")

        creditsView.movementMethod = LinkMovementMethod()
        creditsView.text = Html.fromHtml("%s<br/><br/><b>%s</b>".format(
                context.getString(R.string.update_credits_header),
                formatCredits(context.getString(R.string.update_credits))
        ))

        download.setOnClickListener { if (canClick) {
            canClick = false
            onClick()
        }}

        changelogView.setOnClickListener {

        }

        makerView.setOnClickListener {
            val intent = Intent(Intent.ACTION_VIEW)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.setData(Uri.parse(context.getString(R.string.branding_maker_url)))
            context.startActivity(intent)
        }

        appInfo.setOnClickListener {
            context.startActivity(newAppDetailsIntent(context.packageName))
        }
    }

}

fun newAppDetailsIntent(packageName: String): Intent {
    val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
    intent.data = Uri.parse("package:" + packageName)
    return intent
}

private fun formatCredits(credits: String): String {
    return credits.split("\n").map {
        val parts = it.split(" ").map { it.trim() }
        when (parts.size) {
            0 -> null
            1 -> parts[0]
            else -> {
                val url = try { URL(parts[parts.size - 1]) } catch (e: Exception) { null }
                if (url != null) "<a href=\"%s\">%s</a>".format(url.toExternalForm(), parts.map { it.trim(':') }
                        .subList(0, parts.size - 1).joinToString(" "))
                else parts.joinToString(" ")
            }
        }
    }.filterNotNull().joinToString("<br/>")
}
