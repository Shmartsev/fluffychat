package chat.fluffy.fluffychat

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationManager

object CallIntentHandler {
    private const val CHANNEL_NAME = "com.mgchat/voip"

    fun handleIntent(context: Context, intent: Intent?): Boolean {
        if (intent == null) return false

        val action = intent.action
        if (action == "ACTION_INCOMING_CALL" || action == "ACTION_DECLINE_CALL") {
            val notificationId = intent.getIntExtra("notification_id", 1001)
            val roomId = intent.getStringExtra("room_id") ?: ""
            val callerName = intent.getStringExtra("caller_name") ?: ""
            val event = if (action == "ACTION_INCOMING_CALL") "accept" else "decline"
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)

            val args = mapOf(
                "event" to event,
                "room_id" to roomId,
                "caller_name" to callerName
            )

            // Отправляем событие прямо через изолят FCM
            try {
                val engine = FcmPushService.provideEngine(context)
                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
                channel.invokeMethod("onCallAction", args)
            } catch (e: Exception) {
                e.printStackTrace()
            }
            return true
        }
        return false
    }
}