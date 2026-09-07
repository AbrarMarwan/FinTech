import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/mali_intro_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/savings_screen.dart';
import 'providers/app_state_provider.dart';
import 'models/api_models.dart';
import 'services/api_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  ApiService().connectToGoldWebSocket();
  runApp(ChangeNotifierProvider(create: (_) => AppStateProvider(), child: const MaliWalletApp()));
}

class AppColors {
  static const Color primary = Color(0xFF0A2540);       
  static const Color cardDark = Color(0xFF112D4E);      
  static const Color surface = Color(0xFFF6F9FC);       
  static const Color accent = Color(0xFF00D4B6);        
  static const Color gold = Color(0xFFF3A000);          
  static const Color danger = Color(0xFFE63946);        
  static const Color textPrimary = Color(0xFF0A2540);
  static const Color textSecondary = Color(0xFF6B7C93);
  static const Color cardWhite = Colors.white;
}

class MaliWalletApp extends StatelessWidget {
  const MaliWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Tajawal',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.primary),
          titleTextStyle: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'Tajawal',
          ),
        ),
      ),
      home: Consumer<AppStateProvider>(builder: (context, provider, child) => provider.isAuthenticated ? const MainHomeScreen() : const AuthScreen()),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  bool _isBalanceVisible = true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    final provider = context.read<AppStateProvider>();
    await provider.loadHomeData();
    await provider.loadAnalysis();
  }

  Future<void> _navigateToService(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    await _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, child) {
        final wallet = provider.wallet;
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: _buildAppBar(),
          body: RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _refreshData,
            child: wallet == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildTotalBalanceCard(wallet.totalBalance),
                        const SizedBox(height: 16),
                        _buildSubBalanceCards(wallet.availableAmount, wallet.savingsAmount),
                        const SizedBox(height: 16),
                        _buildNewServiceBanner(),
                        const SizedBox(height: 25),
                        _buildQuickServicesSection(),
                        const SizedBox(height: 25),
                        _buildRecentTransactionsSection(),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSubBalanceCards(double available, double savings) {
    return Row(
      children: [
        Expanded(child: _subCard('المتاح', WalletData.formatCurrency(available), Icons.account_balance_wallet, null)),
        const SizedBox(width: 12),
        Expanded(
          child: _subCard('المدخر', WalletData.formatCurrency(savings), Icons.savings, () {
            _navigateToService(const SavingsScreen()); 
          }),
        ),
      ],
    );
  }

  Widget _subCard(String title, String amount, IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(icon, color: AppColors.accent, size: 24),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            Text(_isBalanceVisible ? amount : '*******',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBalanceCard(double balance) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.cardDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 6))]
      ),
      child: Column(
        children: [
          const Align(alignment: Alignment.centerRight, child: Text('إجمالي الرصيد', style: TextStyle(color: Colors.white70))),
          Text(_isBalanceVisible ? WalletData.formatCurrency(balance) : 'YR *******',
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
            icon: Icon(_isBalanceVisible ? Icons.visibility_off : Icons.visibility, size: 18),
            label: Text(_isBalanceVisible ? 'إخفاء الرصيد' : 'إظهار الرصيد'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(30),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickServicesSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => _navigateToService(const AllServicesScreen()),
              child: const Text('عرض الكل', style: TextStyle(color: AppColors.accent)),
            ),
            const Text('الخدمات ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _serviceItem('فواتير', Icons.receipt_long, AppColors.primary, () {}),
            _serviceItem('QR', Icons.qr_code_scanner, AppColors.primary, () {}),
            _serviceItem('شحن', Icons.phone_android, AppColors.primary, () {}),
            _serviceItem('تحويل', Icons.send, AppColors.primary, () {}),
            _serviceItem('مالي', Icons.stars, AppColors.gold, () {
              _navigateToService(MaliIntroScreen(userName: context.read<AppStateProvider>().currentUser?.name ?? ''));
            }),
          ],
        ),
      ],
    );
  }

  Widget _serviceItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          Container(
            width: 65, height: 65,
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.03), blurRadius: 8)],
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Future<void> _openTransactionForm({TransactionModel? transaction}) async {
    final titleController = TextEditingController(text: transaction?.title ?? '');
    final amountController = TextEditingController(text: transaction?.amount.replaceAll(RegExp(r'[^\d.]'), '') ?? '');
    bool isExpense = transaction?.isExpense ?? true;
    String category = transaction?.category ?? 'shopping';

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  transaction == null ? 'إضافة معاملة' : 'تعديل المعاملة',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'اسم المعاملة', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'shopping', child: Text('تسوق')),
                    DropdownMenuItem(value: 'food', child: Text('طعام')),
                    DropdownMenuItem(value: 'bills', child: Text('فواتير')),
                    DropdownMenuItem(value: 'other', child: Text('أخرى')),
                  ],
                  onChanged: (value) => setSheetState(() => category = value ?? 'other'),
                ),
                SwitchListTile(
                  value: isExpense,
                  title: const Text('عملية مصروف'),
                  onChanged: (value) => setSheetState(() => isExpense = value),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final title = titleController.text.trim();
                      final amount = double.tryParse(amountController.text.trim());
                      if (title.isEmpty || amount == null || amount <= 0) return;
                      final signed = isExpense
                          ? '-${amount.toStringAsFixed(0)}'
                          : '+${amount.toStringAsFixed(0)}';
                      Navigator.pop(sheetContext, {
                        'title': title,
                        'amount': signed,
                        'isExpense': isExpense,
                        'category': category,
                      });
                    },
                    child: const Text('حفظ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    titleController.dispose();
    amountController.dispose();

    if (!mounted || result == null) return;

    try {
      final provider = context.read<AppStateProvider>();
      if (transaction == null) {
        await provider.createTransaction(
          title: result['title'] as String,
          amount: result['amount'] as String,
          isExpense: result['isExpense'] as bool,
          category: result['category'] as String,
        );
      } else {
        await provider.updateTransaction(
          transaction.id,
          title: result['title'] as String,
          amount: result['amount'] as String,
          isExpense: result['isExpense'] as bool,
          category: result['category'] as String,
        );
      }
      if (!mounted) return;
      await provider.loadHomeData();
      await _refreshData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ المعاملة: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _deleteTransaction(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المعاملة'),
        content: const Text('هل تريد حذف هذه المعاملة نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AppStateProvider>().deleteTransaction(id);
      _refreshData();
    }
  }

  Widget _buildRecentTransactionsSection() {
    return Consumer<AppStateProvider>(
      builder: (context, provider, child) {
        final transactions = provider.transactions.take(10).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _openTransactionForm(),
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
                      tooltip: 'إضافة',
                    ),
                    const Text('إدارة', style: TextStyle(color: AppColors.accent)),
                  ],
                ),
                const Text('العمليات الأخيرة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 10),
            if (provider.isLoading && transactions.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (transactions.isEmpty)
              const Text('لا توجد معاملات')
            else
              Column(
                children: transactions.map((tx) {
                  IconData iconData = Icons.shopping_cart;
                  if (tx.iconName == 'person') iconData = Icons.person;
                  if (tx.iconName == 'send') iconData = Icons.send;
                  if (tx.iconName == 'receipt_long') iconData = Icons.receipt_long;
                  return Card(
                    elevation: 0,
                    color: AppColors.cardWhite,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _openTransactionForm(transaction: tx);
                          if (value == 'delete') _deleteTransaction(tx.id);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('تعديل')),
                          PopupMenuItem(value: 'delete', child: Text('حذف')),
                        ],
                      ),
                      title: Text(tx.title, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text(tx.category, textAlign: TextAlign.right),
                      trailing: CircleAvatar(
                        backgroundColor: AppColors.primary.withAlpha(15),
                        child: Icon(iconData, size: 18, color: AppColors.primary),
                      ),
                      isThreeLine: true,
                    ),
                  );
                }).toList(),
              ),
          ],
        );
      },
    );
  }


  Widget _buildNewServiceBanner() {
    return InkWell(
      onTap: () => _navigateToService(MaliIntroScreen(userName: context.read<AppStateProvider>().currentUser?.name ?? '')),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold.withAlpha(80)),
            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.06), blurRadius: 10)],
        ),
        child: Row(
          children: [
            const Icon(Icons.chevron_left, color: AppColors.textSecondary),
            const Spacer(),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('خدمة مالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                Text('الجيل الجديد من الخدمات', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(width: 12),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.gold, Color(0xFFFFB830)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star, color: Colors.white))
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 50, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text("تعذر الاتصال بالسيرفر", style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text("إعادة المحاولة"),
          ),
        ],
      ),
    );
  }

  void _logout() {
    context.read<AppStateProvider>().logout();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Mali Wallet', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent,
      actions: [
        IconButton(icon: const Icon(Icons.refresh, color: AppColors.primary), onPressed: _refreshData),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: InkWell(
            onTap: _logout,
            borderRadius: BorderRadius.circular(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.read<AppStateProvider>().currentUser?.name ?? '',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary.withAlpha(15),
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AllServicesScreen extends StatelessWidget {
  const AllServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كافة الخدمات')),
      body: const Center(child: Text("قائمة الخدمات الكاملة")),
    );
  }
}
