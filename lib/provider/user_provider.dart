import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;

  UserProvider({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  bool _isUpdating = false;
  bool get isUpdating => _isUpdating;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> toggleBlockStatus({
    required String userId,
    required bool currentBlocked,
  }) async {
    if (_isUpdating) {
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    final newBlocked = !currentBlocked;

    try {
      final userReference = _firestore.collection('users').doc(userId);
      final userSnapshot = await userReference.get();

      if (!userSnapshot.exists) {
        _errorMessage = 'کاربر موردنظر یافت نشد.';
        return false;
      }

      final userData = userSnapshot.data() ?? {};
      final previousStatus = _readText(
        userData,
        [
          'status',
          'accountStatus',
          'account_status',
        ],
        fallback: 'active',
      );

      await userReference.update({
        'blockStatus': newBlocked ? 'yes' : 'no',
        'isBlocked': newBlocked,
        'status': newBlocked
            ? 'blocked'
            : _restoreStatus(previousStatus),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } on FirebaseException catch (error) {
      debugPrint(
        'Firestore error while changing user block status: '
        '${error.code} - ${error.message}',
      );

      _errorMessage = error.message ?? error.code;
      return false;
    } catch (error) {
      debugPrint(
        'Unknown error while changing user block status: $error',
      );

      _errorMessage = error.toString();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  String _restoreStatus(String previousStatus) {
    final normalized = previousStatus.trim().toLowerCase();

    if (normalized.isEmpty || normalized == 'blocked') {
      return 'active';
    }

    return previousStatus;
  }

  String _readText(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is num || value is bool) {
        return value.toString();
      }
    }

    return fallback;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
