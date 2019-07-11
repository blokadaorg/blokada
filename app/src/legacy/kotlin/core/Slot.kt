package core

import android.content.Context
import android.graphics.drawable.Drawable
import android.os.Handler
import android.text.Editable
import android.text.Html
import android.text.TextWatcher
import android.text.format.DateUtils
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import android.widget.*
import com.github.salomonbrys.kodein.instance
import com.ramotion.foldingcell.FoldingCell
import gs.presentation.LayoutViewBinder
import gs.presentation.doAfter
import gs.property.I18n
import org.blokada.R
import tunnel.showSnack
import java.util.*

class Slot {
    enum class Type {
        INFO, FORWARD, BLOCK, COUNTER, STATUS, NEW, EDIT, APP, PROTECTION, PROTECTION_OFF, ACCOUNT
    }

    data class Action(val name: String, val callback: () -> Unit)

    data class Content(
            val label: String,
            val header: String = label,
            val description: String? = null,
            val info: String? = null,
            val detail: String? = null,
            val icon: Drawable? = null,
            val action1: Action? = null,
            val action2: Action? = null,
            val action3: Action? = null,
            val switched: Boolean? = null,
            val values: List<String> = emptyList(),
            val selected: String? = null,
            val unread: Boolean = false,
            val color: Int? = null
    )
}

internal val defaultOnTap = { view: SlotView ->
    if (view.isUnfolded()) view.fold()
    else view.unfold()
}

abstract class SlotVB(internal var onTap: (SlotView) -> Unit = defaultOnTap)
    : LayoutViewBinder(R.layout.slotview), Stepable, Navigable {

    abstract fun attach(view: SlotView)
    open fun detach(view: SlotView) = Unit

    protected var view: SlotView? = null

    override fun attach(view: View) {
        view as SlotView
        this.view = view
        view.onTap = { onTap(view) }
        attach(view)
    }

    override fun detach(view: View) {
        view as SlotView
        view.unbind()
        this.view = null
        detach(view)
    }

    override fun focus() {
        view?.unfold()
        view?.requestFocusOnEdit()
    }

    override fun enter() {
        view?.onTap?.invoke()
    }

    override fun exit() {
        view?.fold()
    }

    override fun up() = Unit

    override fun down() = scheduleAction(2)

    override fun left() = scheduleAction(3)

    override fun right() = scheduleAction(1)

    private val ACTION_DELAY_MS = 900L
    private val actionPerformHandler = Handler {
        (it.obj as? SlotView)?.performAction(it.what)
        true
    }

    private fun scheduleAction(action: Int) {
        val msg = actionPerformHandler.obtainMessage()
        msg.obj = view
        msg.what = action
        actionPerformHandler.sendMessageDelayed(msg, ACTION_DELAY_MS)
    }
}

