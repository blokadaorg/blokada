package update

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.text.Html
import android.util.AttributeSet
import android.view.View
import android.widget.ImageView
import android.widget.ScrollView
import android.widget.TextView
import com.github.salomonbrys.kodein.LazyKodein
import com.github.salomonbrys.kodein.instance
import core.Pages
import gs.environment.inject
import gs.property.Version
import org.blokada.R


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
                appInfo.visibility = View.VISIBLE
                headerView.text = context.getString(R.string.update_header_noupdate)
                headerView.setTextColor(context.resources.getColor(R.color.colorActive))
                iconView.setColorFilter(context.resources.getColor(R.color.colorActive))
                iconView.setImageResource(R.drawable.ic_info)
            } else {
                download.visibility = View.VISIBLE
                appInfo.visibility = View.GONE
                headerView.text = "${context.getString(R.string.update_header)} ${context.getString(R.string.branding_app_name)} ${value}"
                headerView.setTextColor(context.resources.getColor(R.color.colorAccent))
                iconView.setColorFilter(context.resources.getColor(R.color.colorAccent))
                iconView.setImageResource(R.drawable.ic_new_releases)
            }
        }

    var onClick = {}
    var onClickBackup = {}

    private val currentView by lazy { findViewById(R.id.update_current) as TextView }
    private val download by lazy { findViewById(R.id.update_download) as TextView }
    private val headerView by lazy { findViewById(R.id.update_header) as TextView }
    private val iconView by lazy { findViewById(R.id.update_icon) as ImageView }
    private val makerView by lazy { findViewById(R.id.update_maker) as View }
    private val appInfo by lazy { findViewById(R.id.update_appinfo) as TextView }

    private val ver by lazy { ctx.inject().instance<Version>() }
    private val pages by lazy { ctx.inject().instance<Pages>() }

    private val xx = LazyKodein(ctx.inject)

    override fun onFinishInflate() {
        super.onFinishInflate()
        currentView.text = Html.fromHtml("${ver.appName} ${ver.name}")

        download.setOnClickListener { if (canClick) {
            canClick = false
            onClick()
        } else {
            canClick = true
            onClickBackup()
        }}

        makerView.setOnClickListener {
            val intent = Intent(Intent.ACTION_VIEW)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.setData(Uri.parse(context.getString(R.string.branding_maker_url)))
            context.startActivity(intent)
        }
        makerView.setOnLongClickListener {
            throw Exception("Are we 1984?")
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

