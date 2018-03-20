package core

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
        if (ui.editUi()) {
            dash.active = !dash.active
        } else {
            contentActor.reveal(dash,
                    x = v.x.toInt() + v.measuredWidth / 2,
                    y = v.y.toInt() + v.measuredHeight / 2
            )
        }
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
