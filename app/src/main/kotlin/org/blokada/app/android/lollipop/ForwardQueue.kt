/* Copyright (C) 2017 Karsen Gauss <a@kar.gs>
 *
 * Derived from DNS66:
 * Copyright (C) 2016 Julian Andres Klode <jak@jak-linux.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * Contributions shall also be provided under any later versions of the
 * GPL.
 */
package org.blokada.app.android.lollipop

import org.pcap4j.packet.IpPacket
import java.net.DatagramSocket
import java.util.*

internal class Item(
        val socket: DatagramSocket,
        val packet: IpPacket
) {
    private val time: Long = System.currentTimeMillis()

    internal fun ageSeconds(): Long {
        return (System.currentTimeMillis() - time) / 1000
    }
}

internal class ForwardQueue : Iterable<Item> {
    private val list = LinkedList<Item>()

    fun add(item: Item) {
        if (list.size > 1024) {
            list.element().socket.close()
            list.remove()
        }
        while (!list.isEmpty() && list.element().ageSeconds() > 10) {
            list.element().socket.close()
            list.remove()
        }
        list.add(item)
    }

    override fun iterator(): MutableIterator<Item> {
        return list.iterator()
    }

    fun size(): Int {
        return list.size
    }
}
