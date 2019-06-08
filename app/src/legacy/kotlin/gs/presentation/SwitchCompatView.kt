package gs.presentation

class SwitchCompatView(
        private val ctx: android.content.Context,
        attributeSet: android.util.AttributeSet?
) : androidx.appcompat.widget.SwitchCompat(ctx, attributeSet) {

    private var isInSetChecked = false

    override fun setChecked(checked: Boolean) {
        isInSetChecked = true
        super.setChecked(checked)
        isInSetChecked = false
    }

    override fun isShown(): Boolean {
        if (isInSetChecked) {
            return visibility == android.view.View.VISIBLE
        }
        return super.isShown()
    }
}
