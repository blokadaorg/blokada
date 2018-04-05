package flavor

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import com.github.salomonbrys.kodein.*
import core.*
import filter.DashFilterWhitelist
import filter.FilterSourceApp
import gs.environment.Journal
import gs.environment.Worker
import gs.property.IWhen
import nl.komponents.kovenant.any
import nl.komponents.kovenant.task
import nl.komponents.kovenant.then
import notification.NotificationDashKeepAlive
import notification.createNotificationKeepAlive
import org.blokada.R
import tunnel.ATunnelAgent
import tunnel.ATunnelBinder
import tunnel.ATunnelService
import tunnel.ITunnelEvents
import update.AboutDash
import update.UpdateDash

fun newFlavorModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<IEngineManager>() with singleton {
            object : IEngineManager {
                var binder: ATunnelBinder? = null
                val j: Journal by lazy { instance<Journal>() }
                val agent: ATunnelAgent by lazy { ATunnelAgent(ctx)}
                val waitKctx: Worker by lazy { with("ienginemanager").instance<Worker>() }
                override fun start() {
                    val binding = agent.bind(object : ITunnelEvents {
                        override fun configure(builder: VpnService.Builder): Long { return 0L }
                        override fun revoked() {}
                    }).then {
                        binder = it
                        binder!!.actions.turnOn()
                    }
                    val wait = task(waitKctx) {
                        Thread.sleep(3000)
                    }
                    any(listOf(binding, wait)).get()
                    if (!binding.isSuccess()) {
                        j.log(binding.getError())
                        throw Exception("could not bind to lollipop agent")
                    }
                }
                override fun updateFilters() {}
                override fun stop() {
                    binder?.actions?.turnOff()
                    agent.unbind()
                    Thread.sleep(2000)
                }
            }
        }
        bind<List<Engine>>() with singleton {
            listOf(Engine(
                id = "dummy",
                createIEngineManager = { object: IEngineManager {
                    override fun start() {}
                    override fun updateFilters() {}
                    override fun stop() {}
                } }
        )) }
        bind<ATunnelService.IBuilderConfigurator>() with singleton {
            val dns: Dns = instance()
            val s: Filters = instance()
            object : ATunnelService.IBuilderConfigurator {
                override fun configure(builder: VpnService.Builder) {
                    val choice = dns.choices().firstOrNull { it.active }
                    if (choice != null) {
                        choice.servers.forEach { builder.addDnsServer(it) }
                    }
                    builder.setSession(ctx.getString(R.string.branding_app_name))
                            .setConfigureIntent(PendingIntent.getActivity(ctx, 1,
                                    Intent(ctx, MainActivity::class.java),
                                    PendingIntent.FLAG_CANCEL_CURRENT))

                    // Those are TEST-NET IP ranges from RFC5735, so that we don't collide.
                    var found = false
                    for (prefix in arrayOf("203.0.113", "198.51.100", "192.0.2")) {
                        try {
                            builder.addAddress(prefix + ".1", 24)
                            found = true
                            break
                        } catch (e: IllegalArgumentException) { }
                    }

                    if (!found) {
                        // If no subnet worked, just go with something safe.
                        builder.addAddress("192.168.50.1", 24)
                    }

                    s.filters().filter { it.whitelist && it.active && it.source is FilterSourceApp }.forEach {
                        builder.addDisallowedApplication(it.source.toUserInput())
                    }

                    // People kept asking why GPlay doesnt work
                    try { builder.addDisallowedApplication("com.android.vending") } catch (e: Exception) {}
                }
            }
        }
        bind<List<Dash>>() with singleton { listOf(
                UpdateDash(ctx).activate(true),
                DashDns(lazy).activate(true),
                DashFilterWhitelist(ctx).activate(true),
                NotificationDashKeepAlive(ctx).activate(true),
                AutoStartDash(ctx).activate(true),
                ConnectivityDash(ctx).activate(true),
                PatronDash(lazy).activate(false),
                PatronAboutDash(lazy).activate(false),
                DonateDash(lazy).activate(false),
                NewsDash(lazy).activate(false),
                FeedbackDash(lazy).activate(false),
                FaqDash(lazy).activate(false),
                ChangelogDash(lazy).activate(false),
                AboutDash(ctx).activate(false),
                CreditsDash(lazy).activate(false),
                CtaDash(lazy).activate(false),
                ShareLogDash(lazy).activate(false)
        ) }
        onReady {
            val s: Tunnel = instance()
            val k: KeepAlive = instance()
            val d: Dns = instance()

            // Keep DNS servers up to date on notification
            val keepAliveNotificationUpdater = {
                val nm: NotificationManager = instance()
                val n = createNotificationKeepAlive(ctx = ctx, count = 0, last = "")
                nm.notify(3, n)
            }
            var w: IWhen? = null
            k.keepAlive.doWhenSet().then {
                if (k.keepAlive()) {
                    w = d.dnsServers.doOnUiWhenSet().then {
                        keepAliveNotificationUpdater()
                    }
                } else {
                    d.dnsServers.cancel(w)
                    // Will be turned off by logic in core module
                }
            }

            // Initialize default values for properties that need it (async)
            s.tunnelDropCount {}
        }
    }
}