class SlotView(
        ctx: Context,
        attributeSet: AttributeSet
) : FrameLayout(ctx, attributeSet) {

    init {
        inflate(context, R.layout.slotview_content, this)
    }

    private val i18n by lazy { context.ktx("SlotView").di().instance<I18n>() }

    private val foldingView = getChildAt(0) as FoldingCell
    private val foldedContainerView = findViewById<ViewGroup>(R.id.folded)
    private val unfoldedContainerView = findViewById<ViewGroup>(R.id.unfolded)
    private val unfoldedContentView = findViewById<ViewGroup>(R.id.unfolded_content)
    private val unreadView = findViewById<ImageView>(R.id.folded_unread)
    private val textView = findViewById<TextView>(R.id.folded_text)
    private val iconView = findViewById<ImageView>(R.id.folded_icon)
    private val timeView = findViewById<TextView>(R.id.folded_time)
    private val headerView = findViewById<TextView>(R.id.unfolded_header)
    private val descriptionView = findViewById<TextView>(R.id.unfolded_description)
    private val editView = findViewById<EditText>(R.id.unfolded_edit)
    private val detailView = findViewById<TextView>(R.id.unfolded_detail)
    private val infoIconView = findViewById<ImageView>(R.id.unfolded_info_icon)
    private val infoTextView = findViewById<TextView>(R.id.unfolded_info_text)
    private val switchFoldedView = findViewById<TextView>(R.id.folded_switch)
    private val switchUnfoldedView = findViewById<TextView>(R.id.unfolded_switch)
    private val action0View = findViewById<Button>(R.id.unfolded_action0)
    private val action1View = findViewById<Button>(R.id.unfolded_action1)
    private val action2View = findViewById<Button>(R.id.unfolded_action2)
    private val action3View = findViewById<Button>(R.id.unfolded_action3)
    private val buttonSeparatorView = findViewById<View>(R.id.folded_button_separator)
    private val switchViews = listOf(switchFoldedView, switchUnfoldedView)

    init {
        setOnClickListener { onTap() }
        action0View.setOnClickListener { onTap() }
        switchViews.forEach { it.setOnClickListener { action1View.callOnClick() } }
        infoTextView.setOnClickListener {
            isEnabled = false
            unfoldedContentView.visibility = View.VISIBLE
            unfoldedContentView.alpha = 0f
            unfoldedContentView.animate().alpha(1f).setDuration(500)
            infoTextView.animate().alpha(0f).setDuration(500).doAfter {
                infoTextView.visibility = View.GONE
                isEnabled = true
            }
        }
        infoIconView.setOnClickListener {
            isEnabled = false
            unfoldedContentView.animate().alpha(0f).setDuration(500).doAfter {
                unfoldedContentView.visibility = View.INVISIBLE
                isEnabled = true
            }
            infoTextView.visibility = View.VISIBLE
            infoTextView.alpha = 0f
            infoTextView.animate().alpha(1f).setDuration(500)
        }
        editView.addTextChangedListener(object : TextWatcher {
            override fun afterTextChanged(s: Editable) {
                val error = onInput(s.toString())
                if (error != null) {
                    descriptionView.apply {
                        visibility = View.VISIBLE
                        text = error
                        setTextColor(resources.getColor(R.color.colorAccentDark))
                    }
                    switchViews.forEach {
                        it.visibility = View.VISIBLE
                        it.setText(R.string.slot_invalid)
                        it.setTextColor(resources.getColor(R.color.colorAccentDark))
                    }
                } else {
                    descriptionView.apply {
                        visibility = View.GONE
                    }
                    switchViews.forEach {
                        it.visibility = View.VISIBLE
                        it.setText(R.string.slot_set)
                        it.setTextColor(resources.getColor(R.color.switch_on))
                    }
                }
            }

            override fun beforeTextChanged(s: CharSequence, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence, start: Int, before: Int, count: Int) = Unit
        })
    }

    val ACTION_NONE = {
        showSnack(R.string.slot_action_none)
    }

    val ACTION_CLOSE = Slot.Action(i18n.getString(R.string.slot_action_close), {
        onTap()
    })

    val ACTION_REMOVE = Slot.Action(i18n.getString(R.string.slot_action_remove), {
        onRemove()
    })

    var type: Slot.Type? = null
        set(value) {
            field = value
            value?.apply { bind(this) }
        }

    var content: Slot.Content? = null
        set(value) {
            field = value
            value?.apply { bind(this) }
            foldingView.fold(true)
            timeRefreshHandler.sendEmptyMessage(0)
        }

    var date: Date? = null
        set(value) {
            field = value
            content?.apply { bind(this) }
            timeRefreshHandler.sendEmptyMessage(0)
        }

    var input: String = ""
        set(value) {
            field = value
            editView.setText(value, TextView.BufferType.EDITABLE)
        }

    var onTap = {}
        set(value) {
            field = value
            setOnClickListener { value() }
        }

    var onClose = {}
    var onSwitch = { _: Boolean -> }
    var onSelect = { _: String -> }
    var onInput: (String) -> String? = { _: String -> null }
    var onRead = {}
    var onRemove = {}

    fun fold(skipAnimation: Boolean = false) = foldingView.fold(skipAnimation)

    fun unfold() {
        if (content?.unread ?: false) {
            content = content?.copy(unread = false)
            onRead()
        }
        foldingView.unfold(false)
    }

    fun isUnfolded() = foldingView.isUnfolded

    fun enableAlternativeBackground() {
        foldingView.initialize(500, resources.getColor(R.color.colorBackgroundLight), 0)
        foldedContainerView.setBackgroundResource(R.drawable.bg_dashboard_item_alternative)
        unfoldedContainerView.setBackgroundResource(R.drawable.bg_dashboard_item_unfolded_alternative)
    }

    fun requestFocusOnEdit() {
        editView.requestFocus()
    }

    private fun bind(content: Slot.Content) {
        textView.text = Html.fromHtml(content.label)
        buttonSeparatorView.visibility = View.GONE
        when {
            date != null -> switchViews.forEach { it.visibility = View.GONE }
            content.values.isNotEmpty() && content.selected in content.values -> switchViews.forEach {
                it.visibility = View.VISIBLE
                it.text = content.selected
                it.setTextColor(resources.getColor(
                        when (content.selected) {
                            i18n.getString(R.string.slot_allapp_whitelisted) -> R.color.switch_on
                            i18n.getString(R.string.slot_allapp_normal) -> R.color.switch_off
                            else -> R.color.colorAccent
                        }
                ))
                buttonSeparatorView.visibility = View.VISIBLE
            }
            type == Slot.Type.EDIT && content.switched == null -> switchViews.forEach {
                it.visibility = View.VISIBLE
                it.text = i18n.getString(R.string.slot_unset)
                it.setTextColor(resources.getColor(R.color.switch_off))
            }
            content.switched == true -> switchViews.forEach {
                it.visibility = View.VISIBLE
                it.setText(R.string.slot_switch_on)
                it.setTextColor(resources.getColor(R.color.switch_on))
                buttonSeparatorView.visibility = View.VISIBLE
            }
            content.switched == false -> switchViews.forEach {
                it.visibility = View.VISIBLE
                it.setText(R.string.slot_switch_off)
                it.setTextColor(resources.getColor(R.color.switch_off))
                buttonSeparatorView.visibility = View.VISIBLE
            }
            content.action1 != null -> {
                // Show the first action's name (or unicode icon) in top right
                switchUnfoldedView.visibility = View.INVISIBLE
                switchFoldedView.visibility = View.VISIBLE
                switchFoldedView.text = actionNameToIcon(content.action1.name)
                switchFoldedView.setTextColor(resources.getColor(R.color.colorAccent))
                buttonSeparatorView.visibility = View.VISIBLE
            }
            content.switched == null -> switchViews.forEach { it.visibility = View.GONE }
        }

        headerView.text = Html.fromHtml(content.header)

        if (content.description != null) descriptionView.text = Html.fromHtml(content.description)
        else descriptionView.text = i18n.getString(R.string.slot_list_no_desc)

        if (content.detail != null) {
            detailView.visibility = View.VISIBLE
            detailView.text = content.detail
        } else detailView.visibility = View.GONE

        if (content.icon != null) {
            iconView.setImageDrawable(content.icon)
        }

        unreadView.visibility = if (content.unread) View.VISIBLE else View.INVISIBLE

        if (content.info != null) {
            infoTextView.visibility = View.GONE
            infoIconView.visibility = View.VISIBLE
            infoTextView.text = content.info
        } else {
            infoTextView.visibility = View.GONE
            infoIconView.visibility = View.GONE
        }

        bind(content.action1, content.action2, content.action3)
    }

    private fun bind(type: Slot.Type) {
        iconView.setColorFilter(resources.getColor(R.color.colorActive))
        editView.visibility = View.GONE
        when (type) {
            Slot.Type.INFO -> {
                iconView.setImageResource(R.drawable.ic_info)
            }
            Slot.Type.FORWARD -> {
                iconView.setImageResource(R.drawable.ic_arrow_right_circle)
            }
            Slot.Type.BLOCK -> {
                iconView.setImageResource(R.drawable.ic_block)
                iconView.setColorFilter(resources.getColor(R.color.colorAccent))
            }
            Slot.Type.COUNTER -> {
                iconView.setImageResource(R.drawable.ic_counter)
            }
            Slot.Type.NEW -> {
                iconView.setImageResource(R.drawable.ic_filter_add)
                iconView.setColorFilter(resources.getColor(R.color.colorAccent))
            }
            Slot.Type.EDIT -> {
                iconView.setImageResource(R.drawable.ic_edit)
                editView.visibility = View.VISIBLE
            }
            Slot.Type.APP -> {
                iconView.setColorFilter(resources.getColor(android.R.color.transparent))
                iconView.setImageResource(R.drawable.ic_hexagon)
            }
            Slot.Type.PROTECTION -> {
                val color = content!!.color!!
                iconView.setColorFilter(color)
                textView.setTextColor(color)
                switchViews.forEach { it.setTextColor(resources.getColor(R.color.colorProtectionLow)) }
            }
            Slot.Type.PROTECTION_OFF -> {
                val color = content!!.color!!
                iconView.setColorFilter(color)
                textView.setTextColor(color)
                switchViews.forEach { it.setTextColor(resources.getColor(R.color.colorProtectionHigh)) }
            }
            Slot.Type.ACCOUNT -> {
                content?.color?.run {
                    iconView.setColorFilter(this)
                    textView.setTextColor(this)
                }
                iconView.setImageResource(R.drawable.ic_account_circle_black_24dp)
            }
        }
    }

    private fun bind(action1: Slot.Action?, action2: Slot.Action?, action3: Slot.Action?) {
        listOf(action0View, action1View, action2View, action3View).forEach {
            it.visibility = View.GONE
        }

        when {
            action1 == null && (content?.values?.size ?: 0) > 1 -> {
                // Set action that rolls through possible values
                val c = content!!
                val nextValueIndex = (c.values.indexOf(c.selected) + 1) % c.values.size
                val nextValue = c.values[nextValueIndex]
                bind(Slot.Action(nextValue, {
                    content = c.copy(selected = nextValue)
                    onSelect(nextValue)
                }), action1View)
                bind(action2, action2View)
                bind(action3, action3View)
            }
            action1 == null && content?.switched != null -> {
                // Set action that switches between two boolean values
                val c = content!!
                val nextValue = !(c.switched!!)
                val nextValueName = i18n.getString(if (nextValue) R.string.slot_switch_on
                        else R.string.slot_switch_off)
                bind(Slot.Action(nextValueName, {
                    content = c.copy(switched = nextValue)
                    onSwitch(nextValue)
                }), action1View)
                bind(action2, action2View)
                bind(action3, action3View)
            }
            action1 == null -> {
                // Show the default "close" action
                action0View.visibility = View.VISIBLE
            }
            else -> {
                listOf(
                        action1 to action1View,
                        action2 to action2View,
                        action3 to action3View
                ).forEach { bind(it.first, it.second) }
            }
        }
    }

    private fun bind(action: Slot.Action?, view: TextView) {
        if (action != null) {
            view.visibility = View.VISIBLE
            view.text = action.name
            view.setOnClickListener { action.callback() }
        } else view.visibility = View.GONE
    }

    fun unbind() = timeRefreshHandler.removeMessages(0)

    fun performAction(index: Int) {
        val action = when (index) {
            1 -> content?.action1
            2 -> content?.action2
            3 -> content?.action3
            else -> null
        }

        if (action != null) action.callback.invoke()
        else if (index == 1) action1View.callOnClick()
    }

    private val timeRefreshHandler = Handler {
        if (date != null) {
            timeView.visibility = View.VISIBLE
            timeView.text = DateUtils.getRelativeTimeSpanString(date?.time!!, Date().time,
                    DateUtils.MINUTE_IN_MILLIS, DateUtils.FORMAT_ABBREV_RELATIVE)
            scheduleTimeRefresh()
        } else
            timeView.visibility = View.GONE
        true
    }

    private fun scheduleTimeRefresh() {
        timeRefreshHandler.sendEmptyMessageDelayed(0, 60 * 1000)
    }

    private fun actionNameToIcon(name: String) = when (name) {
        i18n.getString(R.string.slot_action_remove) -> "x"
        else -> name
    }
}

class LabelView(
        ctx: Context,
        attributeSet: AttributeSet
) : FrameLayout(ctx, attributeSet) {

    init {
        inflate(context, R.layout.labelview_content, this)
    }

    private val i18n by lazy { context.ktx("LabelView").di().instance<I18n>() }

    private val labelView = findViewById<TextView>(R.id.label)

    var label: String = ""
        set(value) {
            field = value
            labelView.text = label
        }

    var labelResId: Int = 0
        set(value) {
            field = value
            labelView.text = i18n.getString(value)
        }
}

class LabelVB(
        val ktx: AndroidKontext,
        val i18n: I18n = ktx.di().instance(),
        val label: Resource
) : LayoutViewBinder(R.layout.labelview) {

    override fun attach(view: View) {
        view as LabelView
        view.label = i18n.getString(label)
    }

}
