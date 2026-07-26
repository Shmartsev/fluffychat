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
