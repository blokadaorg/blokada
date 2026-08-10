package com.adapty.flutter

import android.content.Context
import androidx.lifecycle.ViewModelStoreOwner
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class AdaptyFlowNativeViewFactory(
    private val viewModelStoreOwner: ViewModelStoreOwner,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return AdaptyFlowNativeView(context, viewId, args, viewModelStoreOwner)
    }
}
