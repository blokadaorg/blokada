@file:Suppress("INVISIBLE_MEMBER", "INVISIBLE_REFERENCE")
@file:OptIn(InternalAdaptyApi::class)

package com.adapty.flutter

import android.content.Context
import android.view.View
import androidx.lifecycle.ViewModelStoreOwner
import com.adapty.internal.crossplatform.ui.Dependencies.safeInject
import com.adapty.internal.crossplatform.ui.FlowUiManager
import com.adapty.internal.utils.InternalAdaptyApi
import com.adapty.internal.utils.log
import com.adapty.ui.AdaptyFlowView
import com.adapty.utils.AdaptyLogLevel.Companion.ERROR
import io.flutter.plugin.platform.PlatformView

internal class AdaptyFlowNativeView(
    context: Context,
    id: Int,
    args: Any?,
    private val viewModelStoreOwner: ViewModelStoreOwner,
) : PlatformView {
    private val flowUiManager: FlowUiManager? by safeInject<FlowUiManager>()

    private val flowView: AdaptyFlowView = AdaptyFlowView(context)
        .also { flowView ->
            val flowUiManager = flowUiManager ?: kotlin.run {
                log(ERROR, { "could not find flowUiManager" })
                return@also
            }
            flowUiManager.setupFlowView(flowView, viewModelStoreOwner, args, "flutter_native_$id")
        }

    override fun getView(): View {
        return flowView
    }

    override fun dispose() {
        flowUiManager?.clearFlowView(flowView)
    }
}
