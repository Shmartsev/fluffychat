package chat.fluffy.fluffychat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

import android.content.Context

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.content.Intent

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        CallIntentHandler.handleIntent(this, intent)
        // Разрешаем показывать окно поверх замка экрана
        // if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
        //     setShowWhenLocked(true)
        //     setTurnScreenOn(true)
        // } else {
        //     window.addFlags(
        //         WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
        //         WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
        //         WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        //     )
        // }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        CallIntentHandler.handleIntent(this, intent)
    }

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
    }


    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return provideEngine(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // do nothing, because the engine was been configured in provideEngine
    }

    companion object {
        var engine: FlutterEngine? = null
        fun provideEngine(context: Context): FlutterEngine {
            val eng = engine ?: FlutterEngine(context, emptyArray(), true, false)
            engine = eng
            return eng
        }
    }
}
