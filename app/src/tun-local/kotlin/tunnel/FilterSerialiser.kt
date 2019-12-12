package tunnel

import com.google.gson.Gson
import core.batch
import core.v
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject


class LegacyFilterSerialiser {
    fun deserialise(repo: List<String>): Set<Filter> {
        if (repo.size <= 1) return emptySet()
        var priority = 0
        val filters = repo.asSequence().batch(9).map { entry ->
            entry[0].toInt() to try {
                val id = entry[1]
                val whitelist = entry[2] == "whitelist"
                val active = entry[3] == "active"
                val credit = entry[4]
                val sourceId = entry[5]
                val url = entry[6]
                val name = if (entry[7].isNotBlank()) entry[7] else null
                val comment = if (entry[8].isNotBlank()) entry[8].replace("\\n", "\n") else null

                Filter(id, FilterSourceDescriptor(sourceId, url), whitelist, active, false,
                        priority = priority++, credit = credit, customName = name, customComment = comment)
            } catch (e: Exception) {
                null
            }
        }.map { it.second }.filterNotNull().toMutableSet()

        // Set hidden flag
        repo.asSequence().last().split(';').forEach { h ->
            val hidden = filters.firstOrNull { it.id == h }?.copy(hidden = true)
            if (hidden != null) filters += hidden
        }
        return filters
    }
}

data class JsonFilter(
        val id: FilterId,
        val source: FilterSourceDescriptor,
        val whitelist: Boolean = false,
        val active: Boolean = false,
        val credit: String? = null,
        val customName: String? = null,
        val customComment: String? = null

)

