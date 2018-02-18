package org.blokada.presentation

import android.content.Context
import android.support.v7.widget.RecyclerView
import android.view.ContextThemeWrapper
import android.view.LayoutInflater
import android.view.ViewGroup
import com.github.salomonbrys.kodein.instance
import org.blokada.main.Events
import gs.environment.Journal
import org.blokada.R
import org.blokada.property.State
import org.obsolete.di

class AEngineAdapter(
        private val ctx: Context
) : RecyclerView.Adapter<AFilterViewHolder>() {

    private val themedContext by lazy { ContextThemeWrapper(ctx, R.style.Switch) }
    private val a by lazy { ctx.di().instance<Journal>() }
    private val s by lazy { ctx.di().instance<State>() }

    private var listener: Any? = null
    init {
        // TODO: remove listener
        listener = s.tunnelEngines.doOnUiWhenChanged(withInit = true).then { notifyDataSetChanged() }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): AFilterViewHolder {
        val v = LayoutInflater.from(themedContext).inflate(R.layout.view_filter, parent, false)
                as AFilterView

        // Initial config of the view
        v.multiple = true
        v.showDelete = false

        v.setOnClickListener { v ->
            val i = v.tag as Int

            s.tunnelActiveEngine %= s.tunnelEngines()[i].id
            notifyDataSetChanged()

            val name = s.tunnelEngines().getOrNull(i)?.javaClass?.simpleName ?: "(unknown)"
            a.event(Events.Companion.CLICK_ENGINE(name))
        }

        return AFilterViewHolder(v)
    }

    override fun onBindViewHolder(holder: AFilterViewHolder, pos: Int) {
        val v = holder.view
        val e = s.tunnelEngines()[pos]

        v.tag = pos
        v.tapped = s.tunnelActiveEngine() == s.tunnelEngines()[pos].id
//        v.name = e.text

        if (e.supported) {
            v.alpha = 1.0f
            v.isEnabled = true
            v.recommended = e.recommended
//            v.description = e.comment
        } else {
            v.alpha = 0.2f
            v.isEnabled = false
            v.recommended = false
//            v.description = e.commentUnsupported
        }
    }

    override fun getItemCount(): Int {
        return s.tunnelEngines().size
    }
}

data class AFilterViewHolder(val view: AFilterView): RecyclerView.ViewHolder(view)
