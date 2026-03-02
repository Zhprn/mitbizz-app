import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ShiftProvider extends ChangeNotifier {
  bool _isShiftActive = false;
  String? _startTime;

  bool get isShiftActive => _isShiftActive;
  String? get startTime => _startTime;

  void toggleShift() {
    _isShiftActive = !_isShiftActive;
    if (_isShiftActive) {
      _startTime = DateFormat('HH.mm.ss').format(DateTime.now());
    } else {
      _startTime = null;
    }
    notifyListeners();
  }
}
