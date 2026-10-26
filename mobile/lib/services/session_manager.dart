import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../utils/database_helper.dart';

class SessionManager {
  static final SessionManager instance = SessionManager._internal();
  SessionManager._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ValueNotifier<UserAccount?> currentUserNotifier = ValueNotifier<UserAccount?>(null);

  UserAccount? get currentUser => currentUserNotifier.value;
  bool get isLoggedIn => currentUserNotifier.value != null;

  bool get isAdmin => currentUser?.isAdmin ?? false;
  bool get isManager => currentUser?.isManager ?? false;
  bool get isCashier => currentUser?.isCashier ?? false;
  bool get isWaiter => currentUser?.isWaiter ?? false;
  bool get isKitchen => currentUser?.isKitchen ?? false;
  bool get isStaff => currentUser?.isStaff ?? false;
  bool get isMember => currentUser?.isMember ?? false;

  Future<void> initialize() async {
    try {
      final sessionMap = await _dbHelper.getCurrentSession();
      if (sessionMap != null) {
        currentUserNotifier.value = UserAccount.fromMap(sessionMap);
      } else {
        currentUserNotifier.value = null;
      }
    } catch (_) {
      currentUserNotifier.value = null;
    }
  }

  Future<void> setSession(UserAccount user) async {
    await _dbHelper.saveUserSession(user.toMap());
    currentUserNotifier.value = user;
  }

  Future<void> logout() async {
    await _dbHelper.clearUserSession();
    currentUserNotifier.value = null;
  }
}
