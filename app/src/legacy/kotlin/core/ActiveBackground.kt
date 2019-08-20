package core

import tunnel.Request

interface ActiveBackground {
    fun setRecentHistory(items: List<Request>)
    fun addToHistory(item: Request)
    fun setTunnelState(state: TunnelState)
    fun setOnClickSwitch(onClick: () -> Unit)
    fun onScroll(fraction: Float, oldPosition: Int, newPosition: Int)
    fun onOpenSection(after: () -> Unit)
    fun onCloseSection()
    fun onPositionChanged(position: Int)
}

