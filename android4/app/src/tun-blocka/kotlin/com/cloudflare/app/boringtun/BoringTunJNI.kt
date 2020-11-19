/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package com.cloudflare.app.boringtun

import java.nio.ByteBuffer

class BoringTunJNI {
    companion object {
        /// No operation is required.
        const val WIREGUARD_DONE = 0
        /// Write dst buffer to network. Size indicates the number of bytes to write.
        const val WRITE_TO_NETWORK = 1
        /// Some error occurred, no operation is required. Size indicates error code.
        const val WIREGUARD_ERROR = 2
        /// Write dst buffer to the interface as an ipv4 packet. Size indicates the number of bytes to write.
        const val WRITE_TO_TUNNEL_IPV4 = 4
        /// Write dst buffer to the interface as an ipv6 packet. Size indicates the number of bytes to write.
        const val WRITE_TO_TUNNEL_IPV6 = 6

        val errors = arrayOf(
            "DestinationBufferTooSmall",
            "IncorrectPacketLength",
            "UnexpectedPacket",
            "WrongPacketType",
            "WrongIndex",
            "WrongKey",
            "InvalidTai64nTimestamp",
            "WrongTai64nTimestamp",
            "InvalidMac",
            "InvalidAeadTag",
            "InvalidCounter",
            "InvalidPacket",
            "NoCurrentSession",
            "LockFailed",
            "ConnectionExpired"
        )

        private val instance = BoringTunJNI()

        fun x25519_secret_key() = instance.x25519_secret_key()
        fun x25519_public_key(secret_key: ByteArray) = instance.x25519_public_key(secret_key)
        fun x25519_key_to_hex(key: ByteArray) = instance.x25519_key_to_hex(key)
        fun x25519_key_to_base64(key: ByteArray) = instance.x25519_key_to_base64(key)
        fun new_tunnel(secret_key: String, public_key: String) = instance.new_tunnel(secret_key, public_key)
        fun wireguard_write(tunnel: Long, src: ByteArray, src_size: Int, dst: ByteBuffer, dst_size: Int, op: ByteBuffer)
                = instance.wireguard_write(tunnel, src, src_size, dst, dst_size, op)
        fun wireguard_read(tunnel: Long, src: ByteArray, src_size: Int, dst: ByteBuffer, dst_size: Int, op: ByteBuffer)
                = instance.wireguard_read(tunnel, src, src_size, dst, dst_size, op)
        fun wireguard_tick(tunnel: Long, dst: ByteBuffer, dst_size: Int, op: ByteBuffer)
                = instance.wireguard_tick(tunnel, dst, dst_size, op)

    }

    external fun x25519_secret_key(): ByteArray
    external fun x25519_public_key(secret_key: ByteArray): ByteArray
    external fun x25519_key_to_hex(key: ByteArray): String
    external fun x25519_key_to_base64(key: ByteArray): String
    external fun new_tunnel(secret_key: String, public_key: String): Long
    external fun wireguard_write(tunnel: Long, src: ByteArray, src_size: Int, dst: ByteBuffer, dst_size: Int, op: ByteBuffer): Int
    external fun wireguard_read(tunnel: Long, src: ByteArray, src_size: Int, dst: ByteBuffer, dst_size: Int, op: ByteBuffer): Int
    external fun wireguard_tick(tunnel: Long, dst: ByteBuffer, dst_size: Int, op: ByteBuffer): Int

}
