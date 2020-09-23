package buildtype

import android.app.Application
import android.content.Context
import android.text.format.DateUtils
import android.util.Log
import com.github.salomonbrys.kodein.*
import core.Tunnel
import gs.environment.*
import gs.property.BasicPersistence
import gs.property.Device
import gs.property.IProperty
import gs.property.newPersistedProperty
import org.blokada.R

fun newBuildTypeModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<Journal>(overrides = true) with singleton {
            ALogcatJournal("gscore")
        }
        bind<Events>() with singleton {
            EventsImpl(kctx = with("gscore").instance(), xx = lazy)
        }
        onReady {
            val e: Events = instance()
            val d: Device = instance()

            // I assume this will happen at least once a day
            d.screenOn.doWhenChanged().then {
                if (d.reports()) {
                    e.lastDailyMillis.refresh()
                    e.lastActiveMillis.refresh()
                }
            }

            // This will happen when loading the app to memory
            if (d.reports()) {
                e.lastDailyMillis.refresh()
                e.lastActiveMillis.refresh()
            }
        }
    }
}

abstract class Events {
    abstract val lastDailyMillis: IProperty<Long>
    abstract val lastActiveMillis: IProperty<Long>
}

class EventsImpl(
        private val kctx: Worker,
        private val xx: Environment,
        private val time: Time = xx().instance(),
        private val j: Journal = xx().instance(),
        private val t: Tunnel = xx().instance()
) : Events() {
    override val lastDailyMillis = newPersistedProperty(kctx, BasicPersistence(xx, "daily"), { 0L },
            refresh = {
                j.event("daily")
                time.now()
            },
            shouldRefresh = { !DateUtils.isToday(it) })

    override val lastActiveMillis = newPersistedProperty(kctx, BasicPersistence(xx, "daily-active"), { 0L },
            refresh = {
                if (t.active()) {
                    j.event("daily-active")
                    time.now()
                } else it
            },
            shouldRefresh = { !DateUtils.isToday(it) })
}

