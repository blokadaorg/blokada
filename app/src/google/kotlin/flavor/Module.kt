package flavor

import android.content.Context
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.instance
import core.Tunnel

fun newFlavorModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        onReady {
            val s: Tunnel = instance()

            // Initialize default values for properties that need it (async)
            s.tunnelDropCount {}
        }
    }
}

