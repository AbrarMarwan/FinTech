import 'dart:convert';
import 'dart:async';
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

  int _activeUserId = 1;

  int get activeUserId => _activeUserId;

  set activeUserId(int id) {
    _activeUserId = id;
  }

  WebSocketChannel? _goldChannel;
  final StreamController<Map<String, dynamic>> _goldStreamController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get goldPriceStream => _goldStreamController.stream;

  // ========== WEBSOCKET ==========
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
          print('❌ WebSocket Error: $error');
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

  // ========== HELPER METHODS ==========
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

  // ========== USERS ==========
  Future<List<dynamic>> getUsers() async => await _handleGetRequest('/users/');

  // ========== WALLET & TRANSACTIONS ==========
  Future<Map<String, dynamic>> getWallet() async => await _handleGetRequest('/wallet/?user_id=$_activeUserId');

  Future<List<dynamic>> getTransactions() async => await _handleGetRequest('/transactions/?user_id=$_activeUserId');

  // ========== SAVINGS ==========
  Future<Map<String, dynamic>> getSavingsBalance() async => await _handleGetRequest('/savings/balance?user_id=$_activeUserId');

  // ✅ معالجة دقيقة لعمليات الإيداع والسحب لضمان الطرح الصحيح
  Future<void> addSavingsTransaction(double amount, bool isDeposit) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/savings/transaction?user_id=$_activeUserId'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        // Payload matches backend SavingsTransactionCreate schema exactly
        body: jsonEncode({
          'amount': amount,
          'is_deposit': isDeposit,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ تمت العملية بنجاح: ${isDeposit ? "إيداع" : "سحب"}');
      } else {
        // فك تشفير رسالة الخطأ العربية من FastAPI (مثل: "عذراً، رصيدك غير كافٍ")
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw errorData['detail'] ?? 'حدث خطأ أثناء معالجة العملية';
      }
    } catch (e) {
      // إعادة رمي الخطأ ليتم التقاطه في الـ SnackBar بالواجهة
      rethrow;
    }
  }

  // ========== ANALYSIS ==========
  Future<List<dynamic>> getExpenseAnalysis() async => await _handleGetRequest('/analysis/expenses?user_id=$_activeUserId');

  Future<Map<String, dynamic>> getFinancialSummary() async => await _handleGetRequest('/analysis/summary?user_id=$_activeUserId');

  Future<Map<String, dynamic>> getInsights() async => await _handleGetRequest('/analysis/insights?user_id=$_activeUserId');

  /// Fetch AI-driven financial analysis from the financial_advisor service
  Future<Map<String, dynamic>> getAiAnalysis() async {
    try {
      final response = await http.get(
        Uri.parse('$aiBaseUrl/analysis/$_activeUserId'),
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

  // ========== GOLD & CURRENCY SERVICES ==========
  Future<Map<String, dynamic>> getGoldPrices() async => await _handleGetRequest('/gold/prices');

  /// POST to /gold/calculate — routes calculation to backend
  Future<Map<String, dynamic>> calculateGold(double grams, String karat) async {
    return await _handlePostRequest('/gold/calculate', {
      'grams': grams,
      'karat': karat,
    });
  }

  Future<List<dynamic>> getCurrencyRates() async => await _handleGetRequest('/currency/rates');
}