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
       val filters = emptySet<Filter>().toMutableSet()
        val gson = Gson()
        gson.fromJson(repo,  Array<JsonFilter>::class.java).forEachIndexed { i: Int, filter: JsonFilter ->
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