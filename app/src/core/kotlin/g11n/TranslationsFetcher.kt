package g11n

import com.github.michaelbull.result.Err
import com.github.michaelbull.result.mapBoth
import com.github.michaelbull.result.mapError
import core.*
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.net.URL
import java.util.*

internal class TranslationsFetcher(
        val urls: () -> Map<Url, Prefix>,
        val doLoadTranslationStore: () -> Result<TranslationStore> = Persistence.translation.load,
        val doSaveTranslationStore: (TranslationStore) -> Result<Any> = Persistence.translation.save,
        val doValidateCacheForUrl: (TranslationStore, Url) -> Boolean = { store, url ->
            store.get(url) + 86400 * 1000 > System.currentTimeMillis()
        },
        val doFetchTranslations: (Url, Prefix) -> Result<Translations> = { url, prefix ->
            Result.of {
                //val translationData = loadGzip(openUrl(URL(url), 10 * 1000))
                //REMOVE!!!!!!!!!!!!!!!!
                val translationData = if(prefix == "filters"){
                    "[{\"key\":\"b_unified_name\",\"translation\":\"StevenBlack Unified\"},{\"key\":\"b_unified_comment\",\"translation\":\"A great choice that strives to keep balance between blocking effectiveness, battery impact and false positives. Try this list if other ones are blocking too much.\"},{\"key\":\"b_hphosts_name\",\"translation\":\"HpHosts\"},{\"key\":\"b_hphosts_comment\",\"translation\":\"A rigorous configuration which will block more ads, but may occasionally mistakenly block desired content. This is a good choice if the default choice is not effective enough for you.\"},{\"key\":\"b_mvps_name\",\"translation\":\"MVPS\"},{\"key\":\"b_mvps_comment\",\"translation\":\"A lenient, less resource-intensive configuration which will omit more ads than the default one, but may improve battery life and device performance. This is a great choice if you are experiencing any issues with your device or apps.\"},{\"key\":\"b_adaway_name\",\"translation\":\"AdAway\"},{\"key\":\"b_adaway_comment\",\"translation\":\"Blocks mobile ad providers and some analytics providers.\"},{\"key\":\"b_danpollock_name\",\"translation\":\"Dan Pollock's hosts file\"},{\"key\":\"b_danpollock_comment\",\"translation\":\"A reasonably balanced ad blocking hosts file.\"},{\"key\":\"b_pgl_name\",\"translation\":\"Peter Lowe's hosts file\"},{\"key\":\"b_pgl_comment\",\"translation\":\"A compact ad servers hosts file.\"},{\"key\":\"b_mining_name\",\"translation\":\"Coin Blocker List\"},{\"key\":\"b_mining_comment\",\"translation\":\"A simple list that prevents unwanted mining of cryptocurrencies, like Bitcoin.\"},{\"key\":\"b_social_name\",\"translation\":\"Social hosts file\"},{\"key\":\"b_social_comment\",\"translation\":\"Blocks social sites. Useful for blocking Facebook ads, but may block too much.\"},{\"key\":\"b_moab_name\",\"translation\":\"Mother of all AdBlocking (MoAB)\"},{\"key\":\"b_moab_comment\",\"translation\":\"The famous XDA ad blocking list.\"},{\"key\":\"b_adzhosts_name\",\"translation\":\"AdZHosts\"},{\"key\":\"b_adzhosts_comment\",\"translation\":\"The most complete and accurate filtering list on the net. Regularly updated and live support on Telegram.\"},{\"key\":\"b_unified_porn_name\",\"translation\":\"StevenBlack Unified + porn\"},{\"key\":\"b_unified_porn_comment\",\"translation\":\"Same as Unified, with additional blocking of sites with adult content.\"},{\"key\":\"b_energized_spark_name\",\"translation\":\"Energized Spark\"},{\"key\":\"b_energized_spark_comment\",\"translation\":\"The most compact version of the Energized list. Good for devices with very little RAM.\"},{\"key\":\"b_energized_blu_go_name\",\"translation\":\"Energized Blu Go\"},{\"key\":\"b_energized_blu_go_comment\",\"translation\":\"The little brother of Energized Blu, for devices with less available RAM.\"},{\"key\":\"b_energized_blu_name\",\"translation\":\"Energized Blu (recommended)\"},{\"key\":\"b_energized_blu_comment\",\"translation\":\"A lightweight list optimized for mobile devices, blocking most of the ads one can face browsing the net or running apps.\"},{\"key\":\"b_energized_basic_name\",\"translation\":\"Energized Basic\"},{\"key\":\"b_energized_basic_comment\",\"translation\":\"Standard version of the popular Energized list. This list consists of ad domains, tracking scripts, malware and other from reputable sources always merged and unified into one list. The purpose of this list is to provide the best protection and cover most of advertisement, malware, spam and tracking in both web and apps.\"},{\"key\":\"b_goodbyeads_name\",\"translation\":\"Goodbye Ads by Jerryn70\"},{\"key\":\"b_goodbyeads_comment\",\"translation\":\"Blocks mobile ads & trackers. Particularly designed for blocking ads in games & apps. Unlike other host files it also blocks ads provided by Facebook. This will also increase battery life and performance. Note: if you are a Facebook user, whitelist it to work properly.\"},{\"key\":\"b_xiaomi_name\",\"translation\":\"Xiaomi blocker by Jerryn70\"},{\"key\":\"b_xiaomi_comment\",\"translation\":\"List specifically for Xiaomi phones, to keep your device clean and tidy.\"},{\"key\":\"b_mat_name\",\"translation\":\"MobileAdTrackers\"},{\"key\":\"b_mat_comment\",\"translation\":\"The list is taken from DNS logs while actively using Android apps over the years. The list, as it suggests, aims to block trackers your device may accesses day by day.\"}]"
                }else{
                    "[{\"key\":\"opendns_name\",\"translation\":\"OpenDNS\"},{\"key\":\"opendns_comment\",\"translation\":\"Extends the Domain Name System by adding features such as phishing protection and optional content filtering.\"},{\"key\":\"google_name\",\"translation\":\"Google Public DNS\"},{\"key\":\"google_comment\",\"translation\":\"A free, global DNS resolution service that you can use as an alternative to your current DNS provider.\"},{\"key\":\"quad9_name\",\"translation\":\"Quad9\"},{\"key\":\"quad9_comment\",\"translation\":\"Quad9 uses threat intelligence from more than a dozen of the industry’s leading cyber security companies to give a real-time perspective on what websites are safe and what sites are known to include malware or other threats. \"},{\"key\":\"verisign_name\",\"translation\":\"VeriSign Public DNS\"},{\"key\":\"verisign_comment\",\"translation\":\"Verisign Public DNS is a free DNS service that offers improved DNS stability and security over other alternatives. And, unlike many of the other DNS services out there, Verisign respects your privacy.\"},{\"key\":\"dnswatch_name\",\"translation\":\"DNS.WATCH\"},{\"key\":\"dnswatch_comment\",\"translation\":\"No Censorship. No Bullshit. Just DNS.\"},{\"key\":\"adguard_name\",\"translation\":\"AdGuard DNS\"},{\"key\":\"adguard_comment\",\"translation\":\"AdGuard DNS is an alternative solution for ad blocking, privacy protection, and parental control.\"},{\"key\":\"adguard_family_name\",\"translation\":\"AdGuard DNS (Family)\"},{\"key\":\"adguard_family_comment\",\"translation\":\"Use the Family protection mode of AdGuard DNS to block access to all websites with adult content and enforce safe search in the browser, in addition to the regular perks of ad blocking and browsing security.\"},{\"key\":\"cloudflare_name\",\"translation\":\"Cloudflare 1.1.1.1\"},{\"key\":\"cloudflare_comment\",\"translation\":\"The new, fast DNS servers from Cloudflare with privacy guarantee.\"},{\"key\":\"keweon_name\",\"translation\":\"Keweon\"},{\"key\":\"keweon_comment\",\"translation\":\"Keweon Adblock and Online Security is a network of DNS servers around the world that provide advanced features, like adblocking and privacy protection, while protecting from spyware, malware, phishing, fake software and more.\"},{\"key\":\"alternate_name\",\"translation\":\"Alternate DNS\"},{\"key\":\"alternate_comment\",\"translation\":\"Alternate DNS is an affordable, global Domain Name System resolution service that blocks unwanted ads.\"},{\"key\":\"fdn_name\",\"translation\":\"French Data Network\"},{\"key\":\"fdn_comment\",\"translation\":\"The French Data Network is a fast, reliable DNS service, recommended for French users.\"},{\"key\":\"opennicusa_name\",\"translation\":\"OpenNIC - USA\"},{\"key\":\"opennicusa_comment\",\"translation\":\"The OpenNIC project is a global service that ensures neutrality and reliability. This option is optimal for users in the USA.\"},{\"key\":\"openniceu_name\",\"translation\":\"OpenNIC - Europe\"},{\"key\":\"openniceu_comment\",\"translation\":\"The OpenNIC project is a global service that ensures neutrality and reliability. This option is optimal for users in the EU.\"},{\"key\":\"uncensored_name\",\"translation\":\"Uncensored DNS\"},{\"key\":\"uncensored_comment\",\"translation\":\"Uncensored, just as the name implies, aims to provide uncensored, unfiltered internet.\"},{\"key\":\"tenta_name\",\"translation\":\"Tenta DNS\"},{\"key\":\"tenta_comment\",\"translation\":\"Tenta DNS is your open source, privacy-first DNS solution. With their service, you can ensure your browsing will stay private.\"},{\"key\":\"freenom_name\",\"translation\":\"Freenom World\"},{\"key\":\"freenom_comment\",\"translation\":\"A fast and anonymous public DNS resolver with servers around the globe. Their service doesn't store your IP while it gives you the result you are expecting, nothing additional.\"},{\"key\":\"digitalcourage_name\",\"translation\":\"Digitalcourage\"},{\"key\":\"digitalcourage_comment\",\"translation\":\"The organisation is well known about their privacy and security focused work, Digitalcourage campaigns for civil and human rights, consumer protection, freedom of information and related issues. \"},{\"key\":\"quad101_name\",\"translation\":\"Quad101\"},{\"key\":\"quad101_comment\",\"translation\":\"Quad101 is the Taiwan Network Information Center's experimental public DNS project, running one of the world's fastest DNS infrastructure.\"}]"
                }
                val translations = emptyTranslations().toMutableList()
                try {
                    val jsonTranslations = JSONArray(translationData)
                    for (i in 0 until jsonTranslations.length()){
                        val jsonTranslation = jsonTranslations.getJSONObject(i)
                        translations.add("${prefix}_${jsonTranslation.getString("key")}" to jsonTranslation.getString("translation"))
                    }

                } catch (e: JSONException) {
                    v("Json parsing error: " + e.message)
                    v("JSON-data was:$translationData")
                    e(e)
                }
                translations
            }
        },
        val doPutTranslation: (Key, Translation) -> Result<Boolean> = { key, translation ->
            Err(Exception("nowhere to put translations"))
        }
) {

    private var store = TranslationStore()

    @Synchronized fun load(ktx: Kontext) {
        doLoadTranslationStore().mapBoth(
                success = {
                    ktx.v("loaded TranslationStore from persistence", it.cache.size)
//                    ktx.emit(Events.FILTERS_CHANGED, it.cache)
                    store = it
                },
                failure = {
                    ktx.e("failed loading TranslationStore from persistence", it)
                }
        )
    }

    @Synchronized fun save(ktx: Kontext) {
        doSaveTranslationStore(store).mapBoth(
                success = { ktx.v("saved TranslationStore to persistence") },
                failure = { ktx.e("failed saving TranslationStore to persistence", it) }
        )
    }

    @Synchronized fun sync(ktx: Kontext) {
        val invalid = urls().filter { !doValidateCacheForUrl(store, it.key) }
        ktx.v("attempting to fetch ${invalid.size} translation urls")

        var failed = 0
        invalid.map { (url, prefix) -> doFetchTranslations(url, prefix).mapBoth(
                success = {
                    ktx.v("translation fetched", url, it.size)
                    url to it
                },
                failure = { ex ->
                    ktx.e("failed fetching translation", url, ex)
                    ++failed
                    url to emptyTranslations()
                }
        ) }.filter { it.second.isNotEmpty() }.forEach { (url, translations) ->
            store = store.put(url)
            translations.forEach { (key, value) ->
                doPutTranslation(key, value).mapError { ex -> ktx.e("failed putting translation", ex) }
            }
        }

        ktx.v("finished fetching translations; $failed failed")
    }

    @Synchronized fun invalidateCache(ktx: Kontext) {
        ktx.v("invalidating translations cache")
        store = TranslationStore()
    }
}
