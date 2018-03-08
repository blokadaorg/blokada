package org.blokada.app

import org.blokada.framework.combine
import core.Filter
import filter.FilterSourceSingle
import org.junit.Assert
import org.junit.Test

/**
 *
 */
class FilterManagingTest {
    @Test fun combine_combines() {
        val filters2 = listOf(
                Filter("two", FilterSourceSingle(), hosts = listOf("two.com")),
                Filter("four", FilterSourceSingle(), hosts = listOf("four.com", "five.com"))
        )

        val whitelist = listOf(
                Filter("one", FilterSourceSingle(), hosts = listOf("one.com")),
                Filter("four", FilterSourceSingle(), hosts = listOf("four.com"))
        )


        val combined = combine(filters2, whitelist)

        Assert.assertEquals(2, combined.size)
    }

    @Test fun filter_equal() {
        val filters = listOf(
                Filter("two", FilterSourceSingle("two.com")),
                Filter("four", FilterSourceSingle("four.com"))
        )

        val filters2 = listOf(
                Filter("two 2", FilterSourceSingle("two.com")),
                Filter("one", FilterSourceSingle("one.com"))
        )

        // Test the code from FilterStrategy
        val filters3 = filters.map { filter ->
            val newFilter = filters2.find { it == filter }
            newFilter ?: filter
        }

        Assert.assertEquals("two 2", filters3[0].id)

        // Test another code from FilterStrategy
        val filters4 = filters2.filter { !filters.contains(it) } + filters

        Assert.assertEquals("one", filters4[0].id)
        Assert.assertEquals("two", filters4[1].id)
        Assert.assertEquals("four", filters4[2].id)
    }

}
