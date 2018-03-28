package update

import com.github.salomonbrys.kodein.instance
import core.Tunnel
import core.TunnelState
import gs.environment.Environment
import gs.environment.Journal
import gs.property.IWhen
import java.net.URL

/**
 * It makes sure Blokada is inactive during update download.
 */
class UpdateCoordinator(
        private val xx: Environment,
        private val downloader: AUpdateDownloader,
        private val s: Tunnel = xx().instance(),
        private val j: Journal = xx().instance()
) {

    private var w: IWhen? = null
    private var downloading = false

    fun start(urls: List<URL>) {
        if (downloading) return
        if (s.tunnelState(TunnelState.INACTIVE)) {
            download(urls)
        }
        else {
            j.log("UpdateCoordinator: deactivate tunnel: ${s.tunnelState()}")
            s.tunnelState.cancel(w)
            w = s.tunnelState.doOnUiWhenChanged().then {
                if (s.tunnelState(TunnelState.INACTIVE)) {
                    if (!downloading) {
                        j.log("UpdateCoordinator: tunnel deactivated")
                        s.tunnelState.cancel(w)
                        w = null
                        download(urls)
                    }
                }
            }

            s.updating %= true
            s.restart %= true
            s.active %= false
        }
    }

    private fun download(urls: List<URL>) {
        j.log("UpdateCoordinator: start download")
        downloading = true
        downloader.downloadUpdate(urls, { uri ->
            j.log("UpdateCoordinator: downloaded: url $uri")
            if (uri != null) downloader.openInstall(uri)
            s.updating %= false
            downloading = false
        })
    }

}

