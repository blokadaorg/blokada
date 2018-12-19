package core

import android.view.ViewGroup
import jp.wasabeef.blurry.Blurry

class ModalManager {

    private var blurOpen = false

    fun openModal() {
        activityRegister.getParentView()?.apply {
            if (this is ViewGroup) {
                Blurry.with(context).animate(500).onto(this)
                blurOpen = true
            }
        }
    }

    fun closeModal() {
        if (blurOpen)
            activityRegister.getParentView()?.apply {
                if (this is ViewGroup) {
                    val last = childCount - 1
                    removeViewAt(last)
                    blurOpen = false
                }
            }
    }
}
