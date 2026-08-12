@file:Suppress("INVISIBLE_MEMBER", "INVISIBLE_REFERENCE")
@file:OptIn(InternalAdaptyApi::class)

package com.adapty.flutter

import android.content.Context
import android.view.View
import androidx.lifecycle.ViewModelStoreOwner
import com.adapty.internal.crossplatform.ui.Dependencies.safeInject
import com.adapty.internal.crossplatform.ui.OnboardingUiManager
import com.adapty.internal.utils.InternalAdaptyApi
import com.adapty.internal.utils.log
import com.adapty.ui.onboardings.AdaptyOnboardingView
import com.adapty.utils.AdaptyLogLevel.Companion.ERROR
import io.flutter.plugin.platform.PlatformView

internal class AdaptyOnboardingNativeView(
    context: Context,
    id: Int,
    args: Any?,
    private val viewModelStoreOwner: ViewModelStoreOwner,
) : PlatformView {
    private val onboardingUiManager: OnboardingUiManager? by safeInject<OnboardingUiManager>()

    private val onboardingView: AdaptyOnboardingView = AdaptyOnboardingView(context)
        .also { onboardingView ->
            val onboardingUiManager = onboardingUiManager ?: kotlin.run {
                log(ERROR, { "could not find onboardingUiManager" })
                return@also
            }
            onboardingUiManager.setupOnboardingView(onboardingView, viewModelStoreOwner, args, "flutter_native_$id")
        }

    override fun getView(): View {
        return onboardingView
    }

    override fun dispose() {
        onboardingUiManager?.clearOnboardingView(onboardingView)
    }
}
