package org.blokada.presentation

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.DialogInterface
import android.view.WindowManager
import com.github.salomonbrys.kodein.instance
import org.blokada.property.Filter
import org.blokada.property.IFilterSource
import org.blokada.property.LocalisedFilter
import org.blokada.property.State
import gs.environment.ActivityProvider
import org.obsolete.di
import org.blokada.R

class AFilterGenerateDialog(
        private val ctx: Context,
        private val s: State,
        private val sourceProvider: (String) -> IFilterSource,
        private val whitelist: Boolean
) {

    private val activity by lazy { ctx.di().instance<ActivityProvider<Activity>>().get() }
    private val dialog: AlertDialog
    private var which: Int = 0

    init {
        val d = AlertDialog.Builder(activity)
        d.setTitle(R.string.filter_generate_title)
        val options = if (whitelist) { arrayOf(
                ctx.getString(R.string.filter_generate_defaults),
                ctx.getString(R.string.filter_generate_refetch),
                ctx.getString(R.string.filter_generate_whitelist_system),
                ctx.getString(R.string.filter_generate_whitelist_system_disabled),
                ctx.getString(R.string.filter_generate_whitelist_all),
                ctx.getString(R.string.filter_generate_whitelist_all_disabled)
        ) } else { arrayOf(
                ctx.getString(R.string.filter_generate_defaults),
                ctx.getString(R.string.filter_generate_refetch)
        ) }
        d.setSingleChoiceItems(options, which, object : DialogInterface.OnClickListener {
            override fun onClick(dialog: DialogInterface?, which: Int) {
                this@AFilterGenerateDialog.which = which
            }
        })
        d.setPositiveButton(R.string.filter_edit_do, { dia, int -> })
        d.setNegativeButton(R.string.filter_edit_cancel, { dia, int -> })
        dialog = d.create()
    }

    fun show() {
        dialog.show()
        dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener { handleSave() }
        dialog.window.clearFlags(
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM
        )
    }

    private fun handleSave() {
        if (s.apps().isEmpty()) s.apps.refresh(blocking = true)
        when (which) {
            0 -> {
                s.filters %= emptyList()
                s.filters.refresh()
            }
            1 -> {
                s.filters.refresh(force = true)
            }
            2, 3, 4, 5 -> {
                val filters = s.apps().filter { which in listOf(3, 4) || it.system }
                        .map { it.appId }.map { app ->
                    val source = sourceProvider("app")
                    if (source.fromUserInput(app)) {
                        Filter(
                                id = app,
                                source = source,
                                valid = true,
                                active = which in listOf(1, 3),
                                whitelist = true,
                                localised = LocalisedFilter(sourceToName(ctx, source))
                        )
                    } else null
                }.filterNotNull()

                // TODO: preserve user comments
                s.filters %= s.filters().minus(filters).plus(filters) // To re-add equal instances
            }
        }
        dialog.dismiss()
    }

}

