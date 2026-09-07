import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/api_models.dart';
import '../main.dart';

class AnalysisSummaryScreen extends StatelessWidget {
  const AnalysisSummaryScreen({super.key});

  String _format(double value) => value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'), (m) => ',');

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('التحليل المالي')), 
        body: Consumer<AppStateProvider>(
          builder: (context, provider, child) {
            final summary = provider.financialSummary;
            final analysis = provider.expenseAnalysis;
            final ai = provider.aiAnalysis;
            final insights = provider.insights;
            if (provider.isLoading && summary == null && analysis.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.transactions.isEmpty) {
              return RefreshIndicator(
                onRefresh: provider.loadAnalysis,
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _newAccountCard(),
                    const SizedBox(height: 16),
                    _summaryCard(summary),
                    const SizedBox(height: 20),
                    const Text('سيبدأ التحليل تلقائيًا بعد تسجيل معاملاتك الفعلية.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: provider.loadAnalysis,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _summaryCard(summary),
                  const SizedBox(height: 16),
                  _spendingCard(analysis),
                  const SizedBox(height: 16),
                  _aiCard(ai, insights),
                  const SizedBox(height: 20),
                  const Text('التحليل يعتمد على معاملات المستخدم المسجل فقط خلال آخر 30 يومًا.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
                ],
              ),
            );
          },
        ),
      ),
    );
  }


  Widget _newAccountCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ابدأ ببناء تحليلك المالي',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.analytics_outlined, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'لا توجد معاملات كافية حتى الآن لإعطائك تقييمًا ماليًا. هذا طبيعي للحساب الجديد، وليس مؤشرًا على أن وضعك المالي جيد أو سيئ.',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 14),
          const Text(
            'سجل دخلك ومصروفاتك أولًا. كلما زادت معاملاتك، أصبحت التوصيات أكثر دقة وارتباطًا بسلوكك الفعلي.',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(FinancialSummaryData? summary) {
    if (summary == null) return _emptyCard('لا توجد بيانات مالية كافية للتحليل');
    return Row(
      children: [
        Expanded(child: _stat('المصروفات', _format(summary.currentOutflow), summary.outflowGrowthPercentage, AppColors.danger)),
        const SizedBox(width: 12),
        Expanded(child: _stat('الدخل', _format(summary.currentInflow), summary.inflowGrowthPercentage, AppColors.accent)),
      ],
    );
  }

  Widget _stat(String title, String amount, double growth, Color color) {
    final sign = growth > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Text('YR $amount', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 5),
        Text('$sign${growth.toStringAsFixed(1)}% مقارنة بالفترة السابقة', style: TextStyle(fontSize: 10, color: color)),
      ]),
    );
  }

  Widget _spendingCard(List<ExpenseAnalysisData> analysis) {
    if (analysis.isEmpty) return _emptyCard('لا توجد مصروفات خلال آخر 30 يومًا');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('توزيع المصروفات الحقيقي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 8),
        const Text('النسب محسوبة من معاملاتك المسجلة في قاعدة البيانات.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 18),
        ...analysis.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              Text('${item.percentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              const Spacer(),
              Text(item.category, style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (item.percentage / 100).clamp(0, 1), minHeight: 10)),
            const SizedBox(height: 4),
            Text('YR ${_format(item.amount)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        )),
      ]),
    );
  }

  Widget _aiCard(AiAnalysisData? ai, InsightsData? insights) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('المستشار المالي', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        if (ai != null) ...[
          _line('الشخصية المالية', ai.personality),
          _line('مستوى الخطورة', '${ai.riskLevel} (${ai.riskScore}%)'),
        ],
        if (insights != null) ...[
          const SizedBox(height: 10),
          _line('الملاحظة', insights.insightText),
          _line('التوصية', insights.recommendationText),
        ],
        if (ai == null && insights == null) const Text('سيظهر التحليل بعد تسجيل معاملاتك.', style: TextStyle(color: Colors.white70)),
      ]),
    );
  }

  Widget _line(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _emptyCard(String text) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)));
}
