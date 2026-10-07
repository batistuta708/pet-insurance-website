import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/models.dart';

/// Holds who is signed in and keeps the token in secure storage.
class Session extends ChangeNotifier {
  Session({required this.api, FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final ApiClient api;
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'auth_token';

  User? user;
  bool restoring = true;

  bool get isLoggedIn => user != null;

  /// Called once at start-up: signs the user back in if a valid token was saved.
  Future<void> restore() async {
    try {
      final saved = await _storage.read(key: _tokenKey);
      if (saved != null) {
        api.token = saved;
        user = await api.me();
      }
    } on ApiException catch (e) {
      api.token = null;
      if (e.isUnauthorized) await _storage.delete(key: _tokenKey);
    } catch (_) {
      api.token = null;
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async =>
      _signIn(await api.login(email, password));

  Future<void> register(String email, String password) async =>
      _signIn(await api.register(email, password));

  Future<void> _signIn(AuthResult result) async {
    api.token = result.token;
    user = result.user;
    await _storage.write(key: _tokenKey, value: result.token);
    notifyListeners();
  }

  Future<void> logout() async {
    api.token = null;
    user = null;
    await _storage.delete(key: _tokenKey);
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await api.deleteAccount();
    await logout();
  }
}

/// Makes the [Session] available to every screen, including pushed routes.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({super.key, required Session session, required super.child})
      : super(notifier: session);

  /// Use in build methods: rebuilds the widget when the session changes.
  static Session of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;

  /// Use in callbacks (onPressed etc.): no rebuild subscription.
  static Session read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}
