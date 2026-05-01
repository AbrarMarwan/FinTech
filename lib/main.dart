import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert'; // لفك تشفير بيانات الـ API
import 'package:http/http.dart' as http;

// تأكدي من مطابقة هذه المسارات لمشروعك
import 'screens/mali_intro_screen.dart';
import 'screens/analysis_summary_screen.dart';
import 'screens/savings_screen.dart';
import 'screens/gold_prices_screen.dart';
import 'screens/currency_exchange_screen.dart';
import 'services/api_service.dart';
import 'models/api_models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService().connectToGoldWebSocket();
  runApp(const MaliWalletApp());
}

// ========== Premium Fintech Color Palette ==========
class AppColors {
  static const Color primary = Color(0xFF0A2540);       // Deep Navy
  static const Color cardDark = Color(0xFF112D4E);      // Dark card gradient end
  static const Color surface = Color(0xFFF6F9FC);       // Platinum White
  static const Color accent = Color(0xFF00D4B6);        // Emerald
  static const Color gold = Color(0xFFF3A000);          // Gold
  static const Color danger = Color(0xFFE63946);        // Error/withdrawal red
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
      home: const MainHomeScreen(),
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
  final ApiService _apiService = ApiService();
  String _activeUserName = 'أحمد محمد';

  late Future<WalletData> _walletData;
  late Future<List<TransactionModel>> _transactionsData;

  @override
  void initState() {
    super.initState();
    _loadData(); // تحميل البيانات الأولية
  }

  // دالة لجلب البيانات من السيرفر
  void _loadData() {
    _walletData = _apiService.getWallet().then((data) => WalletData.fromJson(data));
    _transactionsData = _apiService.getTransactions().then((list) =>
        list.map((item) => TransactionModel.fromJson(item)).toList());
  }

  // إعادة بناء الواجهة لجلب البيانات الجديدة
  void _refreshData() {
    setState(() {
      _loadData();
    });
  }

  // ✅ الدالة المحسنة للانتقال والمزامنة
  // تقوم بتحديث البيانات دائماً عند العودة من أي شاشة لضمان تطابق الأرصدة
  Future<void> _navigateToService(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    _refreshData(); // التحديث غير المشروط لضمان المزامنة
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          _refreshData();
          // Wait for actual data to load — not an arbitrary delay
          try {
            await _walletData;
            await _transactionsData;
          } catch (_) {}
        },
        child: FutureBuilder<WalletData>(
          future: _walletData,
          builder: (context, walletSnapshot) {
            if (walletSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.accent));
            }
            if (walletSnapshot.hasError) {
              return _buildErrorView();
            }

            final wallet = walletSnapshot.data!;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildTotalBalanceCard(wallet.totalBalance),
                  const SizedBox(height: 16),
                  // تمرير الأرصدة المحدثة للبطاقات
                  _buildSubBalanceCards(wallet.availableAmount, wallet.savingsAmount),
                  const SizedBox(height: 16),
                  _buildNewServiceBanner(),
                  const SizedBox(height: 25),
                  _buildQuickServicesSection(),
                  const SizedBox(height: 25),
                  _buildRecentTransactionsSection(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // بطاقات الرصيد المتاح والمدخر
  // Accepts raw double values; formats with "YR" locally at display time
  Widget _buildSubBalanceCards(double available, double savings) {
    return Row(
      children: [
        Expanded(child: _subCard('المتاح', WalletData.formatCurrency(available), Icons.account_balance_wallet, null)),
        const SizedBox(width: 12),
        Expanded(
          child: _subCard('المدخر', WalletData.formatCurrency(savings), Icons.savings, () {
            _navigateToService(const SavingsScreen()); // الانتقال مع المزامنة
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
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]
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

  // Accepts raw double value; formats with "YR" locally at display time
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
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6))]
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
              _navigateToService(MaliIntroScreen(userName: _activeUserName));
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
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.03), blurRadius: 8)],
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('العمليات الأخيرة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        FutureBuilder<List<TransactionModel>>(
          future: _transactionsData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox();
            if (snapshot.hasError || !snapshot.hasData) return const Text("خطأ في التحميل");

            final transactions = snapshot.data!;
            return Column(
              children: transactions.map((tx) {
                // استخدام التحويل للموديل المحلي لعرض الأيقونات
                IconData iconData = Icons.shopping_cart;
                if (tx.iconName == 'person') iconData = Icons.person;
                if (tx.iconName == 'send') iconData = Icons.send;
                if (tx.iconName == 'receipt_long') iconData = Icons.receipt_long;

                return Card(
                  elevation: 0, color: AppColors.cardWhite,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: Text(tx.amount,
                        style: TextStyle(color: tx.isExpense ? AppColors.danger : AppColors.accent, fontWeight: FontWeight.bold)),
                    title: Text(tx.title, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textPrimary)),
                    trailing: CircleAvatar(
                        backgroundColor: AppColors.primary.withAlpha(15),
                        child: Icon(iconData, size: 18, color: AppColors.primary)
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNewServiceBanner() {
    return InkWell(
      onTap: () => _navigateToService(MaliIntroScreen(userName: _activeUserName)),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold.withAlpha(80)),
            boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.06), blurRadius: 10)],
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

  void _showUserSelectionModal() async {
    try {
      final usersData = await _apiService.getUsers();
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text('اختيار المستخدم',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  ...usersData.map((userData) {
                    final name = userData['name'] ?? '';
                    final id = userData['id'] ?? 0;
                    final isActive = id == _apiService.activeUserId;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? AppColors.primary
                            : AppColors.primary.withAlpha(20),
                        child: Text(
                          name.isNotEmpty ? name[0] : '?',
                          style: TextStyle(
                            color: isActive ? Colors.white : AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(name, style: const TextStyle(color: AppColors.textPrimary)),
                      trailing: isActive
                          ? const Icon(Icons.check_circle, color: AppColors.accent)
                          : null,
                      onTap: () {
                        _apiService.activeUserId = id;
                        setState(() {
                          _activeUserName = name;
                        });
                        Navigator.pop(context);
                        _refreshData();
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل المستخدمين: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
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
            onTap: _showUserSelectionModal,
            borderRadius: BorderRadius.circular(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _activeUserName,
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

// كود شاشة كافة الخدمات البسيطة
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