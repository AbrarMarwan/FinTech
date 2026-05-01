import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../models/api_models.dart';
import '../main.dart';

class AnalysisSummaryScreen extends StatefulWidget {
  const AnalysisSummaryScreen({super.key});

  @override
  State<AnalysisSummaryScreen> createState() => _AnalysisSummaryScreenState();
}

class _AnalysisSummaryScreenState extends State<AnalysisSummaryScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<ExpenseAnalysisData>> _analysisData;
  late Future<AiAnalysisData> _aiInsights;
  late Future<FinancialSummaryData> _financialSummary;
  late Future<InsightsData> _dynamicInsights;
  late Future<WalletData> _walletData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // Expense pie chart data
    _analysisData = _apiService.getExpenseAnalysis().then(
      (list) => list.map((item) => ExpenseAnalysisData.fromJson(item)).toList());
    
    // AI insights data from financial_advisor microservice
    _aiInsights = _apiService.getAiAnalysis().then((data) => AiAnalysisData.fromJson(data));

    // Dynamic financial summary
    _financialSummary = _apiService.getFinancialSummary().then((data) => FinancialSummaryData.fromJson(data));

    // Dynamic generative AI insights based on real transactions
    _dynamicInsights = _apiService.getInsights().then((data) => InsightsData.fromJson(data));

    // Wallet data for fallback calculations
    _walletData = _apiService.getWallet().then((data) => WalletData.fromJson(data));
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('ملخص التحليل المالي',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 15),
            FutureBuilder<FinancialSummaryData>(
              future: _financialSummary,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                }
                
                if (snapshot.hasError || !snapshot.hasData) {
                  return Row(
                    children: [
                      Expanded(child: _buildStatCard('الخرج الشهري', 'YR 0', '0%', AppColors.danger, Icons.arrow_upward)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard('الدخل الشهري', 'YR 0', '0%', AppColors.accent, Icons.arrow_downward)),
                    ],
                  );
                }
                
                final summary = snapshot.data!;
                
                String formatGrowth(double growth) {
                  final sign = growth > 0 ? '+' : (growth < 0 ? '-' : '');
                  return '$sign${growth.abs().toStringAsFixed(1)}%';
                }
                
                Color getGrowthColor(double growth, bool isExpense) {
                  if (growth == 0) return AppColors.textSecondary;
                  if (isExpense) {
                    return growth > 0 ? AppColors.danger : AppColors.accent;
                  } else {
                    return growth > 0 ? AppColors.accent : AppColors.danger;
                  }
                }

                return Row(
                  children: [
                    Expanded(child: _buildStatCard(
                      'الخرج الشهري', 
                      'YR ${_formatAmount(summary.currentOutflow)}', 
                      formatGrowth(summary.outflowGrowthPercentage), 
                      getGrowthColor(summary.outflowGrowthPercentage, true), 
                      Icons.arrow_upward
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(
                      'الدخل الشهري', 
                      'YR ${_formatAmount(summary.currentInflow)}', 
                      formatGrowth(summary.inflowGrowthPercentage), 
                      getGrowthColor(summary.inflowGrowthPercentage, false), 
                      Icons.arrow_downward
                    )),
                  ],
                );
              },
            ),
            const SizedBox(height: 25),
            _buildDetailedSpendingSection(),
            const SizedBox(height: 25),
            _buildAiAnalysisSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Mali Wallet', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20)),
    );
  }

  Widget _buildDetailedSpendingSection() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppColors.cardWhite, borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('توجهات الإنفاق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
          const SizedBox(height: 30),
          FutureBuilder<List<ExpenseAnalysisData>>(
            future: _analysisData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.accent));
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Center(child: Text("خطأ في تحميل البيانات", style: TextStyle(color: AppColors.danger)));
              }
              final analysis = snapshot.data!;
              return Row(
                children: [
                  SizedBox(width: 110, height: 110,
                    child: CustomPaint(painter: GradientDonutPainter(analysis)),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: analysis.map((item) => _buildSpendingItem(
                      item.category, 'YR ${item.amount.toStringAsFixed(0)}',
                      [Color(int.parse(item.colorStart.replaceAll('#', '0xFF'))), 
                       Color(int.parse(item.colorEnd.replaceAll('#', '0xFF')))]
                    )).toList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingItem(String label, String amount, List<Color> colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(amount, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(width: 15),
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(gradient: LinearGradient(colors: colors), shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String amount, String percent, Color accentColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(icon, color: accentColor.withOpacity(0.9), size: 20),
          const SizedBox(height: 15),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 5),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
          const SizedBox(height: 5),
          Text(percent, style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAiAnalysisSection() {
    return FutureBuilder<AiAnalysisData>(
      future: _aiInsights,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(30.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        return FutureBuilder<List<dynamic>>(
          future: Future.wait([_financialSummary, _walletData]),
          builder: (context, fallbackSnapshot) {
            final hasRealAiData = snapshot.hasData && !snapshot.hasError;
            
            int riskScore;
            String riskLevel;
            String personality;

            if (hasRealAiData) {
              riskScore = snapshot.data!.riskScore;
              riskLevel = snapshot.data!.riskLevel;
              personality = snapshot.data!.personality;
            } else if (fallbackSnapshot.hasData) {
              // Contextual Fallbacks: Logic-based estimation if AI microservice is down
              final summary = fallbackSnapshot.data![0] as FinancialSummaryData;
              final wallet = fallbackSnapshot.data![1] as WalletData;

              // Proportional Risk: Ratio of Outflow to Inflow
              final riskRatio = (summary.currentInflow > 0) 
                  ? (summary.currentOutflow / summary.currentInflow) 
                  : 1.0;
              riskScore = (riskRatio * 100).toInt().clamp(0, 100);
              riskLevel = riskScore > 70 ? 'عالية' : (riskScore > 30 ? 'متوسطة' : 'منخفضة');

              // Personality Detection: Savings vs Spending behavior
              if (summary.currentOutflow > summary.currentInflow) {
                personality = 'مسرف';
              } else if (wallet.savingsAmount > wallet.availableAmount) {
                personality = 'مدخر';
              } else {
                personality = 'موازن';
              }
            } else {
              // Dead fallback
              riskScore = 0;
              riskLevel = 'غير متوفر';
              personality = 'غير متوفر';
            }

            return Column(
              children: [
                // User Persona & Risk Header
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: riskScore > 60 ? AppColors.danger.withOpacity(0.1) : AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: riskScore > 60 ? AppColors.danger.withOpacity(0.3) : AppColors.accent.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            const Text('مستوى الخطورة', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(riskLevel, style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold, 
                              color: riskScore > 60 ? AppColors.danger : AppColors.accent
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('الشخصية المالية', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(personality, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Dynamic Generative AI Insights
                FutureBuilder<InsightsData>(
                  future: _dynamicInsights,
                  builder: (context, insightSnapshot) {
                    final isLoading = insightSnapshot.connectionState == ConnectionState.waiting;
                    final hasError = insightSnapshot.hasError || (!isLoading && !insightSnapshot.hasData);
                    
                    final String insightText;
                    final String recommendationText;

                    if (hasError) {
                      insightText = 'لم نتمكن من تحليل بياناتك في الوقت الحالي، يرجى المحاولة لاحقاً.';
                      recommendationText = 'تأكد من اتصالك بالإنترنت لتلقي نصائح مخصصة.';
                    } else {
                      insightText = insightSnapshot.data?.insightText ?? '';
                      recommendationText = insightSnapshot.data?.recommendationText ?? '';
                    }
                    
                    return Column(
                      children: [
                        _buildAnalysisInsights(isLoading, insightText),
                        const SizedBox(height: 15),
                        _buildRecommendationsCard(isLoading, recommendationText),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAnalysisInsights(bool isLoading, String? text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardWhite, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('تحليل الإنفاق الذكي', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 10),
              Icon(Icons.analytics, color: AppColors.accent, size: 24),
            ],
          ),
          const SizedBox(height: 15),
          if (isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator(color: AppColors.accent)))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(text ?? '', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(bool isLoading, String? text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary, borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('توصيات الذكاء الاصطناعي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 10),
              Icon(Icons.psychology, color: AppColors.accent, size: 24),
            ],
          ),
          const SizedBox(height: 15),
          if (isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator(color: AppColors.gold)))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(text ?? '', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6)),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.lightbulb_outline, color: AppColors.gold, size: 20),
              ],
            ),
        ],
      ),
    );
  }
}

class GradientDonutPainter extends CustomPainter {
  final List<ExpenseAnalysisData> analysis;
  GradientDonutPainter(this.analysis);

  @override
  void paint(Canvas canvas, Size size) {
    double strokeWidth = 15;
    Rect rect = Offset.zero & size;
    Paint paint = Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    double startAngle = -math.pi / 2;

    for (var item in analysis) {
      final colors = [Color(int.parse(item.colorStart.replaceAll('#', '0xFF'))), Color(int.parse(item.colorEnd.replaceAll('#', '0xFF')))];
      final shader = LinearGradient(colors: colors).createShader(rect);
      final sweepAngle = 2 * math.pi * (item.percentage / 100);
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint..shader = shader);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
