package filter

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.DialogInterface
import android.view.*
import com.github.salomonbrys.kodein.instance
import core.Filters
import core.ktx
import gs.environment.ComponentProvider
import gs.environment.Environment
import gs.environment.Journal
import gs.environment.inject
import gs.presentation.CallbackViewBinder
import gs.presentation.SimpleDialog
import org.blokada.R
import tunnel.Filter
import tunnel.FilterSourceDescriptor

class ExportDash(
        private val xx: Environment
) : CallbackViewBinder {

    override val viewType = 42
    override fun createView(ctx: Context, parent: ViewGroup): View {
        val themedContext = ContextThemeWrapper(ctx, R.style.GsTheme_Dialog)
        return LayoutInflater.from(themedContext).inflate(R.layout.view_export, parent, false)
    }

    override fun attach(view: View) {
        view as FiltersExportView
    }

    override fun detach(view: View) {
        (view.parent as ViewGroup).removeView(view)
        detached()
        detached = {}
        attached = {}
    }

    private var attached: () -> Unit = {}
    private var detached: () -> Unit = {}

    override fun onAttached(attached: () -> Unit) {
        this.attached = attached
    }

    override fun onDetached(detached: () -> Unit) {
        this.detached = detached
    }

}

class AFilterGenerateDialog(
        private val xx: Environment,
        private val ctx: Context = xx().instance(),
        private val s: Filters = xx().instance(),
        private val sourceProvider: DefaultSourceProvider = xx().instance(),
        private val whitelist: Boolean = false
) {

    private val activity by lazy { ctx.inject().instance<ComponentProvider<Activity>>().get() }
    private val j by lazy { ctx.inject().instance<Journal>() }
    private val tunnel by lazy { ctx.inject().instance<tunnel.Main>() }
    private val translations by lazy { ctx.inject().instance<g11n.Main>() }
    private val dialog: AlertDialog
    private var which: Int = 0

    private val dialogExport by lazy {
        val dash = ExportDash(xx)
        SimpleDialog(xx, dash)
    }

    init {
        val d = AlertDialog.Builder(activity)
        d.setTitle(R.string.filter_generate_title)
        val options = if (whitelist) {
            arrayOf(
                    ctx.getString(R.string.filter_generate_refetch),
                    ctx.getString(R.string.filter_generate_defaults),
                    ctx.getString(R.string.filter_generate_export),
                    ctx.getString(R.string.filter_generate_whitelist_system),
                    ctx.getString(R.string.filter_generate_whitelist_system_disabled),
                    ctx.getString(R.string.filter_generate_whitelist_all),
                    ctx.getString(R.string.filter_generate_whitelist_all_disabled)
            )
        } else {
            arrayOf(
                    ctx.getString(R.string.filter_generate_refetch),
                    ctx.getString(R.string.filter_generate_defaults),
                    ctx.getString(R.string.filter_generate_export)
            )
        }
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
        if (dialog.isShowing) return
        try {
            dialog.show()
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener { handleSave() }
            dialog.window.clearFlags(
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM
            )
        } catch (e: Exception) {
            j.log(e)
        }
    }

    private fun handleSave() {
        when (which) {
            0 -> {
                val ktx = ctx.ktx("quickActions:refresh")
                s.apps.refresh(force = true)
                tunnel.invalidateFilters(ktx)
                translations.invalidateCache(ktx)
                translations.sync(ktx)
            }
            1 -> {
                val ktx = ctx.ktx("quickActions:restore")
                s.apps.refresh(force = true)
                tunnel.deleteAllFilters(ktx)
                translations.invalidateCache(ktx)
                translations.sync(ktx)
            }
            2 -> {
                dialogExport.onClosed = { accept ->
                    val ktx = ctx.ktx("quickActions:export:close")
                    tunnel.invalidateFilters(ktx)
                }
                dialogExport.show()
            }
            3, 4, 5, 6 -> {
                val ktx = ctx.ktx("quickActions:generate")
                if (s.apps().isEmpty()) s.apps.refresh(blocking = true)
                val new = s.apps().filter { which in listOf(5, 6) || it.system }
                        .map { it.appId }.map { app ->
                            Filter(
                                    id = id(app, whitelist = true),
                                    source = FilterSourceDescriptor("app", app),
                                    active = which in listOf(3, 5),
                                    whitelist = true
                            )
                        }
                tunnel.putFilters(ktx, new)
                s.changed %= true
            }
        }
        dialog.dismiss()
    }

}

