import Foundation
import PushKit
import CallKit
import os
import Flutter
// Обязательно импортируем Flutter для каналов

class VoIPManager: NSObject, PKPushRegistryDelegate, CXProviderDelegate {
    
    static let shared = VoIPManager()
    private var voipRegistry: PKPushRegistry?
    private var provider: CXProvider?
    var backgroundMessenger: FlutterBinaryMessenger? {
        didSet {
            guard let messenger = backgroundMessenger else { return }
            let channel = FlutterMethodChannel(name: "com.mgchat/voip", binaryMessenger: messenger)
            
            // Вот этот недостающий мост, который запускает ваш handleMethodCall!
            channel.setMethodCallHandler { [weak self] (call, result) in
                self?.handleMethodCall(call, result: result)
            }
        }
    }

    private var currentCallUUID: UUID?
    private let callController = CXCallController()
    
    func configureVoIP() {
        self.voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        self.voipRegistry?.delegate = self
        self.voipRegistry?.desiredPushTypes = [.voIP]
        
        // Правильный инициализатор iOS 10+
        let providerConfiguration = CXProviderConfiguration(localizedName: "MGChat")
        providerConfiguration.supportsVideo = false
        
        self.provider = CXProvider(configuration: providerConfiguration)
        self.provider?.setDelegate(self, queue: nil)
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        if let tokenData = pushCredentials.token as Data? {
            let tokenString = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
            DispatchQueue.main.async {
                if let messenger = self.backgroundMessenger {
                    let channel = FlutterMethodChannel(name: "com.mgchat/voip", binaryMessenger: messenger)
                    channel.invokeMethod("onVoIPTokenReceived", arguments: tokenString)
                }
            }
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        
        let userInfo = payload.dictionaryPayload as? [String: Any] ?? [:]
        let customData = userInfo["data"] as? [String: Any] ?? [:]
        let callerName = customData["caller_name"] as? String ?? "Входящий звонок"

        let roomId = userInfo["room"] as? String ?? "unknown_room"
        UserDefaults.standard.set(roomId, forKey: "last_incoming_room_id")
        UserDefaults.standard.set(callerName, forKey: "last_incoming_caller_name")
        let callUUID = UUID()
        
        self.currentCallUUID = callUUID

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        update.hasVideo = false
        
        // 1. Показываем нативный экран звонка
        self.provider?.reportNewIncomingCall(with: callUUID, update: update) { error in
            
            // 2. ОТПРАВЛЯЕМ МЕССЕДЖ В DART ИЗОЛЯТ
            DispatchQueue.main.async {
                // Берем мессенджер фонового движка из AppDelegate
                if let messenger = self.backgroundMessenger {
                    let channel = FlutterMethodChannel(name: "com.mgchat/voip", binaryMessenger: messenger)
                    // Выплескиваем сырой JSON пуша прямо в ваш пакет!
                    channel.invokeMethod("onIncomingCallPush", arguments: userInfo)
                }
                completion()
            }
        }
    }
    
    func providerDidReset(_ provider: CXProvider) {}
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {}
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // Достаем roomId, который мы сохранили в кэш при получении пуша (Шаг 2 ниже)
        let roomId = UserDefaults.standard.string(forKey: "last_incoming_room_id") ?? ""
        let callerName = UserDefaults.standard.string(forKey: "last_incoming_caller_name") ?? "Неизвестный"
        let userInfo: [String: Any] = ["room_id": roomId, "caller_name": callerName]

        DispatchQueue.main.async {
            if let messenger = self.backgroundMessenger {
                let channel = FlutterMethodChannel(name: "com.mgchat/voip", binaryMessenger: messenger)
                // Отправляем во Flutter четкий сигнал: пользователь поднял трубку!
                channel.invokeMethod("onCallAccepted", arguments: userInfo)
            }
        }
        action.fulfill() // Сообщаем системе iOS, что действие выполнено успешно
    }
    
    // 2. Срабатывает, когда пользователь НАЖАЛ КРАСНУЮ КНОПКУ "ОТКЛОНИТЬ"
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        DispatchQueue.main.async {
            if let messenger = self.backgroundMessenger {
                let channel = FlutterMethodChannel(name: "com.mgchat/voip", binaryMessenger: messenger)
                // Отправляем во Flutter сигнал отмены
                channel.invokeMethod("onCallDeclined", arguments: nil)
            }
        }
        action.fulfill()
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            
        case "setConnectedSuccessfully":
            // 1. Убираем надпись "Соединение" и запускаем таймер разговора звонка Apple
            if let uuid = self.currentCallUUID {
                self.provider?.reportOutgoingCall(with: uuid, connectedAt: nil)
                os_log("[VoIP Swift] Сигнал успешного соединения LiveKit передан в CallKit")
            }
            result(nil)
            
        case "endCallFromDart":
            // 2. Бэкенд прислал отмену звонка (или пользователь повесил трубку в кастомном UI)
            if let uuid = self.currentCallUUID {
                let endCallAction = CXEndCallAction(call: uuid)
                let transaction = CXTransaction(action: endCallAction)
                callController.request(transaction) { error in
                    if let error = error {
                        os_log("[VoIP Swift] Ошибка завершения звонка: %{public}@", error.localizedDescription)
                    }
                }
                self.currentCallUUID = nil
            }
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