class JsonFilterSerialiser {
    fun deserialise(repo: String): Set<Filter> {
        //REMOVE!!!!!!!!!!!!!!!!
        val temp_repo = "[{\"id\":\"b_unified\",\"source\":{\"id\":\"link\",\"source\":\"https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://github.com/StevenBlack/hosts\",\"name\":null,\"comment\":null},{\"id\":\"b_unified_porn\",\"source\":{\"id\":\"link\",\"source\":\"https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://github.com/StevenBlack/hosts\",\"name\":null,\"comment\":null},{\"id\":\"b_energized_basic\",\"source\":{\"id\":\"link\",\"source\":\"https://raw.githubusercontent.com/EnergizedProtection/block/master/basic/formats/hosts\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://github.com/AdroitAdorKhan/Energized\",\"name\":null,\"comment\":null},{\"id\":\"b_energized_blu_go\",\"source\":{\"id\":\"link\",\"source\":\"https://raw.githubusercontent.com/EnergizedProtection/block/master/bluGo/formats/hosts\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://github.com/AdroitAdorKhan/Energized\",\"name\":null,\"comment\":null},{\"id\":\"b_energized_blu\",\"source\":{\"id\":\"link\",\"source\":\"https://raw.githubusercontent.com/EnergizedProtection/block/master/blu/formats/hosts\"},\"whitelist\":false,\"active\":true,\"credit\":\"https://github.com/AdroitAdorKhan/Energized\",\"name\":null,\"comment\":null},{\"id\":\"b_energized_spark\",\"source\":{\"id\":\"link\",\"source\":\"https://raw.githubusercontent.com/EnergizedProtection/block/master/spark/formats/hosts\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://github.com/AdroitAdorKhan/Energized\",\"name\":null,\"comment\":null},{\"id\":\"b_goodbyeads\",\"source\":{\"id\":\"link\",\"source\":\"https://raw.githubusercontent.com/jerryn70/GoodbyeAds/master/Hosts/GoodbyeAds.txt\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://github.com/jerryn70/GoodbyeAds\",\"name\":null,\"comment\":null},{\"id\":\"b_hphosts\",\"source\":{\"id\":\"link\",\"source\":\"https://hosts-file.net/ad_servers.txt\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://hosts-file.net/?s=Download\",\"name\":null,\"comment\":null},{\"id\":\"b_mvps\",\"source\":{\"id\":\"link\",\"source\":\"http://winhelp2002.mvps.org/hosts.txt\"},\"whitelist\":false,\"active\":false,\"credit\":\"http://winhelp2002.mvps.org/hosts.htm\",\"name\":null,\"comment\":null},{\"id\":\"b_adaway\",\"source\":{\"id\":\"link\",\"source\":\"https://adaway.org/hosts.txt\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://adaway.org\",\"name\":null,\"comment\":null},{\"id\":\"b_danpollock\",\"source\":{\"id\":\"link\",\"source\":\"https://someonewhocares.org/hosts/hosts\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://someonewhocares.org/hosts/zero/\",\"name\":null,\"comment\":null},{\"id\":\"b_pgl\",\"source\":{\"id\":\"link\",\"source\":\"https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://pgl.yoyo.org/adservers/\",\"name\":null,\"comment\":null},{\"id\":\"b_social\",\"source\":{\"id\":\"link\",\"source\":\"https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/social/hosts\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://github.com/StevenBlack/hosts\",\"name\":null,\"comment\":null},{\"id\":\"b_mining\",\"source\":{\"id\":\"link\",\"source\":\"https://zerodot1.gitlab.io/CoinBlockerLists/hosts\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://gitlab.com/ZeroDot1/CoinBlockerLists\",\"name\":null,\"comment\":null},{\"id\":\"b_xiaomi\",\"source\":{\"id\":\"link\",\"source\":\"https://raw.githubusercontent.com/jerryn70/GoodbyeAds/master/Extension/GoodbyeAds-Xiaomi-Extension.txt\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://github.com/jerryn70/GoodbyeAds\",\"name\":null,\"comment\":null},{\"id\":\"b_mat\",\"source\":{\"id\":\"link\",\"source\":\"https://raw.githubusercontent.com/jawz101/MobileAdTrackers/master/hosts\"},\"whitelist\":false,\"active\":false,\"credit\":\"https://github.com/jawz101/MobileAdTrackers\",\"name\":null,\"comment\":null},{\"id\":\"b_app_vending\",\"source\":{\"id\":\"app\",\"url\":\"com.android.vending\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_downloads\",\"source\":{\"id\":\"app\",\"url\":\"com.android.providers.downloads\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_allo\",\"source\":{\"id\":\"app\",\"url\":\"com.google.android.apps.fireball\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_authenticator\",\"source\":{\"id\":\"app\",\"url\":\"com.google.android.apps.authenticator2\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_gdocs\",\"source\":{\"id\":\"app\",\"url\":\"com.google.android.apps.docs\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_duo\",\"source\":{\"id\":\"app\",\"url\":\"com.google.android.apps.tachyon\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_gmail\",\"source\":{\"id\":\"app\",\"url\":\"com.google.android.gm\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_gphotos\",\"source\":{\"id\":\"app\",\"url\":\"com.google.android.apps.photos\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_playgames\",\"source\":{\"id\":\"app\",\"url\":\"com.google.android.play.games\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_signal\",\"source\":{\"id\":\"app\",\"url\":\"org.thoughtcrime.securesms\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_plex\",\"source\":{\"id\":\"app\",\"url\":\"com.plexapp.android\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_kdeconnect\",\"source\":{\"id\":\"app\",\"url\":\"org.kde.kdeconnect_tp\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_waze\",\"source\":{\"id\":\"app\",\"url\":\"com.waze\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_xda\",\"source\":{\"id\":\"app\",\"url\":\"com.xda.labs\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_incallui\",\"source\":{\"id\":\"app\",\"url\":\"com.android.incallui\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_phone\",\"source\":{\"id\":\"app\",\"url\":\"com.android.phone\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_telephony\",\"source\":{\"id\":\"app\",\"url\":\"com.android.providers.telephony\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_hwsysmanager\",\"source\":{\"id\":\"app\",\"url\":\"com.huawei.systemmanager\"},\"whitelist\":true,\"active\":false,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_rcsserviceapp\",\"source\":{\"id\":\"app\",\"url\":\"com.android.service.ims.RcsServiceApp\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_carriersetup\",\"source\":{\"id\":\"app\",\"url\":\"com.google.android.carriersetup\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_carrierservice\",\"source\":{\"id\":\"app\",\"url\":\"com.google.android.ims\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_cafservice\",\"source\":{\"id\":\"app\",\"url\":\"com.codeaurora.ims\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null},{\"id\":\"b_app_carrierconfig\",\"source\":{\"id\":\"app\",\"url\":\"com.android.carrierconfig\"},\"whitelist\":true,\"active\":true,\"credit\":\"https://blokada.org\",\"name\":null,\"comment\":null}]"
        val filters = emptySet<Filter>().toMutableSet()
        val gson = Gson()
        gson.fromJson(temp_repo,  Array<JsonFilter>::class.java).forEachIndexed { i: Int, filter: JsonFilter ->
            filters.add(Filter(
                filter.id,
                filter.source,
                filter.whitelist,
                filter.active,
            false,
                    i,
                credit = filter.credit,
                customName = filter.customName,
                customComment = filter.customComment
            ))
        }

        return filters
    }
}