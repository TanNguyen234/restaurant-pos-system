import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
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
  bool get isChef => currentUser?.isChef ?? false;
  bool get isKitchen => currentUser?.isKitchen ?? false;
  bool get isStaff => currentUser?.isStaff ?? false;
  bool get isMember => currentUser?.isMember ?? false;

  Future<void> initialize() async {
    try {
      await _dbHelper.initWebPersistence();
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

  Future<void> updateLoyaltyPoints(int points) async {
    final current = currentUserNotifier.value;
    if (current == null || current.loyaltyPoints == points) return;
    final updated = current.copyWith(loyaltyPoints: points);
    currentUserNotifier.value = updated;
    await _dbHelper.saveUserSession(updated.toMap());
  }

  Future<void> logout() async {
    await AuthRepository().logout();
    currentUserNotifier.value = null;
  }
}
