package org.obsolete

import core.Filter

internal fun downloadFilters(filters: List<Filter>) {
    filters.forEach { filter ->
        if (filter.hosts.isEmpty()) {
            filter.hosts = filter.source.fetch()
            filter.valid = filter.hosts.isNotEmpty()
        }
    }
}

internal fun combine(blacklist: List<Filter>, whitelist: List<Filter>): Set<String> {
    val set = mutableSetOf<String>()
    blacklist.forEach { set.addAll(it.hosts) }
    whitelist.forEach { set.removeAll(it.hosts) }
    return set
}
