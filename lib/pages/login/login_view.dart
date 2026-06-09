import 'package:fluffychat/utils/additional_api/additional_api.dart';
import 'package:fluffychat/widgets/layouts/login_scaffold.dart';
import 'package:fluffychat/widgets/matrix.dart'; // Нужен для cachedPassword
import 'package:flutter/material.dart';

import 'login.dart';

typedef LoginArgs = ({String login, String password});

// Используем Stateful-виджет внутри View для локального переключения шага SMS (телефон/код)
class LoginView extends StatefulWidget {
  final LoginController controller;

  const LoginView(this.controller, {super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _smsSent = false;
  bool _localLoading = false; // Лоадер для запросов к твоему бэкенду
  String? _customError;

  // Шаг 1: Отправка телефона на твой бэк
  Future<void> _sendPhone() async {
    setState(() {
      _localLoading = true;
      _customError = null;
    });

    try {
      // Твой вызов к бэкенду для отправки СМС
      await AdditionalApi.instance.sendSmsCode(_phoneController.text.trim());
      
      setState(() {
        _smsSent = true;
      });
    } catch (e) {
      setState(() {
        _customError = 'Ошибка отправки SMS';
      });
    } finally {
      setState(() {
        _localLoading = false;
      });
    }
  }

  // Шаг 2: Проверка кода на бэке + заполнение контроллера FluffyChat
  Future<void> _verifyCodeAndSubmit() async {
    setState(() {
      _localLoading = true;
      _customError = null;
    });

    try {
      // Твой вызов к бэкенду для проверки кода
      final credentials = await AdditionalApi.instance.verifySmsCode(
        phone: _phoneController.text.trim(),
        code: _codeController.text.trim(),
      ) as LoginArgs;
      
      final matrixUser = credentials.login; // "@user_79219397820:matrix.medgarant-spb.ru";
      final matrixPassword =  credentials.password; // "xerHn0djeb7*m0yi";

      // 1. Записываем пароль в MatrixState для обхода Bootstrap
      if (mounted) {
        Matrix.of(context).cachedPassword = matrixPassword;
      }

      // 2. Магия: подсовываем данные прямо в контроллеры оригинального LoginController
      widget.controller.usernameController.text = matrixUser;
      widget.controller.passwordController.text = matrixPassword;

      // 3. Запускаем нативную логику логина мессенджера
      widget.controller.login();

    } catch (e) {
      setState(() {
        _customError = 'Неверный код или ошибка авторизации';
      });
    } finally {
      setState(() {
        _localLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Объединяем лоадер твоего бэка и лоадер оригинального контроллера Matrix
    final isAnyLoading = _localLoading || widget.controller.loading;

    // Берем ошибку либо из нашей логики, либо из Matrix (если пароль не подошел)
    final displayError = _customError ?? widget.controller.usernameError ?? widget.controller.passwordError;

    return LoginScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isAnyLoading,
        titleSpacing: !isAnyLoading ? 0 : null,
        title: const Text('Авторизация'), // Или твой кастомный тайтл
      ),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: <Widget>[
            Hero(
              tag: 'info-logo',
              child: Image.asset('assets/banner_transparent.png'),
            ),
            const SizedBox(height: 16),
            
            if (displayError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  displayError,
                  style: const TextStyle(color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
              ),
            
            const SizedBox(height: 16),

            if (!_smsSent) ...[
              // Поле ввода Номера Телефона
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: TextField(
                  readOnly: isAnyLoading,
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '+7 (999) 999-99-99',
                    labelText: 'Номер телефона',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  onPressed: isAnyLoading ? null : _sendPhone,
                  child: isAnyLoading
                      ? const LinearProgressIndicator()
                      : const Text('Получить код'),
                ),
              ),
            ] else ...[
              // Поле ввода SMS-кода
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: TextField(
                  readOnly: isAnyLoading,
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_outlined),
                    hintText: '123456',
                    labelText: 'Код подтверждения',
                  ),
                  onSubmitted: (_) => isAnyLoading ? null : _verifyCodeAndSubmit(),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  onPressed: isAnyLoading ? null : _verifyCodeAndSubmit,
                  child: isAnyLoading
                      ? const LinearProgressIndicator()
                      : const Text('Войти'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: isAnyLoading ? null : () => setState(() => _smsSent = false),
                child: const Text('Изменить номер телефона'),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// import 'package:fluffychat/l10n/l10n.dart';
// import 'package:fluffychat/widgets/layouts/login_scaffold.dart';
// import 'package:flutter/material.dart';

// import 'login.dart';

// class LoginView extends StatelessWidget {
//   final LoginController controller;

//   const LoginView(this.controller, {super.key});

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     final homeserver = controller.widget.client.homeserver
//         ?.toString()
//         .replaceFirst('https://', '');
//     final title = homeserver == null
//         ? L10n.of(context).loginWithMatrixId
//         : L10n.of(context).logInTo(homeserver);

//     return LoginScaffold(
//       appBar: AppBar(
//         leading: null, // controller.loading ? null : const Center(child: BackButton()),
//         automaticallyImplyLeading: !controller.loading,
//         titleSpacing: !controller.loading ? 0 : null,
//         title: Text(title),
//       ),
//       body: Builder(
//         builder: (context) {
//           return AutofillGroup(
//             child: ListView(
//               padding: const EdgeInsets.symmetric(horizontal: 8),
//               children: <Widget>[
//                 Hero(
//                   tag: 'info-logo',
//                   child: Image.asset('assets/banner_transparent.png'),
//                 ),
//                 const SizedBox(height: 16),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 24.0),
//                   child: TextField(
//                     readOnly: controller.loading,
//                     autocorrect: false,
//                     autofocus: true,
//                     onChanged: controller.checkWellKnownWithCoolDown,
//                     controller: controller.usernameController,
//                     textInputAction: TextInputAction.next,
//                     keyboardType: TextInputType.emailAddress,
//                     autofillHints: controller.loading
//                         ? null
//                         : [AutofillHints.username],
//                     decoration: InputDecoration(
//                       prefixIcon: const Icon(Icons.account_box_outlined),
//                       errorText: controller.usernameError,
//                       errorStyle: const TextStyle(color: Colors.orange),
//                       hintText: '@username:domain',
//                       labelText: L10n.of(context).matrixId,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 24.0),
//                   child: TextField(
//                     readOnly: controller.loading,
//                     autocorrect: false,
//                     autofillHints: controller.loading
//                         ? null
//                         : [AutofillHints.password],
//                     controller: controller.passwordController,
//                     textInputAction: TextInputAction.go,
//                     obscureText: !controller.showPassword,
//                     onSubmitted: (_) => controller.login(),
//                     decoration: InputDecoration(
//                       prefixIcon: const Icon(Icons.lock_outlined),
//                       errorText: controller.passwordError,
//                       errorStyle: const TextStyle(color: Colors.orange),
//                       suffixIcon: IconButton(
//                         onPressed: controller.toggleShowPassword,
//                         icon: Icon(
//                           controller.showPassword
//                               ? Icons.visibility_off_outlined
//                               : Icons.visibility_outlined,
//                           color: Colors.black,
//                         ),
//                       ),
//                       hintText: '******',
//                       labelText: L10n.of(context).password,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 24.0),
//                   child: ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: theme.colorScheme.primary,
//                       foregroundColor: theme.colorScheme.onPrimary,
//                     ),
//                     onPressed: controller.loading ? null : controller.login,
//                     child: controller.loading
//                         ? const LinearProgressIndicator()
//                         : Text(L10n.of(context).login),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 if (homeserver != null)
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 24.0),
//                     child: TextButton(
//                       onPressed: controller.loading
//                           ? () {}
//                           : controller.passwordForgotten,
//                       style: TextButton.styleFrom(
//                         foregroundColor: theme.colorScheme.error,
//                       ),
//                       child: Text(L10n.of(context).passwordForgotten),
//                     ),
//                   ),
//                 const SizedBox(height: 16),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
