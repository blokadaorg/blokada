package tunnel

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

class JsonFilterSerialiser {
    fun deserialise(repo: String): Set<Filter> {
       val filters = emptySet<Filter>().toMutableSet()
        try {
            val jsonFilters = JSONArray(repo)
            for (i in 0 until jsonFilters.length()) {
                val jsonFilter = jsonFilters.getJSONObject(i)
                val jsonSource = jsonFilter.getJSONObject("source")
                val customName = jsonFilter.getString("name")
                val customComment = jsonFilter.getString("comment")

                filters.add(Filter(
                    jsonFilter.getString("id"),
                    FilterSourceDescriptor(
                        jsonSource.getString("id"),
                        jsonSource.getString("url")
                    ),
                    jsonFilter.getBoolean("whitelist"),
                    jsonFilter.getBoolean("active"),
                false,
                        i,
                    credit = jsonFilter.getString("credit"),
                    customName = if(jsonFilter.isNull("name") || customName.isEmpty()) null else customName,
                    customComment = if(jsonFilter.isNull("comment") || customComment.isEmpty()) null else customComment
                ))
            }

        } catch (e: JSONException) {
            v("Json parsing error: " + e.message)
            v("JSON-data was:$repo")
            core.e(e)
        }

        return filters
    }
}