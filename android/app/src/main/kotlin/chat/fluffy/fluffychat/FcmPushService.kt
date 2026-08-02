package chat.fluffy.fluffychat

import com.famedly.fcm_shared_isolate.FcmSharedIsolateService

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint
import android.content.Context

import android.os.Handler
import android.os.Looper
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugin.common.MethodChannel
import java.util.HashMap

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import android.os.PowerManager
import androidx.core.app.Person

class FcmPushService : FcmSharedIsolateService() {
    override fun getEngine(): FlutterEngine {
        return provideEngine(getApplicationContext())
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data

        // 1. Проверяем, является ли пуш приглашением в звонок LiveKit
        if (data["type"] == "livekit_call_invite") {
            val roomId = data["room_name"] ?: ""
            val callerName = data["caller_name"] ?: "Входящий звонок"

            showNativeIncomingCallNotification(callerName, roomId)

            // 2. Переключаемся на главный поток Android
            Handler(Looper.getMainLooper()).post {
                // Извлекаем binaryMessenger текущего фонового движка Famedly
                val messenger = getEngine().dartExecutor.binaryMessenger
                
                // Создаем ТОТ ЖЕ САМЫЙ MethodChannel, который мы слушаем в Dart!
                val channel = MethodChannel(messenger, "com.mgchat/voip")

                // Упаковываем аргументы для передачи
                val arguments = HashMap<String, String>()
                arguments["room_id"] = roomId
                arguments["caller_name"] = callerName
                //arguments["data"] = data

                // Выстреливаем метод прямо в существующий фоновый Dart-изолят пакета!
                channel.invokeMethod("onIncomingCallPushAndroid", arguments)
            }
            return // Выходим, чтобы Famedly не обрабатывал звонок как обычное сообщение чата
        }

        // 3. Если это обычный пуш сообщения чата, отдаем его базовому классу Famedly
        super.onMessageReceived(message)
    }

    private fun showNativeIncomingCallNotification(callerName: String, roomId: String) {
        val context = applicationContext

        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!powerManager.isInteractive) { // Если экран выключен
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                        PowerManager.ACQUIRE_CAUSES_WAKEUP or
                        PowerManager.ON_AFTER_RELEASE,
                "MGChat:IncomingCallWakeLock"
            )
            // Включаем экран на 10 секунд (пока идет вызов)
            wakeLock.acquire(10000)
        }

        // Intent, который запустит/развернет вашу MainActivity
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "ACTION_INCOMING_CALL"
            putExtra("room_id", roomId)
            putExtra("caller_name", callerName)
            // Флаги пробивают заблокированный экран и поднимают инстанс
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val acceptIntent = Intent(context, MainActivity::class.java).apply {
            action = "ACTION_INCOMING_CALL"
            putExtra("room_id", roomId)
            putExtra("caller_name", callerName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val acceptPendingIntent = PendingIntent.getActivity(
            context,
            1001,
            acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 2. Intent для отклонения звонка (закрывает плашку)
        val declineIntent = Intent(context, CallNotificationReceiver::class.java).apply {
            action = "ACTION_DECLINE_CALL"
            putExtra("room_id", roomId)
            putExtra("caller_name", callerName)
            putExtra("notification_id", 1001)
        }

        val declinePendingIntent = PendingIntent.getBroadcast(
            context,
            1002,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val channelId = "voip_calls_v5"
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Создаем High Priority канал для вызовов
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            val channel = NotificationChannel(
                channelId,
                "Входящие вызовы",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Канал для полноэкранных звонков"
                setSound(
                    ringtoneUri,
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                enableVibration(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }

        val caller = Person.Builder()
            .setName(callerName)
            .setImportant(true)
            .build()

        // Собираем звонковое уведомление
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher) // Замените на вашу иконку
            .setContentIntent(acceptPendingIntent)
            //.setContentTitle("Входящий вызов")
            //.setContentText("$callerName звонит вам")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            // Магия WhatsApp: нативный PendingIntent открывает полноэкранный UI без блокировок
            .setFullScreenIntent(acceptPendingIntent, true)
            .setStyle(
                NotificationCompat.CallStyle.forIncomingCall(caller, declinePendingIntent, acceptPendingIntent)
            )
            .addPerson(caller)
            //.addAction(
            //    R.mipmap.ic_launcher, // Иконка кнопки (можно заменяться на свою)
            //    "Отклонить",
            //    declinePendingIntent
            //)
            //.addAction(
            //    R.mipmap.ic_launcher,
            //    "Ответить",
            //    acceptPendingIntent
            //)

        notificationManager.notify(1001, builder.build())
    }

    companion object {
        fun provideEngine(context: Context): FlutterEngine {
            var engine = MainActivity.engine
            if (engine == null) {
                engine = MainActivity.provideEngine(context)
                engine.getLocalizationPlugin().sendLocalesToFlutter(
                    context.getResources().getConfiguration())
                engine.getDartExecutor().executeDartEntrypoint(
                    DartEntrypoint.createDefault())
            }
            return engine
        }
    }
}
