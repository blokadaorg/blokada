package core

import android.content.Context
import gs.presentation.doAfter
import gs.property.Persistence
import nl.komponents.kovenant.ui.promiseOnUi
import org.blokada.R
import android.util.AttributeSet

/**
 * Dash defines the UI element to be displayed in the home screen as well as the UI that opens
 * up (optionally) once clicked.
 */
open class Dash (
        val id: String,
        icon: Any,
        var description: String? = null,
        active: Boolean = true,
        text: String? = null,
        val isSwitch: Boolean = false,
        checked: Boolean = false,
        val hasView: Boolean = false,
        emphasized: Boolean = false,
        val topBarColor: Int? = null,
        var menuDashes: Triple<Dash?, Dash?, Dash?> = Triple(null, null, null),
        var onClick: ((dashRef: Any) -> Boolean)? = null,
        var onLongClick: ((dashRef: Any) -> Boolean)? = null,
        var onDashOpen: () -> Unit = {},
        var onBack: () -> Unit = {},
        var onUpdate: MutableSet<() -> Unit> = mutableSetOf()
) {
    fun activate(active: Boolean): Dash {
        this.active = active
        return this
    }

    open var active = active
        set(value) {
            field = value
            onUpdate.forEach { it() }
        }

    open var emphasized = emphasized
        set(value) {
            field = value
            onUpdate.forEach { it() }
        }

    open var checked = checked
        set(value) {
            field = value
            onUpdate.forEach { it() }
        }

    var icon = icon
        set(value) {
            field = value
            onUpdate.forEach { it() }
        }

    var text = text
        set(value) {
            field = value
            onUpdate.forEach { it() }
        }

    open fun createView(parent: Any): Any? { return null }
}

enum class InfoType {
    CUSTOM, ERROR, PAUSED, PAUSED_TETHERING, PAUSED_OFFLINE, ACTIVE, ACTIVATING, DEACTIVATING,
    NOTIFICATIONS_ENABLED, NOTIFICATIONS_DISABLED,
    NOTIFICATIONS_KEEPALIVE_ENABLED, NOTIFICATIONS_KEEPALIVE_DISABLED
}

data class Info(val type: InfoType, val param: Any? = null)


class ADashesPersistence(
        val ctx: Context
) : Persistence<List<Dash>> {

    val p by lazy { ctx.getSharedPreferences("State2", Context.MODE_PRIVATE) }

    override fun read(current: List<Dash>): List<Dash> {
        val dashes = ArrayList(current)
        val updateDash = { id: String, active: Boolean ->
            promiseOnUi {
                val dash = dashes.firstOrNull { it.id == id }
                if (dash != null) {
                    dash.active = active
                }
            }
        }
        p.getStringSet("dashes-active", setOf()).forEach { id -> updateDash(id, true)}
        p.getStringSet("dashes-inactive", setOf()).forEach { id -> updateDash(id, false)}
        return dashes
    }

    override fun write(source: List<Dash>) {
        val e = p.edit()
        val active = source.filter(Dash::active).map(Dash::id).toSet()
        val inactive = source.filter { !it.active }.map(Dash::id).toSet()

        // Dashes which were active, but are not loaded yet (we preserve their state to read later)
        val ghosts = p.getStringSet("dashes-active", setOf())

        e.putStringSet("dashes-active", active.plus(ghosts).minus(inactive))
        e.putStringSet("dashes-inactive", inactive)
        e.apply()
    }

}

class ADashActor(
        initialDash: Dash,
        private val v: ADashView,
        private val ui: UiState,
        private val contentActor: ContentActor
) {

    var dash = initialDash
        set(value) {
            field = value
            dash.onUpdate.add { update() }
            update()
        }

    init {
        update()
        v.onChecked = { checked -> dash.checked = checked }
        v.onClick = {
            if (dash.onClick?.invoke(v) ?: true) defaultClick()
        }
        v.onLongClick = {
            if (dash.onLongClick?.invoke(v) ?: true) {
                ui.infoQueue %= ui.infoQueue() + Info(InfoType.CUSTOM, dash.description)
            }
        }

        dash.onUpdate.add { update() }
    }

    private fun defaultClick() {
        contentActor.reveal(dash,
                x = v.x.toInt() + v.measuredWidth / 2,
                y = v.y.toInt() + v.measuredHeight / 2
        )
    }

    private fun update() {
        if (dash.isSwitch) {
            v.checked = dash.checked
        } else {
            if (dash.icon is Int) {
                v.iconRes = dash.icon as Int
            }
        }

        v.text = dash.text
        v.active = dash.active
        v.emphasized = dash.emphasized
    }

}

