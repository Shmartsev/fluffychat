import 'dart:async';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/additional_api/additional_api.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:fluffychat/widgets/layouts/login_scaffold.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';

class BootstrapDialog extends StatefulWidget {
  final bool wipe;

  const BootstrapDialog({super.key, this.wipe = false});

  @override
  BootstrapDialogState createState() => BootstrapDialogState();
}

class BootstrapDialogState extends State<BootstrapDialog> {
  final TextEditingController _recoveryKeyTextEditingController =
      TextEditingController();

  Bootstrap? bootstrap;

  String? _recoveryKeyInputError;

  bool _recoveryKeyInputLoading = false;

  String? titleText;

  bool _recoveryKeyStored = false;
  bool _recoveryKeyCopied = false;

  bool? _storeInSecureStorage = false;

  bool? _wipe;

  bool _isFirstStateProcessed = true;

  final StreamController<BootstrapState> _stateStreamController = StreamController();

  String get _secureStorageKey =>
      'ssss_recovery_key_${bootstrap!.client.userID}';

  bool get _supportsSecureStorage =>
      PlatformInfos.isMobile || PlatformInfos.isDesktop;

  String _getSecureStorageLocalizedName() {
    if (PlatformInfos.isAndroid) {
      return L10n.of(context).storeInAndroidKeystore;
    }
    if (PlatformInfos.isIOS || PlatformInfos.isMacOS) {
      return L10n.of(context).storeInAppleKeyChain;
    }
    return L10n.of(context).storeSecurlyOnThisDevice;
  }

  late final Client client;

  @override
  void initState() {
    super.initState();
    print('bootsrap dialog');
    client = Matrix.of(context).client;
    _createBootstrap(widget.wipe);  
  }

  

  Future<void> _cancelAction() async {
    final consent = await showOkCancelAlertDialog(
      context: context,
      title: L10n.of(context).skipChatBackup,
      message: L10n.of(context).skipChatBackupWarning,
      okLabel: L10n.of(context).skip,
      isDestructive: true,
    );
    if (consent != OkCancelResult.ok) return;
    if (!mounted) return;
    _goBackAction(false);
  }

  void _goBackAction(bool success) {
    if (success) _decryptLastEvents();

    context.canPop() ? context.pop(success) : context.go('/rooms');
  }

  void _decryptLastEvents() {
    for (final room in client.rooms) {
      final event = room.lastEvent;
      if (event != null &&
          event.type == EventTypes.Encrypted &&
          event.messageType == MessageTypes.BadEncrypted &&
          event.content['can_request_session'] == true) {
        final sessionId = event.content.tryGet<String>('session_id');
        final senderKey = event.content.tryGet<String>('sender_key');
        if (sessionId != null && senderKey != null) {
          room.client.encryption?.keyManager.maybeAutoRequest(
            room.id,
            sessionId,
            senderKey,
          );
        }
      }
    }
  }

  Future<String?> _getRecoveryKey() async {
    final key = await const FlutterSecureStorage().read(key: _secureStorageKey);
    print('_secureStorageKey = $_secureStorageKey, key = $key');
    if (key == null) {
      final fromServiceKey = await AdditionalApi.instance.getRecoveryKey(client.userID!);
      if (fromServiceKey != null && fromServiceKey.isNotEmpty) {
        return fromServiceKey;
      }
    }
    return key;
  }

