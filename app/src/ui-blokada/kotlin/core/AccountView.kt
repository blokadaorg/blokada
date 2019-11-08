package core

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import com.github.salomonbrys.kodein.instance
import gs.presentation.LayoutViewBinder
import gs.property.I18n
import org.blokada.R

class AccountView(
        ctx: Context,
        attributeSet: AttributeSet
) : FrameLayout(ctx, attributeSet) {

    init {
        inflate(context, R.layout.accountview_content, this)
    }

    private val i18n by lazy { context.ktx("AccountView").di().instance<I18n>() }

    private val containerView = findViewById<ViewGroup>(R.id.account_container)
    private val iconView = findViewById<ImageView>(R.id.account_icon)
    private val headerView = findViewById<TextView>(R.id.account_header)
    private val idView = findViewById<TextView>(R.id.account_id)
    private val expiredView = findViewById<TextView>(R.id.account_active)

    fun icon(icon: Resource) {
        when {
            icon.hasResId() -> {
                iconView.setImageResource(icon.getResId())
            }
            else -> {
                iconView.setImageDrawable(icon.getDrawable())
            }
        }
    }

    fun id(label: Resource) {
        when {
            label.hasResId() -> {
                idView.text = i18n.getString(label.getResId())
            }
            else -> {
                idView.text = label.getString()
            }
        }
    }

    fun expired(label: Resource, color: Resource = Resource.ofResId(R.color.switch_on)) {
        when {
            label.hasResId() -> {
                expiredView.text = i18n.getString(label.getResId())
            }
            else -> {
                expiredView.text = label.getString()
            }
        }

        when {
            color.hasResId() -> expiredView.setTextColor(resources.getColor(color.getResId()))
            else -> expiredView.setTextColor(color.getColor())
        }
    }

    fun onTap(tap: () -> Any) {
        setOnClickListener { tap() }
    }
}

abstract class AccountVB
    : LayoutViewBinder(R.layout.accountview), Stepable, Navigable {

    abstract fun attach(view: AccountView)
    open fun detach(view: AccountView) = Unit

    protected var view: AccountView? = null

    override fun attach(view: View) {
        view as AccountView
        this.view = view
        attach(view)
    }

    override fun detach(view: View) {
        view as AccountView
        this.view = null
        detach(view)
    }

    override fun enter() {
        view?.performClick()
    }

    override fun focus() {
    }

    override fun exit() = Unit
    override fun up() = Unit
    override fun down() = Unit
    override fun left() = Unit
    override fun right() = Unit

}

