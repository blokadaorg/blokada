package gs.presentation

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import com.github.salomonbrys.kodein.instance
import gs.environment.ComponentProvider
import gs.environment.Environment
import gs.environment.Journal
import gs.environment.inject
import org.blokada.R

class SimpleDialog(
        private val xx: Environment,
        private val dash: CallbackViewBinder,
        private val continueButton: Int = R.string.welcome_continue,
        private val additionalButton: Int? = null,
        private val loadFirst: Boolean = false,
        private val ctx: Context = xx().instance()
) {

    var onClosed = { button: Int? -> }

    private val activity by lazy { ctx.inject().instance<ComponentProvider<Activity>>() }
    private val j by lazy { ctx.inject().instance<Journal>() }
    private var dialog: AlertDialog? = null
    private var view: View? = null

    init {
    }

    fun show() {
        if (dialog != null) return
        try {
            val d = AlertDialog.Builder(activity.get())
            val parent = activity.get()?.findViewById<ViewGroup>(R.id.root)!!
            val view = dash.createView(ctx, parent)
            d.setView(view)
            d.setPositiveButton(continueButton, { dia, int -> })
            if (additionalButton != null) {
                d.setNeutralButton(ctx.getString(additionalButton), { dia, int -> })
            }
            val dialog = d.create()
            d.setView(null)

            dialog.setOnDismissListener {
                onClosed(null)
                hide()
            }

            dialog.window.clearFlags(
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM
            )
            this.dialog = dialog
            this.view = view
            if (loadFirst) {
                dash.onAttached { try {
                    dialog.show()
                    setButtons()
                } catch (e: Exception) {} }
                dash.attach(view)
            } else {
                dialog.show()
                setButtons()
                dash.attach(view)
            }
        } catch (e: Exception) {
            j.log("SimpleDialog: fail", e)
        }
    }

    private fun setButtons() {
        dialog?.getButton(AlertDialog.BUTTON_POSITIVE)?.setOnClickListener {
            onClosed(1)
            hide()
        }

        if (additionalButton != null) {
            dialog?.getButton(AlertDialog.BUTTON_NEUTRAL)?.setOnClickListener {
                onClosed(2)
                hide()
            }
        }

    }

    private fun hide() {
        onClosed = {}
        if (dialog?.isShowing ?: false) dialog?.dismiss()
        if (view != null) dash.detach(view!!)
        dialog?.setView(null)
        dialog = null
        view = null
    }
}

