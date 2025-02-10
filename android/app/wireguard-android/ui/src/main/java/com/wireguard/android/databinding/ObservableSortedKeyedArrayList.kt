/*
 * Copyright © 2017-2021 WireGuard LLC. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */
package com.wireguard.android.databinding

import java.util.AbstractList
import java.util.Collections
import java.util.Comparator
import java.util.Spliterator

/**
 * KeyedArrayList that enforces uniqueness and sorted order across the set of keys. This class uses
 * binary search to improve lookup and replacement times to O(log(n)). However, due to the
 * array-based nature of this class, insertion and removal of elements with anything but the largest
 * key still require O(n) time.
 */
class ObservableSortedKeyedArrayList<K, E : Keyed<out K>>(private val comparator: Comparator<in K>) : ObservableKeyedArrayList<K, E>() {
    @Transient
    private val keyList = KeyList(this)

    override fun add(element: E): Boolean {
        val insertionPoint = getInsertionPoint(element)
        if (insertionPoint < 0) {
            // Skipping insertion is non-destructive if the new and existing objects are the same.
            if (element === get(-insertionPoint - 1)) return false
            throw IllegalArgumentException("Element with same key already exists in list")
        }
        super.add(insertionPoint, element)
        return true
    }

    override fun add(index: Int, element: E) {
        val insertionPoint = getInsertionPoint(element)
        require(insertionPoint >= 0) { "Element with same key already exists in list" }
        if (insertionPoint != index) throw IndexOutOfBoundsException("Wrong index given for element")
        super.add(index, element)
    }

    override fun addAll(elements: Collection<E>): Boolean {
        var didChange = false
        for (e in elements) {
            if (add(e))
                didChange = true
        }
        return didChange
    }

    override fun addAll(index: Int, elements: Collection<E>): Boolean {
        var i = index
        for (e in elements)
            add(i++, e)
        return true
    }

    private fun getInsertionPoint(e: E) = -Collections.binarySearch(keyList, e.key, comparator) - 1

    override fun indexOfKey(key: K): Int {
        val index = Collections.binarySearch(keyList, key, comparator)
        return if (index >= 0) index else -1
    }

    override fun set(index: Int, element: E): E {
        val order = comparator.compare(element.key, get(index).key)
        if (order != 0) {
            // Allow replacement if the new key would be inserted adjacent to the replaced element.
            val insertionPoint = getInsertionPoint(element)
            if (insertionPoint < index || insertionPoint > index + 1)
                throw IndexOutOfBoundsException("Wrong index given for element")
        }
        return super.set(index, element)
    }

    private class KeyList<K, E : Keyed<out K>>(private val list: ObservableSortedKeyedArrayList<K, E>) : AbstractList<K>(), Set<K> {
        override fun get(index: Int): K = list[index].key

        override val size
            get() = list.size

        override fun spliterator(): Spliterator<K> = super<AbstractList>.spliterator()
    }
}
