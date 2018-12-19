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

        external fun x25519_secret_key(): ByteArray
        external fun x25519_public_key(secret_key: ByteArray): ByteArray
        external fun x25519_key_to_hex(key: ByteArray): String
        external fun x25519_key_to_base64(key: ByteArray): String
        external fun new_tunnel(secret_key: String, public_key: String): Long
        external fun wireguard_write(tunnel: Long, src: ByteArray, src_size: Int, dst: ByteBuffer, dst_size: Int, op: ByteBuffer): Int
        external fun wireguard_read(tunnel: Long, src: ByteArray, src_size: Int, dst: ByteBuffer, dst_size: Int, op: ByteBuffer): Int
        external fun wireguard_tick(tunnel: Long, dst: ByteBuffer, dst_size: Int, op: ByteBuffer): Int
    }
}
