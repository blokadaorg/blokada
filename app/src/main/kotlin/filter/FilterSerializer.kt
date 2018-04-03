package filter

import core.Filter
import core.IFilterSource
import core.LocalisedFilter
import gs.environment.batch
import gs.property.Repo

/**
 * AFilterSerialiser is responsible for serialising and deserialising filters.
 *
 * It's used both for persisting user filters, as well as reading default (builtin) filters from
 * the repo. A newline-separated-value file format is used, that is designed for easy by-hand
 * editing and simple parsing without external libraries:
 *
 * order_integer
 * filter_id
 * blacklist|whitelist
 * active|inactive
 * credit_url
 * source_id
 * source
 * name
 * comment
 *
 * Both name and comment are optional and can be just empty lines. They are suspect for localisation.
 */
class FilterSerializer(
        private val repo: Repo,
        private val sourceProvider: (String) -> IFilterSource
) {

    private fun backupUrl(id: String): String {
        return "${repo.content().contentPath?.toExternalForm()}/canonical/cache/${id}.txt"
    }

    /**
     * Serialises a list of filters into a list of lines that should be written to persistence as is.
     */
    fun serialise(filters: List<Filter>): List<String> {
        var i = 0
        return filters.map {
            val whitelist = if (it.whitelist) "whitelist" else "blacklist"
            val active = if (it.active) "active" else "inactive"
            val soureId = it.source.id()
            val source = it.source.toUserInput()
            val name = it.localised?.name ?: ""
            val comment = it.localised?.comment?.replace("\n", "\\n") ?: ""

            "${i++}\n${it.id}\n${whitelist}\n${active}\n${it.credit}\n${soureId}\n${source}\n${name}\n${comment}"
        }.flatMap { it.split("\n") }
    }

    /**
     * Deserialises a list of lines read directly from persistence into a list of filters. Will skip
     * any incorrectly looking entries. May return an empty list.
     */
    fun deserialise(repo: List<String>): List<Filter> {
        if (repo.size <= 1) return emptyList()
        val filters = repo.asSequence().batch(9).map { entry ->
            entry[0].toInt() to try {
                val id = entry[1]
                val whitelist = entry[2] == "whitelist"
                val active = entry[3] == "active"
                val credit = entry[4]
                val sourceId = entry[5]
                val url = entry[6]
                val name = entry[7]
                val comment = if(entry[8].isNotBlank()) entry[8].replace("\\n", "\n") else null

                val source = sourceProvider(sourceId)
                if (!source.fromUserInput(url, backupUrl(id))) throw Exception("invalid source input")

                val localised = if (name.isNotBlank()) LocalisedFilter(name, comment) else null

                Filter(id, source, credit, true, active, whitelist, emptyList(), localised)
            } catch (e: Exception) {
                null
            }
        }.toList().sortedBy { it.first }.map { it.second }.filterNotNull()

        return filters
    }

}
