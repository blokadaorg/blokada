package tunnel

import core.batch

class FilterSerializer {
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
