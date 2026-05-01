import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/api_models.dart';
import '../main.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final TextEditingController _amountController = TextEditingController();
  final ApiService _apiService = ApiService();

  double _depositScale = 1.0;
  double _withdrawScale = 1.0;
  double _totalSavings = 0.0;
  bool _isLoading = true;
  bool _hasPerformed = false; // Track if we need to sync back to main screen

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  void _loadBalance() async {
    setState(() => _isLoading = true);
    try {
      final balanceData = await _apiService.getSavingsBalance();
      final savingsData = SavingsBalanceData.fromJson(balanceData);

      setState(() {
        _totalSavings = savingsData.totalSavings.toDouble();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('فشل تحديث الرصيد');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _processTransaction(double amount, bool isDeposit, void Function() onSuccess) async {
    try {
      await _apiService.addSavingsTransaction(amount, isDeposit);
      if (!mounted) return;
      onSuccess();
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  void _showTransactionPopup(BuildContext context, {required bool isDeposit}) {
    _triggerFeedback();
    _amountController.clear();
    bool isSuccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 25),
                    if (isSuccess)
                      _buildSuccessView(sheetContext, isDeposit)
                    else
                      _buildTransactionForm(setSheetState, isDeposit, () {
                        setSheetState(() => isSuccess = true);
                        _hasPerformed = true;
                        _loadBalance();
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionForm(StateSetter setSheetState, bool isDeposit, VoidCallback onSuccess) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          isDeposit ? 'إيداع مبلغ للادخار' : 'سحب مبلغ من الادخار',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        const SizedBox(height: 25),
        TextField(
          controller: _amountController,
          textAlign: TextAlign.right,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
          decoration: InputDecoration(
            hintText: 'أدخل المبلغ هنا (YR)',
            prefixIcon: Icon(isDeposit ? Icons.add_chart : Icons.outbox, color: isDeposit ? AppColors.accent : AppColors.danger),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () async {
            final double? amount = double.tryParse(_amountController.text);
            if (amount == null || amount <= 0) {
              _showErrorSnackBar('يرجى إدخل مبلغ صحيح');
              return;
            }
            if (!isDeposit && amount > _totalSavings) {
              _showErrorSnackBar('رصيد المدخرات الحالي (YR ${_formatNumber(_totalSavings)}) غير كافٍ');
              return;
            }
            await _processTransaction(amount, isDeposit, onSuccess);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isDeposit ? AppColors.primary : AppColors.danger,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
          ),
          child: Text(
            isDeposit ? 'تأكيد الإيداع' : 'تأكيد السحب',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(BuildContext sheetContext, bool isDeposit) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDeposit ? AppColors.accent.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle, size: 60, color: isDeposit ? AppColors.accent : AppColors.primary),
        ),
        const SizedBox(height: 20),
        Text(
          isDeposit ? 'تم الإيداع بنجاح' : 'تم السحب بنجاح',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        const SizedBox(height: 10),
        Text(
          'تم تحديث رصيد مدخراتك',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () => Navigator.pop(sheetContext),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('تم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope handles the system back button
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasPerformed);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _buildAppBar(),
        body: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async => _loadBalance(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildMainBalanceCard(),
                const SizedBox(height: 30),
                _buildAnimatedActionButton(
                  title: 'إيداع للادخار',
                  icon: Icons.add_circle_outline,
                  bgColor: AppColors.primary,
                  textColor: Colors.white,
                  scale: _depositScale,
                  onTapDown: (_) => setState(() => _depositScale = 0.95),
                  onTapUp: (_) => setState(() => _depositScale = 1.0),
                  onTap: () => _showTransactionPopup(context, isDeposit: true),
                ),
                const SizedBox(height: 15),
                _buildAnimatedActionButton(
                  title: 'سحب من الادخار',
                  icon: Icons.remove_circle_outline,
                  bgColor: Colors.white,
                  textColor: AppColors.danger,
                  isOutlined: true,
                  scale: _withdrawScale,
                  onTapDown: (_) => setState(() => _withdrawScale = 0.95),
                  onTapUp: (_) => setState(() => _withdrawScale = 1.0),
                  onTap: () => _showTransactionPopup(context, isDeposit: false),
                ),
                const SizedBox(height: 40),
                _buildSectionHeader('التحليل والتوصيات', Icons.analytics_outlined),
                const SizedBox(height: 15),
                _buildTipCard(),
                const SizedBox(height: 25),
                _buildInspirationalImage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainBalanceCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('إجمالي المدخرات', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          _isLoading
              ? const SizedBox(height: 30, width: 30, child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
              : Text('YR ${_formatNumber(_totalSavings)}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, textAlign: TextAlign.right), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
    );
  }

  void _triggerFeedback() => HapticFeedback.lightImpact();

  Widget _buildAnimatedActionButton({
    required String title, required IconData icon, required Color bgColor, required Color textColor,
    required double scale, required Function(TapDownDetails) onTapDown, required Function(TapUpDetails) onTapUp,
    required VoidCallback onTap, bool isOutlined = false,
  }) {
    return GestureDetector(
      onTapDown: onTapDown, onTapUp: onTapUp, onTap: onTap,
      child: AnimatedScale(
        scale: scale, duration: const Duration(milliseconds: 100),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: isOutlined ? Colors.white : bgColor,
            borderRadius: BorderRadius.circular(16),
            border: isOutlined ? Border.all(color: textColor.withOpacity(0.3), width: 1.5) : null,
            boxShadow: !isOutlined ? [BoxShadow(color: bgColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 10),
              Icon(icon, color: textColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
        const SizedBox(width: 10), Icon(icon, color: AppColors.accent, size: 22),
      ],
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Expanded(child: Text('الادخار المستمر يساعدك على تحقيق أهدافك المالية بشكل أسرع.',
              textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          const SizedBox(width: 15),
          Icon(Icons.lightbulb_outline_rounded, color: AppColors.gold, size: 28),
        ],
      ),
    );
  }

  Widget _buildInspirationalImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.network('https://images.unsplash.com/photo-1579621970563-ebec7560ff3e?w=500', height: 180, width: double.infinity, fit: BoxFit.cover),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent, elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textSecondary),
        // Pass _hasPerformed back on app bar back button
        onPressed: () => Navigator.pop(context, _hasPerformed)
      ),
      title: const Text('المدخرات', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
      centerTitle: true,
    );
  }
}