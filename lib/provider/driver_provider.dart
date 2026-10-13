import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DriverProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;

  DriverProvider({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  bool _isUpdating = false;
  bool get isUpdating => _isUpdating;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> toggleBlockStatus({
    required String driverId,
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
      final driverReference = _firestore
          .collection('drivers')
          .doc(driverId);

      final driverSnapshot = await driverReference.get();

      if (!driverSnapshot.exists) {
        _errorMessage = 'راننده موردنظر یافت نشد.';
        return false;
      }

      final driverData = driverSnapshot.data() ?? {};
      final isApproved = _isApproved(driverData);

      await driverReference.update({
        'isBlocked': newBlocked,
        'blockStatus': newBlocked ? 'yes' : 'no',
        'status': newBlocked
            ? 'blocked'
            : (isApproved ? 'approved' : 'pending'),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } on FirebaseException catch (error) {
      debugPrint(
        'Firestore error while updating driver block status: '
        '${error.code} - ${error.message}',
      );

      _errorMessage = error.message ?? error.code;
      return false;
    } catch (error) {
      debugPrint(
        'Unknown error while updating driver block status: $error',
      );

      _errorMessage = error.toString();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  bool _isApproved(Map<String, dynamic> data) {
    final value = data['isApproved'] ?? data['status'];

    return value == true ||
        value.toString().trim().toLowerCase() == 'approved';
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
