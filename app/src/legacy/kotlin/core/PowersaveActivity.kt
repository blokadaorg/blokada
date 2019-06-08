package core

import androidx.appcompat.app.AppCompatActivity

/**
 * An invisible activity to get the app out of powersave limitations.
 *
 * When some devices, like Huawei, get into some kind of powersave mode, they start to block network
 * access causing the tunnel's send attempts to fail. Bringing up activity raises the app out of
 * those limitations. This activity is transparent and finishes immediately, to not be visible to
 * user. I couldn't find a nicer way to do this.
 */
class PowersaveActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        finish()
    }
}