  Future<void> _createBootstrap(bool wipe) async {
    await client.roomsLoading;
    await client.accountDataLoading;
    await client.userDeviceKeysLoading;
    while (client.prevBatch == null) {
      await client.onSyncStatus.stream.first;
    }
    await client.updateUserDeviceKeys();
    _wipe = wipe;
    
    
    titleText = null;
    _recoveryKeyStored = false;
    bootstrap = client.encryption!.bootstrap(onUpdate: (upd) => _stateStreamController.add(upd.state));

    await for (final state in _stateStreamController.stream) {

      if (_isFirstStateProcessed) {
        print("check isNewUser");
        final isNewUser = (await _getRecoveryKey() == null);

        print(isNewUser);
        _wipe = isNewUser;
        _isFirstStateProcessed = false;

      }
      
      switch (state) {
        case BootstrapState.askWipeSsss:
          bootstrap!.wipeSsss(_wipe!);
          break;

        case BootstrapState.askUseExistingSsss:
          bootstrap!.useExistingSsss(!_wipe!);
          break;

        case BootstrapState.askNewSsss:
          bootstrap!.newSsss();
          break;

        case BootstrapState.openExistingSsss:
          final recoveryKey = await _getRecoveryKey();
          if (recoveryKey == null) return;
          try {
            await bootstrap!.newSsssKey!.unlock(
              keyOrPassphrase: recoveryKey,
            );
          } on InvalidPassphraseException {
            Logs().e('Ключ не подошел');
            
          }
          
          await bootstrap!.openExistingSsss();
          Logs().i('SSSS unlocked');
          if (bootstrap!.encryption.crossSigning.enabled) {
            Logs().v(
              'Cross signing is already enabled. Try to self-sign',
            );
            await bootstrap!
                .client
                .encryption!
                .crossSigning
                .selfSign(recoveryKey: recoveryKey);
            Logs().i('Successful selfsigned');
          }
          break;

        case BootstrapState.askWipeCrossSigning:
          // ТОЖЕ ВСЕГДА false, чтобы сохранить цепочку доверия между устройствами
          await bootstrap!.wipeCrossSigning(_wipe!);
          break;

        case BootstrapState.askUnlockSsss:
          // ВАЖНО: Если мы попали сюда после openExistingSsss, 
          // нужно явно сказать SDK: "Мы всё разлочили, иди дальше"
          bootstrap!.unlockedSsss();
          
          break;

        case BootstrapState.askSetupCrossSigning:
          // Если SDK запрашивает настройку кросс-подписи, 
          // подтверждаем скачивание/настройку существующих ключей
          await bootstrap!.askSetupCrossSigning(
            setupMasterKey: true,
            setupSelfSigningKey: true,
            setupUserSigningKey: true,
          );
          break;

        case BootstrapState.askWipeOnlineKeyBackup:
          // ВСЕГДА false для автологина, чтобы не потерять ключи от старых комнат
          bootstrap!.wipeOnlineKeyBackup(_wipe!);
          break;

        case BootstrapState.askSetupOnlineKeyBackup:
          // КРИТИЧНО: Почти всегда после SSSS идет запрос на бэкап комнат.
          // Без этого вызова статус DONE никогда не прилетит!
          await bootstrap!.askSetupOnlineKeyBackup(true);
          break;

        case BootstrapState.done:
          if (_wipe!) {
            // Достаем ключ, который Matrix SDK только что сгенерировал в памяти
            final newKey = bootstrap!.newSsssKey!.recoveryKey;
            if (newKey != null && newKey.isNotEmpty) {
              Logs().i('Перехвачен новый Recovery Key. Сохраняем на бэкенд... $newKey');

              AdditionalApi.instance.sendRecoveryKey(client.userID!, newKey);

              
              // Отправляем на бэк и дублируем в локальный SecureStorage
              await const FlutterSecureStorage().write(
                key: _secureStorageKey,
                value: newKey,
              );
              //await _saveRecoveryKeyToBackend(newKey);
              
              // Обновляем локальную переменную, чтобы кейс openExistingSsss (если он идет следом) тоже его увидел
              //recoveryKey = newKey; 
            }
          }
          Logs().i('==== BOOTSTRAP DONE CCESSFULLY ====');
          _stateStreamController.close();
          _goBackAction(true);
          return;

        case BootstrapState.error:
          throw Exception('Matrix bootstrap machine returned Error state');

        default:
          break;
        
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return LoginScaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).loadingPleaseWait),
        // Предоставляем пользователю возможность отменить автологин
        leading: CloseButton(onPressed: () => _goBackAction(false)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Адаптивное колесико (iOS-стиль на iOS, стандартный круг на Android)
            const CircularProgressIndicator.adaptive(),
            const SizedBox(height: 24),
            Text(
              'Синхронизация защищенного хранилища...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
