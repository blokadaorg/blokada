package org.blokada.app

class Events {
    companion object {
        val FIRST_WELCOME = "first_welcome"
        val FIRST_WELCOME_ADVANCED = "first_welcome_advanced"
        val FIRST_ACTIVE_START = "first_active_start"
        val FIRST_ACTIVE_ASK_VPN = "first_active_ask_vpn"
        val FIRST_ACTIVE_FAIL = "first_active_fail"
        val FIRST_ACTIVE_FINISH = "first_active_finish"
        val FIRST_AD_BLOCKED = "first_ad_blocked"
        val UPDATE_CHECK_START = "update_check_start"
        val UPDATE_CHECK_FAIL = "update_check_fail"
        val UPDATE_NOTIFY = "update_notify"
        val UPDATE_DOWNLOAD_START = "update_download_start"
        val UPDATE_DOWNLOAD_FAIL = "update_download_fail"
        val UPDATE_INSTALL_ASK = "update_install_ask"
        val CLICK_DASH = { id: String -> ClickDash(id) }
        val CLICK_LONG_DASH = { id: String -> ClickLongDash(id) }
        val SHOW_DASH = { id: String -> ShowDash(id) }
        val HIDE_DASH = { id: String -> HideDash(id) }
        val CLICK_CONFIG = { id: String -> ClickConfig(id) }
        val COUNT_BLACKLIST_HOSTS = { count: Int -> CountBlacklistHosts(count) }
        val COUNT_WHITELIST_HOSTS = { count: Int -> CountWhitelistHosts(count) }
        val AD_BLOCKED = { host: String -> AdBlocked(host) }
        val CLICK_ENGINE = { id: String -> ClickEngine(id) }
    }

    class ClickDash(val id: String) : EventGroup("click_dash", id)
    class ClickLongDash(val id: String) : EventGroup("click_long_dash", id)
    class ClickConfig(val id: String) : EventGroup("click_config", id)
    class ClickEngine(val id: String) : EventGroup("click_engine", id)
    class ShowDash(val id: String) : EventGroup("show_dash", id)
    class HideDash(val id: String) : EventGroup("hide_dash", id)
    class AdBlocked(val host: String, val name: String = "adBlocked")
    class CountBlacklistHosts(val count: Int) : EventInt("count_blacklist_hosts", count)
    class CountWhitelistHosts(val count: Int) : EventInt("count_whitelist_hosts", count)

    open class EventGroup(val prefix: String, val suffix: String) {
        override fun toString(): String {
            return "%s_%s".format(prefix, suffix.toLowerCase().replace(" ", "_"))
        }
    }

    open class EventInt(val name: String, val value: Int) {
        override fun toString(): String {
            return name
        }
    }
}
class Properties {
    companion object {
        val ENABLED = "enabled"
        val ENGINE_ACTIVE = "engine_active"
        val KEEP_ALIVE = "keep_alive"
        val AUTO_START = "auto_start"
        val NOTIFICATIONS = "notifications"
        val TUNNEL_STATE = "tunnel_state"
        val WATCHDOG = "watchdog"
    }
}
