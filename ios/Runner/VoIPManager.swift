//
//  VoIPManager.swift
//  Runner
//
//  Created by arsenii on 18.07.2026.
//


import Foundation
import PushKit
import CallKit
import os
import UIKit
import Flutter

// Этот класс работает параллельно, не пересекается со Flutter и не ломает его плагины
class VoIPManager: NSObject, PKPushRegistryDelegate {
    
    static let shared = VoIPManager()
    private var voipRegistry: PKPushRegistry?
    
    func configureVoIP() {
        // Запускаем системный реестр VoIP звонков Apple
        self.voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        self.voipRegistry?.delegate = self
        self.voipRegistry?.desiredPushTypes = [.voIP]
    }
    
    // 1. СЮДА прилетит ваш правильный VoIP-токен для бэкенда
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        if let tokenData = pushCredentials.token as Data? {
            let tokenString = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
            // Скопируйте этот токен из консоли Xcode для вашего бэкенда!
            print("[VoIP-КЛЮЧ ДЛЯ БЭКЕНДА]: \(tokenString)")
        }
    }
    
    // 2. СЮДА прилетает звонок, и экран гарантированно откроется САМ и БЕЗ ТАПА
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        
        let userInfo = payload.dictionaryPayload
        let customData = userInfo["data"] as? [String: Any] ?? [:]
        let callerName = customData["caller_name"] as? String ?? "Входящий звонок"
        
        let callUUID = UUID()
        let providerConfiguration = CXProviderConfiguration(localizedName: "MGChat")
        providerConfiguration.supportsVideo = false
        
        let provider = CXProvider(configuration: providerConfiguration)
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        update.hasVideo = false
        
        provider.reportNewIncomingCall(with: callUUID, update: update) { error in
            completion()
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {}
}
