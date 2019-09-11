package tunnel

import com.google.android.material.snackbar.Snackbar
import core.Resource
import core.activityRegister
import kotlinx.coroutines.experimental.android.UI
import kotlinx.coroutines.experimental.async
import org.blokada.R

fun showSnack(resource: Resource) = async(UI) {
    activityRegister.getParentView()?.run {
        if (resource.hasResId()) showSnack(resource.getResId())
        else {
            val snack = Snackbar.make(this, resource.getString(), 5000)
            snack.view.setBackgroundResource(R.drawable.snackbar)
            snack.view.setPadding(32, 32, 32, 32)
            snack.setAction(R.string.menu_ok, { snack.dismiss() })
            snack.show()
        }
    }
}

fun showSnack(msgResId: Int) = async(UI) {
    activityRegister.getParentView()?.run {
        val snack = Snackbar.make(this, msgResId, 5000)
        snack.view.setBackgroundResource(R.drawable.snackbar)
        snack.view.setPadding(32, 32, 32, 32)
        snack.setAction(R.string.menu_ok, { snack.dismiss() })
        snack.show()
    }
}
