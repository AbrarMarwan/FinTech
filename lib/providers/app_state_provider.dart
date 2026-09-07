import 'package:flutter/foundation.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';
import '../database/local_database.dart';

class AppStateProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final LocalDatabase _local = LocalDatabase.instance;

  UserModel? currentUser;
  WalletData? wallet;
  List<TransactionModel> transactions = [];
  bool isLoading = false;
  String? error;
  List<ExpenseAnalysisData> expenseAnalysis = [];
  FinancialSummaryData? financialSummary;
  InsightsData? insights;
  AiAnalysisData? aiAnalysis;
  bool isAuthenticated = false;

  Future<void> login(String phone, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _api.login(phone.trim(), password);
      currentUser = UserModel.fromJson(Map<String, dynamic>.from(result['user']));
      _api.activeUserId = currentUser!.id;
      await _local.clearTransactions();
      isAuthenticated = true;
      await loadHomeData();
      await loadAnalysis();
    } catch (e) {
      isAuthenticated = false;
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String name, String phone, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _api.register(name.trim(), phone.trim(), password);
      currentUser = UserModel.fromJson(result);
      _api.activeUserId = currentUser!.id;
      await _local.clearTransactions();
      isAuthenticated = true;
      await loadHomeData();
      await loadAnalysis();
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _api.activeUserId = null;
    _local.clearTransactions();
    currentUser = null;
    wallet = null;
    transactions = [];
    expenseAnalysis = [];
    financialSummary = null;
    insights = null;
    aiAnalysis = null;
    isAuthenticated = false;
    error = null;
    notifyListeners();
  }

  Future<void> loadHomeData() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final walletJson = await _api.getWallet();
      final transactionJson = await _api.getTransactions();
      wallet = WalletData.fromJson(walletJson);
      transactions = transactionJson.map((e) => TransactionModel.fromJson(e)).toList();
      await _local.replaceTransactions(transactionJson.map((e) {
        final item = Map<String, dynamic>.from(e);
        item['is_expense'] = item['is_expense'] == true ? 1 : 0;
        item.remove('created_at');
        return item;
      }).toList());
    } catch (e) {
      final userId = _api.activeUserId;
      if (userId != null) {
        final cached = await _local.getTransactions(userId: userId);
        transactions = cached.map((e) {
          final item = Map<String, dynamic>.from(e);
          item['is_expense'] = item['is_expense'] == 1;
          return TransactionModel.fromJson(item);
        }).toList();
      } else {
        transactions = [];
      }
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAnalysis() async {
    if (!isAuthenticated || _api.activeUserId == null) return;
    final userId = _api.activeUserId;
    try {
      final data = await _api.getExpenseAnalysis();
      expenseAnalysis = data.map((item) => ExpenseAnalysisData.fromJson(item)).toList();
    } catch (_) {}
    try {
      final data = await _api.getFinancialSummary();
      financialSummary = FinancialSummaryData.fromJson(data);
    } catch (_) {}
    try {
      final data = await _api.getInsights();
      insights = InsightsData.fromJson(data);
    } catch (_) {}
    try {
      final data = await _api.getAiAnalysis();
      aiAnalysis = AiAnalysisData.fromJson(data);
    } catch (_) {}
    if (userId != _api.activeUserId) return;
    notifyListeners();
  }

  Future<void> createTransaction({
    required String title,
    required String amount,
    required bool isExpense,
    required String category,
  }) async {
    final body = {
      'title': title,
      'amount': amount,
      'time': DateTime.now().toIso8601String(),
      'is_expense': isExpense,
      'icon_name': isExpense ? 'shopping_cart' : 'account_balance',
      'category': category,
    };
    final created = await _api.createTransaction(body);
    final item = Map<String, dynamic>.from(created);
    transactions.insert(0, TransactionModel.fromJson(item));
    item['is_expense'] = item['is_expense'] == true ? 1 : 0;
    item.remove('created_at');
    await _local.insertTransaction(item);
    notifyListeners();
    await loadHomeData();
    await loadAnalysis();
  }

  Future<void> updateTransaction(int id, {
    required String title,
    required String amount,
    required bool isExpense,
    required String category,
  }) async {
    final body = {
      'title': title,
      'amount': amount,
      'time': DateTime.now().toIso8601String(),
      'is_expense': isExpense,
      'icon_name': isExpense ? 'shopping_cart' : 'account_balance',
      'category': category,
    };
    final updated = await _api.updateTransaction(id, body);
    final index = transactions.indexWhere((e) => e.id == id);
    if (index >= 0) {
      transactions[index] = TransactionModel.fromJson(updated);
    }
    final localItem = Map<String, dynamic>.from(updated);
    localItem['is_expense'] = localItem['is_expense'] == true ? 1 : 0;
    localItem.remove('created_at');
    await _local.updateTransaction(id, localItem);
    notifyListeners();
    await loadHomeData();
    await loadAnalysis();
  }

  Future<void> deleteTransaction(int id) async {
    await _api.deleteTransaction(id);
    transactions.removeWhere((e) => e.id == id);
    await _local.deleteTransaction(id);
    notifyListeners();
    await loadHomeData();
    await loadAnalysis();
  }
}
