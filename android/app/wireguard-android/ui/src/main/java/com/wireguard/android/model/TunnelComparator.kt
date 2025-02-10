/*
 * Copyright © 2017-2021 WireGuard LLC. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

package com.wireguard.android.model

object TunnelComparator : Comparator<String> {
    private class NaturalSortString(originalString: String) {
        class NaturalSortToken(val maybeString: String?, val maybeNumber: Int?) : Comparable<NaturalSortToken> {
            override fun compareTo(other: NaturalSortToken): Int {
                if (maybeString == null) {
                    if (other.maybeString != null || maybeNumber!! < other.maybeNumber!!) {
                        return -1
                    } else if (maybeNumber > other.maybeNumber) {
                        return 1
                    }
                } else if (other.maybeString == null || maybeString > other.maybeString) {
                    return 1
                } else if (maybeString < other.maybeString) {
                    return -1
                }
                return 0
            }
        }

        val tokens: MutableList<NaturalSortToken> = ArrayList()

        init {
            for (s in NATURAL_SORT_DIGIT_FINDER.findAll(originalString.split(WHITESPACE_FINDER).joinToString(" ").lowercase())) {
                try {
                    val n = s.value.toInt()
                    tokens.add(NaturalSortToken(null, n))
                } catch (_: NumberFormatException) {
                    tokens.add(NaturalSortToken(s.value, null))
                }
            }
        }

        private companion object {
            private val NATURAL_SORT_DIGIT_FINDER = Regex("""\d+|\D+""")
            private val WHITESPACE_FINDER = Regex("""\s""")
        }
    }

    override fun compare(a: String, b: String): Int {
        if (a == b)
            return 0
        val na = NaturalSortString(a)
        val nb = NaturalSortString(b)
        for (i in 0 until nb.tokens.size) {
            if (i == na.tokens.size) {
                return -1
            }
            val c = na.tokens[i].compareTo(nb.tokens[i])
            if (c != 0)
                return c
        }
        return 1
    }
}