class ADashView(
        ctx: Context,
        attributeSet: AttributeSet
) : android.widget.LinearLayout(ctx, attributeSet) {

    var iconRes: Int = R.drawable.ic_info
        set(value) {
            setIcon(value, { field = value })
        }

    var checked: Boolean? = null
        set(value) { when {
            value == null -> fromChecked { field = value }
            else -> setChecked(value, {
                val old = field
                field = value
                if (old != value) onChecked(value)
            })
        }}

    var text: String? = null
        set(value) { when (value) {
            field -> Unit
            null -> hideText()
            else -> showText(value)
        }

            field = value
        }

    var active = true
        set(value) { when {
            field == value -> Unit
            value == true -> toActive { field = value }
            else -> fromActive { field = value }
        }}

    var emphasized = true
        set(value) {
            field = value
            if (emphasized) iconView.setColorFilter(context.resources.getColor(R.color.colorAccent))
            else iconView.setColorFilter(context.resources.getColor(R.color.colorActive))
        }

    var onChecked = { active: Boolean -> }
    var onClick = {}
    var onLongClick = {}

    var showClickAnim = true

    private val iconView by lazy { findViewById(R.id.dash_icon) as android.widget.ImageView }
    private val switchView by lazy { findViewById(R.id.dash_switch) as android.support.v7.widget.SwitchCompat }
    private val textView by lazy { findViewById(R.id.dash_text) as android.widget.TextView }
    private val inter = android.view.animation.AccelerateDecelerateInterpolator()
    private val dur = 80L

    override fun onFinishInflate() {
        super.onFinishInflate()
        if (text == null) hideText()

        switchView.setOnClickListener {
            checked = !checked!!
        }
        var canClick = true
        setOnClickListener {
            if (!canClick) // Anim in progress
            else if (showClickAnim) {
                canClick = false
                rotate(-15f, {
                    rotate(30f, {
                        rotate(-15f, {
                            onClick()
                            canClick = true
                        })
                    })
                })
            } else onClick()
        }
        setOnLongClickListener { onLongClick(); true }
    }

    private fun rotate(how: Float, after: () -> Unit) {
        iconView.animate().rotationBy(how).setInterpolator(inter).setDuration(dur).doAfter(after)
    }

    private fun hideText() {
        textView.visibility = android.view.View.GONE
    }

    private fun showText(text: String) {
        textView.visibility = android.view.View.VISIBLE
        textView.text = android.text.Html.fromHtml(text)
    }

    private fun setIcon(iconRes: Int, after: () -> Unit) {
        iconView.visibility = android.view.View.VISIBLE
        switchView.visibility = android.view.View.GONE
        iconView.setImageResource(iconRes)
        after()
    }

    private fun setChecked(checked: Boolean, after: () -> Unit) {
        iconView.visibility = android.view.View.GONE
        switchView.visibility = android.view.View.VISIBLE
        switchView.isChecked = checked
        after()
    }

    private fun fromChecked(after: () -> Unit) {
        iconView.visibility = android.view.View.VISIBLE
        switchView.visibility = android.view.View.GONE
        after()
    }

    private fun toActive(after: () -> Unit) {
        iconView.alpha = 1.0f
        switchView.alpha = 1.0f
        textView.alpha = 1.0f
        switchView.isEnabled = true
        after()
    }

    private fun fromActive(after: () -> Unit) {
        iconView.alpha = 0.2f
        switchView.alpha = 0.2f
        textView.alpha = 0.2f
        switchView.isEnabled = false
        after()
    }
}
