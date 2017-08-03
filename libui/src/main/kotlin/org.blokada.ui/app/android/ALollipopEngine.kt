package org.blokada.ui.app.android

import android.content.Context
import android.os.Build
import org.blokada.app.android.ATunnelAgent
import org.blokada.lib.ui.R
import org.blokada.app.Engine
import org.blokada.app.EngineEvents
import org.blokada.app.android.lollipop.ALollipopEngineManager

val ENGINE_ID_LOLLIPOP = "lollipop"

class ALollipopEngine(
        private val ctx: Context,
        private val agent: ATunnelAgent
) : Engine(
        id = ENGINE_ID_LOLLIPOP,
        text = ctx.getString(R.string.tunnel_selected_lollipop),
        comment = ctx.getString(R.string.tunnel_selected_lollipop_desc),
        commentUnsupported = ctx.getString(R.string.tunnel_selected_lollipop_desc_unsupported),
        supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP,
        recommended = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP,
        createIEngineManager = { e: EngineEvents ->
                ALollipopEngineManager(
                        ctx = ctx,
                        adBlocked = e.adBlocked,
                        error = e.error,
                        onRevoked = e.onRevoked,
                        agent = agent
                )
        }
)
