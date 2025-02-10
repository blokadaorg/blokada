/*
 * Copyright © 2017-2021 WireGuard LLC. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */
package com.wireguard.android.util

import android.content.res.Resources
import android.os.RemoteException
import com.wireguard.android.backend.BackendException
import com.wireguard.android.util.RootShell.RootShellException
import com.wireguard.config.BadConfigException
import com.wireguard.config.InetEndpoint
import com.wireguard.config.InetNetwork
import com.wireguard.config.ParseException
import com.wireguard.crypto.Key
import com.wireguard.crypto.KeyFormatException
import org.blokada.R
import ui.MainApplication
import java.net.InetAddress

object ErrorMessages {
    private val BCE_REASON_MAP = mapOf(
            BadConfigException.Reason.INVALID_KEY to R.string.bad_config_reason_invalid_key,
            BadConfigException.Reason.INVALID_NUMBER to R.string.bad_config_reason_invalid_number,
            BadConfigException.Reason.INVALID_VALUE to R.string.bad_config_reason_invalid_value,
            BadConfigException.Reason.MISSING_ATTRIBUTE to R.string.bad_config_reason_missing_attribute,
            BadConfigException.Reason.MISSING_SECTION to R.string.bad_config_reason_missing_section,
            BadConfigException.Reason.SYNTAX_ERROR to R.string.bad_config_reason_syntax_error,
            BadConfigException.Reason.UNKNOWN_ATTRIBUTE to R.string.bad_config_reason_unknown_attribute,
            BadConfigException.Reason.UNKNOWN_SECTION to R.string.bad_config_reason_unknown_section
    )
    private val BE_REASON_MAP = mapOf(
            BackendException.Reason.UNKNOWN_KERNEL_MODULE_NAME to R.string.module_version_error,
            BackendException.Reason.WG_QUICK_CONFIG_ERROR_CODE to R.string.tunnel_config_error,
            BackendException.Reason.TUNNEL_MISSING_CONFIG to R.string.no_config_error,
            BackendException.Reason.VPN_NOT_AUTHORIZED to R.string.vpn_not_authorized_error,
            BackendException.Reason.UNABLE_TO_START_VPN to R.string.vpn_start_error,
            BackendException.Reason.TUN_CREATION_ERROR to R.string.tun_create_error,
            BackendException.Reason.GO_ACTIVATION_ERROR_CODE to R.string.tunnel_on_error,
            //BackendException.Reason.DNS_RESOLUTION_FAILURE to R.string.tunnel_dns_failure
    )
    private val KFE_FORMAT_MAP = mapOf(
            Key.Format.BASE64 to R.string.key_length_explanation_base64,
            Key.Format.BINARY to R.string.key_length_explanation_binary,
            Key.Format.HEX to R.string.key_length_explanation_hex
    )
    private val KFE_TYPE_MAP = mapOf(
            KeyFormatException.Type.CONTENTS to R.string.key_contents_error,
            KeyFormatException.Type.LENGTH to R.string.key_length_error
    )
    private val PE_CLASS_MAP = mapOf(
            InetAddress::class.java to R.string.parse_error_inet_address,
            InetEndpoint::class.java to R.string.parse_error_inet_endpoint,
            InetNetwork::class.java to R.string.parse_error_inet_network,
            Int::class.java to R.string.parse_error_integer
    )
    private val RSE_REASON_MAP = mapOf(
            RootShellException.Reason.NO_ROOT_ACCESS to R.string.error_root,
            RootShellException.Reason.SHELL_MARKER_COUNT_ERROR to R.string.shell_marker_count_error,
            RootShellException.Reason.SHELL_EXIT_STATUS_READ_ERROR to R.string.shell_exit_status_read_error,
            RootShellException.Reason.SHELL_START_ERROR to R.string.shell_start_error,
            RootShellException.Reason.CREATE_BIN_DIR_ERROR to R.string.create_bin_dir_error,
            RootShellException.Reason.CREATE_TEMP_DIR_ERROR to R.string.create_temp_dir_error
    )

    operator fun get(throwable: Throwable?): String {
        val resources = MainApplication.get().resources
        if (throwable == null) return resources.getString(R.string.unknown_error)
        val rootCause = rootCause(throwable)
        return when {
            rootCause is BadConfigException -> {
                val reason = getBadConfigExceptionReason(resources, rootCause)
                val context = if (rootCause.location == BadConfigException.Location.TOP_LEVEL) {
                    resources.getString(R.string.bad_config_context_top_level, rootCause.section.getName())
                } else {
                    resources.getString(R.string.bad_config_context, rootCause.section.getName(), rootCause.location.getName())
                }
                val explanation = getBadConfigExceptionExplanation(resources, rootCause)
                resources.getString(R.string.bad_config_error, reason, context) + explanation
            }
            rootCause is BackendException -> {
                resources.getString(BE_REASON_MAP.getValue(rootCause.reason), *rootCause.format)
            }
            rootCause is RootShellException -> {
                resources.getString(RSE_REASON_MAP.getValue(rootCause.reason), *rootCause.format)
            }
//            rootCause is Resources.NotFoundException -> {
//                resources.getString(R.string.error_no_qr_found)
//            }
//            rootCause is ChecksumException -> {
//                resources.getString(R.string.error_qr_checksum)
//            }
            rootCause.message != null -> {
                rootCause.message!!
            }
            else -> {
                val errorType = rootCause.javaClass.simpleName
                resources.getString(R.string.generic_error, errorType)
            }
        }
    }

    private fun getBadConfigExceptionExplanation(resources: Resources,
                                                 bce: BadConfigException): String {
        if (bce.cause is KeyFormatException) {
            val kfe = bce.cause as KeyFormatException?
            if (kfe!!.type == KeyFormatException.Type.LENGTH) return resources.getString(KFE_FORMAT_MAP.getValue(kfe.format))
        } else if (bce.cause is ParseException) {
            val pe = bce.cause as ParseException?
            if (pe!!.message != null) return ": ${pe.message}"
        } else if (bce.location == BadConfigException.Location.LISTEN_PORT) {
            return resources.getString(R.string.bad_config_explanation_udp_port)
        } else if (bce.location == BadConfigException.Location.MTU) {
            return resources.getString(R.string.bad_config_explanation_positive_number)
        } else if (bce.location == BadConfigException.Location.PERSISTENT_KEEPALIVE) {
            return resources.getString(R.string.bad_config_explanation_pka)
        }
        return ""
    }

    private fun getBadConfigExceptionReason(resources: Resources,
                                            bce: BadConfigException): String {
        if (bce.cause is KeyFormatException) {
            val kfe = bce.cause as KeyFormatException?
            return resources.getString(KFE_TYPE_MAP.getValue(kfe!!.type))
        } else if (bce.cause is ParseException) {
            val pe = bce.cause as ParseException?
            val type = resources.getString((if (PE_CLASS_MAP.containsKey(pe!!.parsingClass)) PE_CLASS_MAP[pe.parsingClass] else R.string.parse_error_generic)!!)
            return resources.getString(R.string.parse_error_reason, type, pe.text)
        }
        return resources.getString(BCE_REASON_MAP.getValue(bce.reason), bce.text)
    }

    private fun rootCause(throwable: Throwable): Throwable {
        var cause = throwable
        while (cause.cause != null) {
            if (cause is BadConfigException || cause is BackendException ||
                    cause is RootShellException) break
            val nextCause = cause.cause!!
            if (nextCause is RemoteException) break
            cause = nextCause
        }
        return cause
    }
}
