import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class ApiService {
  static const String baseUrl = 'http://192.168.0.173:8000';
static const String aiBaseUrl = 'http://192.168.0.173:8001';
static const String wsUrl = 'ws://192.168.0.173:8000/ws/gold';

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  int? activeUserId;

  int _requireUser() {
    final id = activeUserId;
    if (id == null) throw Exception('يجب تسجيل الدخول أولاً');
    return id;
  }

  WebSocketChannel? _goldChannel;
  final StreamController<Map<String, dynamic>> _goldStreamController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get goldPriceStream => _goldStreamController.stream;

  void connectToGoldWebSocket() {
    try {
      _goldChannel?.sink.close(status.goingAway);
      _goldChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _goldChannel!.stream.listen(
            (message) {
          final data = jsonDecode(message);
          if (data['type'] == 'gold_update') {
            _goldStreamController.add(Map<String, dynamic>.from(data['data']));
          }
        },
        onError: (error) {
          debugPrint('❌ WebSocket Error: $error');
          _reconnect();
        },
        onDone: () => _reconnect(),
        cancelOnError: true,
      );
    } catch (e) {
      _reconnect();
    }
  }

  void _reconnect() {
    if (_goldStreamController.hasListener) {
      Future.delayed(const Duration(seconds: 5), () => connectToGoldWebSocket());
    }
  }

  void disconnectWebSocket() {
    _goldChannel?.sink.close(status.normalClosure);
  }

  Future<dynamic> _handleGetRequest(String path) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$path'));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('خطأ في السيرفر: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> _handlePostRequest(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw errorData['detail'] ?? 'حدث خطأ أثناء معالجة الطلب';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getUsers() async => await _handleGetRequest('/users/');

  Future<Map<String, dynamic>> login(String phoneNumber, String password) async {
    return Map<String, dynamic>.from(await _handlePostRequest('/users/login', {
      'phone_number': phoneNumber,
      'password': password,
    }));
  }

  Future<Map<String, dynamic>> register(String name, String phoneNumber, String password) async {
    return Map<String, dynamic>.from(await _handlePostRequest('/users/', {
      'name': name,
      'phone_number': phoneNumber,
      'password': password,
    }));
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final id = activeUserId;
    if (id == null) throw Exception('لم يتم تسجيل الدخول');
    return Map<String, dynamic>.from(await _handleGetRequest('/users/$id'));
  }

  Future<Map<String, dynamic>> getWallet() async { final id = _requireUser(); return await _handleGetRequest('/wallet/?user_id=$id'); }

  Future<List<dynamic>> getTransactions() async { final id = _requireUser(); return await _handleGetRequest('/transactions/?user_id=$id'); }

  Future<Map<String, dynamic>> getSavingsBalance() async { final id = _requireUser(); return await _handleGetRequest('/savings/balance?user_id=$id'); }

  Future<void> addSavingsTransaction(double amount, bool isDeposit) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/savings/transaction?user_id=${_requireUser()}'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'amount': amount,
          'is_deposit': isDeposit,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ تمت العملية بنجاح: ${isDeposit ? "إيداع" : "سحب"}');
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw errorData['detail'] ?? 'حدث خطأ أثناء معالجة العملية';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getExpenseAnalysis() async { final id = _requireUser(); return await _handleGetRequest('/analysis/expenses?user_id=$id'); }

  Future<Map<String, dynamic>> getFinancialSummary() async { final id = _requireUser(); return await _handleGetRequest('/analysis/summary?user_id=$id'); }

  Future<Map<String, dynamic>> getInsights() async { final id = _requireUser(); return await _handleGetRequest('/analysis/insights?user_id=$id'); }

  Future<Map<String, dynamic>> getAiAnalysis() async {
    try {
      final response = await http.get(
        Uri.parse('$aiBaseUrl/analysis/${_requireUser()}'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('AI analysis error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getGoldPrices() async => await _handleGetRequest('/gold/prices');

  Future<Map<String, dynamic>> calculateGold(double grams, String karat) async {
    return await _handlePostRequest('/gold/calculate', {
      'grams': grams,
      'karat': karat,
    });
  }

  Future<List<dynamic>> getCurrencyRates() async => await _handleGetRequest('/currency/rates');

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> body) async {
    return Map<String, dynamic>.from(await _handlePostRequest('/transactions/?user_id=${_requireUser()}', body));
  }

  Future<Map<String, dynamic>> updateTransaction(int id, Map<String, dynamic> body) async {
    return Map<String, dynamic>.from(await _handlePutRequest('/transactions/$id?user_id=${_requireUser()}', body));
  }

  Future<void> deleteTransaction(int id) async {
    await _handleDeleteRequest('/transactions/$id?user_id=${_requireUser()}');
  }

  Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> body) async {
    return Map<String, dynamic>.from(await _handlePutRequest('/users/$id', body));
  }

  Future<void> deleteUser(int id) async {
    await _handleDeleteRequest('/users/$id');
  }

  Future<dynamic> _handlePutRequest(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.bodyBytes.isEmpty) return {};
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw Exception('فشل تحديث البيانات: ${response.statusCode}');
  }

  Future<dynamic> _handleDeleteRequest(String path) async {
    final response = await http.delete(Uri.parse('$baseUrl$path'));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes.isEmpty ? {} : jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw Exception('فشل حذف البيانات: ${response.statusCode}');
  }
}