package chat.fluffy.fluffychat

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class CallNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "ACTION_DECLINE_CALL") {
            val notificationId = intent.getIntExtra("notification_id", 1001)
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)

            // Передаем обработку единой логике
            CallIntentHandler.handleIntent(context, intent)
        }
        // if (intent.action == "ACTION_DECLINE_CALL") {
        //     val notificationId = intent.getIntExtra("notification_id", 1001)
        //     val roomId = intent.getStringExtra("room_id") ?: ""
        //     val callerName = intent.getStringExtra("caller_name") ?: ""
        //     val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        //     notificationManager.cancel(notificationId)
        //     
        //     
        //     Handler(Looper.getMainLooper()).post {
        //         try {
        //             // Пытаемся получить активный главный движок Flutter
        //             val engine = FcmPushService.provideEngine(context.applicationContext)
        //             //FlutterEngineCache.getInstance().get("main_engine") 
        //             if (engine != null) {
        //                 val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.mgchat/voip")
        //                 val args = mapOf("room_id" to roomId, "event" to "decline", "caller_name" to callerName)
        //                 channel.invokeMethod("onCallAction", args)
        //             }
        //         } catch (e: Exception) {
        //             e.printStackTrace()
        //         }
        //     }
        // }
    }
}