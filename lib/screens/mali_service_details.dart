import 'package:flutter/material.dart';
import '../main.dart';
import 'analysis_summary_screen.dart';
import 'savings_screen.dart';
import 'gold_prices_screen.dart';
import 'currency_exchange_screen.dart';

class FinancialToolsScreen extends StatelessWidget {
  final String userName;
  const FinancialToolsScreen({super.key, required this.userName});

  void _onToolTap(BuildContext context, String title) {
    switch (title) {
      case 'تحليل المصروفات':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalysisSummaryScreen()));
        break;
      case 'الادخار':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SavingsScreen()));
        break;
      case 'أسعار الذهب':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const GoldPricesScreen()));
        break;
      case 'أسعار العملة':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const CurrencyExchangeScreen()));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('جاري العمل على: $title', textAlign: TextAlign.right),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 700),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildCustomAppBar(context),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(height: 20),
            Text('أهلاً بك، $userName',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            const Text('إليك أهم الأدوات المالية المتاحة لك اليوم.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 30),
            _buildToolCard(context, title: 'تحليل المصروفات', subtitle: 'راقب نمط إنفاقك الشهري بدقة عبر الذكاء الاصطناعي',
              icon: Icons.psychology_outlined, iconBgColor: AppColors.accent.withOpacity(0.15), iconColor: AppColors.accent),
            _buildToolCard(context, title: 'الادخار', subtitle: 'خطط لمستقبلك وحقق أهدافك المالية',
              icon: Icons.savings_outlined, iconBgColor: AppColors.gold.withOpacity(0.15), iconColor: AppColors.gold),
            _buildToolCard(context, title: 'أسعار الذهب', subtitle: 'متابعة لحظية لأسعار الذهب العالمية والمحلية',
              icon: Icons.bar_chart_rounded, iconBgColor: AppColors.accent.withOpacity(0.15), iconColor: AppColors.accent),
            _buildToolCard(context, title: 'أسعار العملة', subtitle: 'أسعار الصرف للريال اليمني والعملات الأجنبية',
              icon: Icons.currency_exchange_outlined, iconBgColor: AppColors.primary.withOpacity(0.1), iconColor: AppColors.primary),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildCustomAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent, elevation: 0, centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textSecondary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Row(
          children: [
            const Text('Mali Wallet', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(right: 16), padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withAlpha(15),
                child: const Icon(Icons.person, size: 20, color: AppColors.primary),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildToolCard(BuildContext context, {required String title, required String subtitle,
      required IconData icon, required Color iconBgColor, required Color iconColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _onToolTap(context, title),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardWhite, borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 20),
              const Spacer(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), textAlign: TextAlign.right),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: iconColor, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
