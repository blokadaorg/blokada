package update

import core.State
import core.TunnelState
import org.obsolete.IWhen
import java.net.URL

/**
 * It makes sure Blokada is inactive during update download.
 */
class UpdateCoordinator(
        private val s: State,
        private val downloader: AUpdateDownloader
) {

    private var w: IWhen? = null

    fun start(urls: List<URL>) {
        s.tunnelState.cancel(w)
        if (s.tunnelState(TunnelState.INACTIVE)) download(urls)
        else {
            w = s.tunnelState.doOnUiWhenChanged().then {
                if (s.tunnelState(TunnelState.INACTIVE)) {
                    if (w != null) s.tunnelState.cancel(w)
                    download(urls)
                }
            }

            s.updating %= true
            s.restart %= true
            s.active %= false
        }
    }

    private fun download(urls: List<URL>) {
        downloader.downloadUpdate(urls, { uri ->
            downloader.openInstall(uri!!)
            s.updating %= false
        })
    }

}

