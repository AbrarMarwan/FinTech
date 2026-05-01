import 'dart:ui';

// ========== 0. User Model ==========
class UserModel {
  final int id;
  final String name;
  final String? phoneNumber;

  UserModel({
    required this.id,
    required this.name,
    this.phoneNumber,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phoneNumber: json['phone_number'],
    );
  }
}

// ========== 1. Wallet Data Model ==========
class WalletData {
  // Raw numeric values from the API — UI handles "YR" formatting via formatCurrency()
  final double totalBalance;
  final double availableAmount;
  final double savingsAmount;

  WalletData({
    required this.totalBalance,
    required this.availableAmount,
    required this.savingsAmount,
  });

  factory WalletData.fromJson(Map<String, dynamic> json) {
    return WalletData(
      totalBalance: (json['total_balance'] ?? 0.0).toDouble(),
      availableAmount: (json['available_amount'] ?? 0.0).toDouble(),
      savingsAmount: (json['savings_amount'] ?? 0.0).toDouble(),
    );
  }

  // UI-layer formatting: converts 1250500.0 → "YR 1,250,500"
  static String formatCurrency(double value) {
    final parts = value.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    int count = 0;
    for (int i = parts.length - 1; i >= 0; i--) {
      buffer.write(parts[i]);
      count++;
      if (count % 3 == 0 && i != 0) buffer.write(',');
    }
    return 'YR ${buffer.toString().split('').reversed.join('')}';
  }
}

// ========== 2. Transaction Model ==========
class TransactionModel {
  final String title;
  final String amount;
  final String time;
  final bool isExpense;
  final String iconName;

  TransactionModel({
    required this.title,
    required this.amount,
    required this.time,
    required this.isExpense,
    required this.iconName,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      title: json['title'] ?? '',
      amount: json['amount'] ?? '',
      time: json['time'] ?? '',
      isExpense: json['is_expense'] ?? true,
      iconName: json['icon_name'] ?? 'shopping_cart',
    );
  }
}

// ========== 3. Gold Price Model ==========
class GoldPriceData {
  final double karat24;
  final double karat21;
  final double karat18;

  GoldPriceData({
    required this.karat24,
    required this.karat21,
    required this.karat18,
  });

  factory GoldPriceData.fromJson(Map<String, dynamic> json) {
    return GoldPriceData(
      karat24: (json['karat_24'] ?? 58450.0).toDouble(),
      karat21: (json['karat_21'] ?? 51140.0).toDouble(),
      karat18: (json['karat_18'] ?? 43830.0).toDouble(),
    );
  }
}

// ========== 4. Currency Rate Model ==========
class CurrencyRateData {
  final String name;
  final double rate;
  final String change;

  CurrencyRateData({
    required this.name,
    required this.rate,
    required this.change,
  });

  factory CurrencyRateData.fromJson(Map<String, dynamic> json) {
    return CurrencyRateData(
      name: json['currency_name'] ?? '',
      rate: (json['rate'] ?? 0.0).toDouble(),
      change: json['change'] ?? '+0.0%',
    );
  }
}

// ========== 5. Savings Balance Model ==========
class SavingsBalanceData {
  final double totalSavings;
  final double totalDeposits;
  final double totalWithdrawals;

  SavingsBalanceData({
    required this.totalSavings,
    required this.totalDeposits,
    required this.totalWithdrawals,
  });

  factory SavingsBalanceData.fromJson(Map<String, dynamic> json) {
    return SavingsBalanceData(
      totalSavings: (json['total_savings'] ?? 0.0).toDouble(),
      totalDeposits: (json['total_deposits'] ?? 0.0).toDouble(),
      totalWithdrawals: (json['total_withdrawals'] ?? 0.0).toDouble(),
    );
  }
}

// ========== 6. Expense Analysis Model ==========
class ExpenseAnalysisData {
  final String category;
  final double amount;
  final double percentage;
  final String colorStart;
  final String colorEnd;

  ExpenseAnalysisData({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.colorStart,
    required this.colorEnd,
  });

  factory ExpenseAnalysisData.fromJson(Map<String, dynamic> json) {
    return ExpenseAnalysisData(
      category: json['category'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      percentage: (json['percentage'] ?? 0.0).toDouble(),
      colorStart: json['color_start'] ?? '#64B5F6',
      colorEnd: json['color_end'] ?? '#1976D2',
    );
  }
}

// ========== 7. AI Analysis Model ==========
class AiAnalysisData {
  final String userName;
  final String personality;
  final int riskScore;
  final String riskLevel;
  final String aiResult;

  AiAnalysisData({
    required this.userName,
    required this.personality,
    required this.riskScore,
    required this.riskLevel,
    required this.aiResult,
  });

  factory AiAnalysisData.fromJson(Map<String, dynamic> json) {
    return AiAnalysisData(
      userName: json['user_name'] ?? json['المستخدم'] ?? '',
      personality: json['personality'] ?? json['الشخصية المالية'] ?? '',
      riskScore: (json['risk_score'] ?? json['درجة الخطورة'] ?? 0) is int
          ? json['risk_score'] ?? json['درجة الخطورة'] ?? 0
          : (json['risk_score'] ?? json['درجة الخطورة'] ?? 0).toInt(),
      riskLevel: json['risk_level'] ?? json['مستوى الخطورة'] ?? '',
      aiResult: json['ai_result'] ?? '',
    );
  }
}

class FinancialSummaryData {
  final double currentInflow;
  final double inflowGrowthPercentage;
  final double currentOutflow;
  final double outflowGrowthPercentage;

  FinancialSummaryData({
    required this.currentInflow,
    required this.inflowGrowthPercentage,
    required this.currentOutflow,
    required this.outflowGrowthPercentage,
  });

  factory FinancialSummaryData.fromJson(Map<String, dynamic> json) {
    return FinancialSummaryData(
      currentInflow: (json['current_inflow'] ?? 0).toDouble(),
      inflowGrowthPercentage: (json['inflow_growth_percentage'] ?? 0).toDouble(),
      currentOutflow: (json['current_outflow'] ?? 0).toDouble(),
      outflowGrowthPercentage: (json['outflow_growth_percentage'] ?? 0).toDouble(),
    );
  }
}

class InsightsData {
  final String insightText;
  final String recommendationText;

  InsightsData({required this.insightText, required this.recommendationText});

  factory InsightsData.fromJson(Map<String, dynamic> json) {
    return InsightsData(
      insightText: json['insight_text'] ?? '',
      recommendationText: json['recommendation_text'] ?? '',
    );
  }
}

// ========== 8. Gold Calculation Result Model ==========
class GoldCalcResult {
  final double grams;
  final String karat;
  final double pricePerGram;
  final double totalPrice;

  GoldCalcResult({
    required this.grams,
    required this.karat,
    required this.pricePerGram,
    required this.totalPrice,
  });

  factory GoldCalcResult.fromJson(Map<String, dynamic> json) {
    return GoldCalcResult(
      grams: (json['grams'] ?? 0.0).toDouble(),
      karat: json['karat'] ?? '24',
      pricePerGram: (json['price_per_gram'] ?? 0.0).toDouble(),
      totalPrice: (json['total_price'] ?? 0.0).toDouble(),
    );
  }
}