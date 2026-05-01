import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/api_models.dart';
import '../main.dart';

class GoldPricesScreen extends StatefulWidget {
  const GoldPricesScreen({super.key});

  @override
  State<GoldPricesScreen> createState() => _GoldPricesScreenState();
}

class _GoldPricesScreenState extends State<GoldPricesScreen> {
  final TextEditingController _gramsController = TextEditingController();
  final ApiService _apiService = ApiService();

  double _goldPricePerGram = 58450.0;
  double _karat21Price = 51140.0;
  double _karat18Price = 43830.0;
  
  double _totalResult = 0.0;
  String _selectedKarat = '21';
  bool _isLoading = true;
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    _loadGoldPrices();
    _listenToWebSocket();
  }

  void _loadGoldPrices() async {
    try {
      final prices = await _apiService.getGoldPrices();
      final data = GoldPriceData.fromJson(prices);
      setState(() {
        _goldPricePerGram = data.karat24;
        _karat21Price = data.karat21;
        _karat18Price = data.karat18;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _listenToWebSocket() {
    _apiService.goldPriceStream.listen((data) {
      setState(() {
        _goldPricePerGram = (data['karat_24'] ?? _goldPricePerGram).toDouble();
        _karat21Price = (data['karat_21'] ?? _karat21Price).toDouble();
        _karat18Price = (data['karat_18'] ?? _karat18Price).toDouble();
      });
    });
  }

  Future<void> _calculatePrice(String value) async {
    double grams = double.tryParse(value) ?? 0.0;
    if (grams <= 0) {
      setState(() => _totalResult = 0.0);
      return;
    }

    setState(() => _isCalculating = true);
    try {
      // Backend API calculation routing
      final resultData = await _apiService.calculateGold(grams, _selectedKarat);
      final result = GoldCalcResult.fromJson(resultData);
      setState(() {
        _totalResult = result.totalPrice;
        _isCalculating = false;
      });
    } catch (e) {
      // Fallback to local calculation if backend fails
      setState(() {
        _totalResult = grams * _getLocalKaratPrice(_selectedKarat);
        _isCalculating = false;
      });
    }
  }

  double _getLocalKaratPrice(String karat) {
    switch (karat) {
      case '24': return _goldPricePerGram;
      case '21': return _karat21Price;
      case '18': return _karat18Price;
      default: return _goldPricePerGram;
    }
  }

  void _resetCalculator() {
    _triggerFeedback();
    setState(() {
      _gramsController.clear();
      _totalResult = 0.0;
      _selectedKarat = '21';
    });
  }

  void _triggerFeedback() => HapticFeedback.lightImpact();

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
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
            const Text('أسعار الذهب المباشرة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
            const Text('تحديث يومي حسب السوق المحلي',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : Row(
                  children: [
                    Expanded(child: _buildKaratCard('عيار 18', _karat18Price, false)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildKaratCard('عيار 21', _karat21Price, false)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildKaratCard('عيار 24', _goldPricePerGram, true)),
                  ],
                ),
            const SizedBox(height: 30),
            _buildGoldCalculator(),
            const SizedBox(height: 25),
            _buildGoldPromoCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldCalculator() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('حاسبة الذهب الذكية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
              const SizedBox(width: 10),
              Icon(Icons.calculate_outlined, color: AppColors.gold, size: 22),
            ],
          ),
          const SizedBox(height: 25),
          const Text('العيار', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedKarat,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                alignment: AlignmentDirectional.centerEnd,
                items: ['24', '21', '18'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text('عيار $value', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _selectedKarat = newValue);
                    _calculatePrice(_gramsController.text);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('الوزن بالجرام', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          TextField(
            controller: _gramsController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
            decoration: InputDecoration(
              filled: true, fillColor: Colors.grey.shade50,
              hintText: '0.0',
              hintStyle: TextStyle(color: Colors.black.withOpacity(0.3), fontWeight: FontWeight.bold),
              prefixText: 'جرام  ',
              prefixStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
            onChanged: _calculatePrice,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Icon(Icons.keyboard_double_arrow_down_rounded, color: AppColors.textSecondary, size: 24)),
          ),
          const Text('القيمة التقديرية بالريال اليمني', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ريال يمني', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
                _isCalculating 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2))
                  : Text(_totalResult == 0 ? '0.00' : _formatNumber(_totalResult),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 24)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _resetCalculator,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2,
            ),
            child: const Text('إعادة ضبط', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textSecondary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Mali Wallet', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20)),
    );
  }

  Widget _buildKaratCard(String title, double price, bool isMain) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: isMain 
          ? const LinearGradient(colors: [AppColors.primary, AppColors.cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight)
          : null,
        color: isMain ? null : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (isMain) BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
          else BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 5, offset: const Offset(0, 2))
        ],
        border: isMain ? null : Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          if (isMain)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: AppColors.accent, size: 6),
                  SizedBox(width: 4),
                  Text('مباشر', style: TextStyle(color: AppColors.accent, fontSize: 8, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Text(title, style: TextStyle(
            color: isMain ? Colors.white70 : AppColors.textSecondary, 
            fontSize: 12, fontWeight: FontWeight.bold
          )),
          const SizedBox(height: 8),
          Text('${_formatNumber(price)}', style: TextStyle(
            color: isMain ? Colors.white : AppColors.primary, 
            fontWeight: FontWeight.bold, fontSize: 16
          )),
        ],
      ),
    );
  }

  Widget _buildGoldPromoCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_graph_rounded, color: AppColors.gold, size: 30),
          const SizedBox(width: 15),
          const Expanded(
            child: Text('استثمر في الذهب الآن عبر محفظة Mali Wallet بطريقة آمنة وسهلة لضمان مستقبلك المالي.',
              style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.5, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
