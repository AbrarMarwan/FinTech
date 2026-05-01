import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/api_models.dart';

class CurrencyExchangeScreen extends StatefulWidget {
  const CurrencyExchangeScreen({super.key});

  @override
  State<CurrencyExchangeScreen> createState() => _CurrencyExchangeScreenState();
}

class _CurrencyExchangeScreenState extends State<CurrencyExchangeScreen> {
  final TextEditingController _yerController = TextEditingController();
  final ApiService _apiService = ApiService();

  String _selectedCurrency = 'USD';
  double _currentRate = 535.00;
  double _convertedResult = 0.0;
  List<CurrencyRateData> _rates = [];
  bool _isLoading = true;

  final Color primaryAppColor = const Color(0xFF07333B);

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  void _loadRates() async {
    try {
      final rates = await _apiService.getCurrencyRates();
      setState(() {
        _rates = rates.map((r) => CurrencyRateData.fromJson(r)).toList();
        _isLoading = false;
        if (_rates.isNotEmpty) _currentRate = _rates[0].rate;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _updateRate(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _selectedCurrency = newValue;
      final rate = _rates.firstWhere(
        (r) => newValue == 'USD' ? r.name.contains('دولار') : r.name.contains('سعودي'),
        orElse: () => CurrencyRateData(name: '', rate: 535.0, change: ''),
      );
      _currentRate = rate.rate;
      _calculateExchange(_yerController.text);
    });
  }

  void _calculateExchange(String value) {
    setState(() {
      double yerAmount = double.tryParse(value) ?? 0.0;
      _convertedResult = yerAmount > 0 ? yerAmount / _currentRate : 0.0;
    });
  }

  void _resetExchange() {
    HapticFeedback.lightImpact();
    setState(() {
      _yerController.clear();
      _convertedResult = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('أسعار الصرف المباشرة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF07333B))),
            const Text('تحديث فوري للسوق اليمني',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    if (_rates.length > 1)
                      Expanded(child: _buildCurrencyCard(_rates[1].name, _rates[1].rate.toStringAsFixed(2), _rates[1].change, const Color(0xFFEF5350))),
                    const SizedBox(width: 12),
                    if (_rates.isNotEmpty)
                      Expanded(child: _buildCurrencyCard(_rates[0].name, _rates[0].rate.toStringAsFixed(2), _rates[0].change, const Color(0xFF81C784))),
                  ],
                ),
            const SizedBox(height: 30),
            _buildExchangeCalculator(),
            const SizedBox(height: 25),
            _buildSmartTipCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildExchangeCalculator() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('حاسبة التحويل الذكية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryAppColor)),
              const SizedBox(width: 10),
              Icon(Icons.sync_alt_rounded, color: primaryAppColor, size: 22),
            ],
          ),
          const SizedBox(height: 25),
          const Text('المبلغ بالريال اليمني', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          TextField(
            controller: _yerController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryAppColor),
            decoration: InputDecoration(
              filled: true, fillColor: const Color(0xFFF1F3F4),
              hintText: '0.0',
              hintStyle: TextStyle(color: Colors.black.withOpacity(0.4), fontWeight: FontWeight.bold),
              prefixText: 'YER  ',
              prefixStyle: TextStyle(color: primaryAppColor.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
            onChanged: _calculateExchange,
          ),
          const SizedBox(height: 20),
          const Text('تحويل إلى', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4), borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCurrency,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryAppColor),
                alignment: AlignmentDirectional.centerEnd,
                items: <String>['USD', 'SAR'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value == 'USD' ? 'دولار أمريكي' : 'ريال سعودي', 
                      textAlign: TextAlign.right, style: TextStyle(color: primaryAppColor, fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                onChanged: _updateRate,
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Text('النتيجة التقريبية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFF1F3F4), borderRadius: BorderRadius.circular(15)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_selectedCurrency, style: TextStyle(color: primaryAppColor.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 13)),
                Text(_convertedResult.toStringAsFixed(2), style: TextStyle(color: primaryAppColor, fontWeight: FontWeight.bold, fontSize: 22)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _resetExchange,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryAppColor, minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
            ),
            child: const Text('تحديث الحساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyCard(String name, String rate, String change, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF07333B), Color(0xFF114352)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: primaryAppColor.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(name, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(rate, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(change, style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Mali Wallet', style: TextStyle(color: Color(0xFF07333B), fontWeight: FontWeight.bold, fontSize: 20)),
    );
  }

  Widget _buildSmartTipCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Expanded(
              child: Text('تحقق من أسعار الصرف الرسمية قبل أي عملية تحويل كبيرة لضمان أفضل قيمة.',
                  textAlign: TextAlign.right, style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4))),
          const SizedBox(width: 15),
          Icon(Icons.lightbulb_outline_rounded, color: Colors.amber[600], size: 24),
        ],
      ),
    );
  }
}
