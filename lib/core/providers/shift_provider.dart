import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_provider.dart';

class ShiftProvider extends ChangeNotifier {
  bool _isShiftActive = false;
  String? _startTime;
  String? _activeShiftId;
  bool _isProcessing = false;

  bool get isShiftActive => _isShiftActive;
  String? get startTime => _startTime;
  bool get isProcessing => _isProcessing;

  void setShiftStatus(bool isActive, {String? shiftId, String? startTime}) {
    _isShiftActive = isActive;
    if (shiftId != null) _activeShiftId = shiftId;
    if (startTime != null) _startTime = startTime;
    notifyListeners();
  }

  Future<bool> startShift(AuthProvider auth) async {
    if (auth.tenantId == null || auth.outletId == null) return false;
    _isProcessing = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse(
          'https://backend-pos-508482854424.us-central1.run.app/api/cash-shifts',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': auth.sessionCookie ?? '',
        },
        body: json.encode({
          "tenantId": auth.tenantId,
          "outletId": auth.outletId,
          "jumlahBuka": "0",
          "status": "buka",
          "catatan": "Shift started",
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = json.decode(response.body);
        _activeShiftId = resData['data']['id'].toString();
        _isShiftActive = true;
        _startTime = DateFormat('HH.mm.ss').format(DateTime.now());
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<bool> stopShift(
    AuthProvider auth,
    Map<String, dynamic> closingData,
  ) async {
    if (_activeShiftId == null) return false;
    _isProcessing = true;
    notifyListeners();
    try {
      final response = await http.put(
        Uri.parse(
          'https://backend-pos-508482854424.us-central1.run.app/api/cash-shifts/$_activeShiftId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': auth.sessionCookie ?? '',
        },
        body: json.encode({
          "jumlahTutup": closingData['jumlahTutup'].toString(),
          "jumlahExpected": closingData['jumlahExpected'].toString(),
          "selisih": closingData['selisih'].toString(),
          "status": "tutup",
          "waktuTutup": DateTime.now().toIso8601String(),
          "catatan": closingData['catatan'] ?? "",
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _isShiftActive = false;
        _startTime = null;
        _activeShiftId = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
