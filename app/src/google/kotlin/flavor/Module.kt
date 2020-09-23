package flavor

import android.content.Context
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.instance
import core.Tunnel
import core.updateControllswitchWidgets

fun newFlavorModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        onReady {
            val s: Tunnel = instance()

            s.tunnelState.doWhenChanged().then{
                updateControllswitchWidgets(ctx)
            }
            updateControllswitchWidgets(ctx)
        }
    }
}

