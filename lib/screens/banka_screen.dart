import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

// --- GELİŞMİŞ BORÇ MODELİ ---
class Debt {
  String bankName;
  String logo;
  double amount;
  double limit; 
  double monthlyInstallment;
  int payDay;
  int statementDay; 
  int lastPaymentOffset; 
  String type;
  int totalMonths; 
  int paidMonths;  
  bool isPaidThisMonth; 

  Debt({
    required this.bankName, 
    required this.logo, 
    required this.amount, 
    this.limit = 0, 
    required this.monthlyInstallment, 
    required this.payDay, 
    this.statementDay = 15, 
    this.lastPaymentOffset = 10, 
    required this.type,
    this.totalMonths = 1,
    this.paidMonths = 0,
    this.isPaidThisMonth = false,
  });

  double get minimumPayment {
    if (type != "Kredi Kartı") return amount;
    double rate = (limit > 100000) ? 0.40 : 0.20;
    return amount * rate;
  }

  Map<String, dynamic> toJson() => {
    'bankName': bankName,
    'logo': logo,
    'amount': amount,
    'limit': limit,
    'monthlyInstallment': monthlyInstallment,
    'payDay': payDay,
    'statementDay': statementDay,
    'lastPaymentOffset': lastPaymentOffset,
    'type': type,
    'totalMonths': totalMonths,
    'paidMonths': paidMonths,
    'isPaidThisMonth': isPaidThisMonth,
  };

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
    bankName: json['bankName'] ?? 'Bilinmeyen Banka',
    logo: json['logo'] ?? '',
    amount: (json['amount'] ?? 0.0).toDouble(),
    limit: (json['limit'] ?? 0.0).toDouble(),
    monthlyInstallment: (json['monthlyInstallment'] ?? 0.0).toDouble(),
    payDay: json['payDay'] ?? 1,
    statementDay: json['statementDay'] ?? 15,
    lastPaymentOffset: json['lastPaymentOffset'] ?? 10,
    type: json['type'] ?? 'Genel',
    totalMonths: json['totalMonths'] ?? 1,
    paidMonths: json['paidMonths'] ?? 0,
    isPaidThisMonth: json['isPaidThisMonth'] ?? false,
  );
}

// --- FORMATLAYICILAR ---

// Para Birimi Formatter (Binlik Ayırıcı)
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String numOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numOnly.isEmpty) return const TextEditingValue();
    final double value = double.parse(numOnly);
    final formatter = NumberFormat("#,###", "tr_TR");
    String newText = formatter.format(value);
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

// Faiz Formatter (Örn: 222 -> 2,22)
class InterestRateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String numOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numOnly.isEmpty) return const TextEditingValue();
    double value = double.parse(numOnly) / 100;
    String newText = value.toStringAsFixed(2).replaceAll('.', ',');
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class BankaScreen extends StatefulWidget {
  const BankaScreen({super.key});
  @override
  State<BankaScreen> createState() => _BankaScreenState();
}

class _BankaScreenState extends State<BankaScreen> {
  bool _showBankSelection = false;
  List<Debt> myDebts = [];
  Map<String, dynamic>? _selectedBank;
  String? _selectedCategory;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _limitController = TextEditingController(); 
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _termController = TextEditingController();
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _customBankNameController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  final TextEditingController _paidMonthsController = TextEditingController();

  int _tempStatementDay = 15;
  int _tempOffset = 10;

  final List<Map<String, dynamic>> _turkishBanks = [
    {'name': 'Akbank', 'logo': 'assets/logos/akbank.png', 'color': const Color(0xFFE30613)},
    {'name': 'Garanti BBVA', 'logo': 'assets/logos/garanti.png', 'color': const Color(0xFF007A33)},
    {'name': 'İş Bankası', 'logo': 'assets/logos/isbank.png', 'color': const Color(0xFF003399)},
    {'name': 'Yapı Kredi', 'logo': 'assets/logos/yapikredi.png', 'color': const Color(0xFF5A2D81)},
    {'name': 'QNB', 'logo': 'assets/logos/qnb.png', 'color': const Color(0xFF002D72)},
    {'name': 'Ziraat Bankası', 'logo': 'assets/logos/ziraat.png', 'color': const Color(0xFF8C0000)},
    {'name': 'Enpara', 'logo': 'assets/logos/enpara.png', 'color': const Color(0xFF75237C)},
    {'name': 'VakıfBank', 'logo': 'assets/logos/vakifbank.png', 'color': const Color(0xFFFDB913)},
    {'name': 'Halkbank', 'logo': 'assets/logos/halkbank.png', 'color': const Color(0xFF0096D1)},
    {'name': 'Denizbank', 'logo': 'assets/logos/denizbank.png', 'color': const Color(0xFF004B91)},
    {'name': 'TEB', 'logo': 'assets/logos/teb.png', 'color': const Color(0xFF008136)},
    {'name': 'Diğer', 'logo': '', 'color': const Color(0xFF1E264D)},
  ];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null).then((_) {
      _loadFromDisk().then((_) => _checkAndResetMonthlyPayments());
    });
  }

  double _calculateLoanInstallment() {
    double P = double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
    double monthlyRate = (double.tryParse(_rateController.text.replaceAll(',', '.')) ?? 0) / 100;
    int n = int.tryParse(_termController.text) ?? 0;
    if (P <= 0 || monthlyRate <= 0 || n <= 0) return 0;
    return (P * monthlyRate * pow(1 + monthlyRate, n)) / (pow(1 + monthlyRate, n) - 1);
  }

  Color _getBankColor(String name) {
    try {
      return _turkishBanks.firstWhere((b) => name.contains(b['name']), orElse: () => _turkishBanks.last)['color'];
    } catch (_) {
      return const Color(0xFF1E264D);
    }
  }

  Future<void> _checkAndResetMonthlyPayments() async {
    final prefs = await SharedPreferences.getInstance();
    int currentMonth = DateTime.now().month;
    int currentYear = DateTime.now().year;
    int lastUpdateMonth = prefs.getInt('last_update_month') ?? currentMonth;
    int lastUpdateYear = prefs.getInt('last_update_year') ?? currentYear;

    if (currentMonth != lastUpdateMonth || currentYear != lastUpdateYear) {
      setState(() {
        for (var debt in myDebts) debt.isPaidThisMonth = false;
      });
      await prefs.setInt('last_update_month', currentMonth);
      await prefs.setInt('last_update_year', currentYear);
      _saveToDisk();
    }
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('saved_debts');
    if (savedData != null) {
      final List<dynamic> decoded = jsonDecode(savedData);
      setState(() {
        myDebts = decoded.map((d) => Debt.fromJson(d)).toList();
      });
    }
  }

  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    String encodedData = jsonEncode(myDebts.map((d) => d.toJson()).toList());
    await prefs.setString('saved_debts', encodedData);
  }

  String _formatDisplay(double val) {
    if (val < 0) val = 0;
    final formatter = NumberFormat("#,###", "tr_TR");
    return formatter.format(val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: _showBankSelection 
          ? _buildBankSelection() 
          : (myDebts.isEmpty ? _buildEmptyState() : _buildAccountsDashboard()),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Bankalar", style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -1)),
          const Spacer(),
          Center(
            child: Column(
              children: [
                SizedBox(
                  height: 200, width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4361EE).withOpacity(0.05))),
                      _creativeCard(const Color(0xFF1E264D), -15, 0),
                      _creativeCard(const Color(0xFF4361EE), 15, 20),
                      const Icon(CupertinoIcons.shield_fill, size: 50, color: Colors.white),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                const Text("Hesaplarınız Güvende", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Text("Tüm borçlarını tek bir yerden\n yönetmeye başla.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5)),
                const SizedBox(height: 35),
                _buildActionButton("Banka Hesabı Ekle", () => setState(() => _showBankSelection = true)),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildAccountsDashboard() {
    Map<String, List<Debt>> groupedByBank = {};
    for (var debt in myDebts) {
      if (!groupedByBank.containsKey(debt.bankName)) {
        groupedByBank[debt.bankName] = [];
      }
      groupedByBank[debt.bankName]!.add(debt);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("VULTRA FINANCE", style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    Text("Hesaplarım", style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
                  ],
                ),
                GestureDetector(
                  onTap: () => setState(() => _showBankSelection = true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: const Icon(CupertinoIcons.plus, color: Color(0xFF4361EE), size: 24),
                  ),
                ),
              ],
            ),
          ),
          _buildBankWalletSlider(groupedByBank),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildTypeGroup("Kredi Kartı", "KREDİ KARTLARI", CupertinoIcons.creditcard_fill),
                _buildTypeGroup("Kredi", "AKTİF KREDİLER", CupertinoIcons.money_dollar_circle_fill),
                _buildTypeGroup("Ek Hesap", "EK HESAPLAR / KMH", CupertinoIcons.arrow_right_circle_fill),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildBankWalletSlider(Map<String, List<Debt>> groupedByBank) {
    var bankNames = groupedByBank.keys.toList();
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: bankNames.length,
        itemBuilder: (context, index) {
          String bName = bankNames[index];
          List<Debt> bankDebts = groupedByBank[bName]!;
          double totalBankDebt = bankDebts.fold(0, (sum, d) => sum + d.amount);
          Color bankColor = _getBankColor(bName);
          
          Debt? cc = bankDebts.where((d) => d.type == "Kredi Kartı").firstOrNull;
          Debt? loan = bankDebts.where((d) => d.type == "Kredi").firstOrNull;

          return GestureDetector(
            onTap: () { if(cc != null) _showCardDetails(cc); },
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              margin: const EdgeInsets.only(right: 15),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [bankColor, bankColor.withOpacity(0.85)]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: bankColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(bName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const Icon(CupertinoIcons.waveform_circle, color: Colors.white70, size: 24),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("TOPLAM BORÇ", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    Text("₺${_formatDisplay(totalBankDebt)}", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    if(loan != null) Text("Kredi: ₺${_formatDisplay(loan.amount)}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                  if(cc != null) ...[
                    Column(
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text("Limit: ₺${_formatDisplay(cc.limit)}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          Text("Kullanılabilir: ₺${_formatDisplay(cc.limit - cc.amount)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: cc.limit > 0 ? (cc.limit - cc.amount) / cc.limit : 0,
                            backgroundColor: Colors.white24,
                            color: Colors.greenAccent,
                            minHeight: 4,
                          ),
                        )
                      ],
                    )
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCardDetails(Debt cc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${cc.bankName} Detayları", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            _infoRow("Toplam Limit", "₺${_formatDisplay(cc.limit)}"),
            _infoRow("Güncel Borç", "₺${_formatDisplay(cc.amount)}", color: Colors.red),
            _infoRow("Kullanılabilir Limit", "₺${_formatDisplay(cc.limit - cc.amount)}", color: Colors.green),
            _infoRow("Hesap Kesim Günü", "${cc.statementDay}"),
            _infoRow("Son Ödeme Günü", "Ayın ${cc.payDay}. Günü"),
            const SizedBox(height: 20),
            _buildActionButton("ÖDEME YAP", () { Navigator.pop(context); _showPaymentSheet(cc); }),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  void _showPaymentSheet(Debt debt) {
    _paymentController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("${debt.bankName} Ödemesi", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if(debt.type == "Kredi Kartı") ...[
            _paymentOptionTile(
              icon: CupertinoIcons.money_dollar_circle,
              title: "Dönem Borcunun Tamamı",
              value: "₺${_formatDisplay(debt.amount)}",
              onTap: () => _processPayment(debt, debt.amount),
            ),
            const SizedBox(height: 12),
            _paymentOptionTile(
              icon: CupertinoIcons.percent,
              title: "Asgari Tutar",
              value: "₺${_formatDisplay(debt.minimumPayment)}",
              onTap: () => _processPayment(debt, debt.minimumPayment),
            ),
          ] else ...[
            _paymentOptionTile(
              icon: CupertinoIcons.money_dollar_circle,
              title: "Taksit Öde",
              value: "₺${_formatDisplay(debt.monthlyInstallment > 0 ? debt.monthlyInstallment : debt.amount)}",
              onTap: () => _processPayment(debt, debt.monthlyInstallment > 0 ? debt.monthlyInstallment : debt.amount, isInstallment: true),
            ),
          ],
          const SizedBox(height: 20),
          _buildClassicField(_paymentController, "Diğer Tutar", "₺", (v) {}, isAmount: true),
          _buildActionButton("ÖDEMEYİ TAMAMLA", () {
            double amt = double.tryParse(_paymentController.text.replaceAll('.', '')) ?? 0;
            if (amt > 0) _processPayment(debt, amt);
          }),
          const SizedBox(height: 32),
        ]),
      )),
    );
  }

  void _processPayment(Debt debt, double amount, {bool isInstallment = false}) {
    setState(() {
      debt.amount -= amount;
      debt.isPaidThisMonth = true;
      if (isInstallment) debt.paidMonths += 1;
      
      if (debt.amount <= 0 || (debt.type == "Kredi" && debt.paidMonths >= debt.totalMonths)) {
        if (debt.type == "Kredi") myDebts.remove(debt);
        else debt.amount = 0;
      }
    });
    _saveToDisk();
    Navigator.pop(context);
  }

  // --- PREMIUM EKLEME EKRANI ---
  void _showAppleStyleForm(String title) {
    _amountController.clear();
    _limitController.clear();
    _rateController.clear();
    _termController.clear();
    _dayController.clear();
    _paidMonthsController.clear();
    _customBankNameController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FE),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 12
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E264D))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey))
                ],
              ),
              const SizedBox(height: 20),

              // Ana Tutar Kartı (Premium Görünüm)
              _buildValueCard(
                _selectedCategory == "Kredi Kartı" ? "GÜNCEL BORÇ" : "TOPLAM TUTAR",
                _amountController,
                CurrencyInputFormatter(),
                (v) => setModalState(() {}),
              ),
              
              const SizedBox(height: 20),

              // Form Alanları Grupları
              if (_selectedCategory == "Kredi Kartı") ...[
                _buildSectionTitle("Kart Detayları"),
                _buildModernInput(_limitController, "Kart Limiti", suffix: "₺", formatter: CurrencyInputFormatter()),
                const SizedBox(height: 12),
                _buildSectionTitle("Tarih Ayarları"),
                _buildModernPicker("Hesap Kesim", "$_tempStatementDay. Gün", () {
                   _showPremiumDatePicker(context, "Kesim Günü", _tempStatementDay, (val) => setModalState(() => _tempStatementDay = val));
                }),
                _buildModernPicker("Son Ödeme", "Kesimden $_tempOffset gün sonra", () {
                   _showPremiumDatePicker(context, "Kaç Gün Sonra?", _tempOffset, (val) => setModalState(() => _tempOffset = val), max: 15);
                }),
              ],

              if (_selectedCategory == "Kredi") ...[
                _buildSectionTitle("Kredi Bilgileri"),
                Row(
                  children: [
                    Expanded(child: _buildModernInput(_rateController, "Faiz Oranı", suffix: "%", formatter: InterestRateFormatter(), onChanged: (v) => setModalState(() {}))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildModernInput(_termController, "Vade", suffix: "Ay", onChanged: (v) => setModalState(() {}))),
                  ],
                ),
                _buildModernInput(_paidMonthsController, "Ödenmiş Taksit", suffix: "Ay"),
                _buildModernInput(_dayController, "Taksit Günü (Ayın Kaçı?)", suffix: "."),
                
                // Dinamik Taksit Bilgi Kartı
                if(_calculateLoanInstallment() > 0)
                  _buildInstallmentBanner(),
              ],

              if (_selectedCategory == "Ek Hesap") ...[
                _buildSectionTitle("KMH Detayları"),
                _buildModernInput(_dayController, "Ödeme Günü", suffix: "."),
              ],

              const SizedBox(height: 24),
              _buildActionButton("HESABI KAYDET", () {
                _saveDebt();
                Navigator.pop(context);
              }),
              const SizedBox(height: 30),
            ],
          ),
        ),
      )),
    );
  }

  // --- PREMIUM WIDGETLAR ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 1.1)),
      ),
    );
  }

  Widget _buildValueCard(String label, TextEditingController ctrl, TextInputFormatter formatter, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E264D), Color(0xFF4361EE)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF4361EE).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text("₺", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [formatter],
                  onChanged: onChanged,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  decoration: const InputDecoration(hintText: "0", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.greenAccent.withOpacity(0.5))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("AYLIK TAKSİT", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
            Text("Hesaplanan Tutar", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          Text("₺${_formatDisplay(_calculateLoanInstallment())}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4361EE))),
        ],
      ),
    );
  }

  Widget _buildModernInput(TextEditingController ctrl, String hint, {String suffix = "", TextInputFormatter? formatter, Function(String)? onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        inputFormatters: formatter != null ? [formatter] : [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: hint,
          suffixText: suffix,
          suffixStyle: const TextStyle(color: Color(0xFF4361EE), fontWeight: FontWeight.bold),
          border: InputBorder.none,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.normal),
        ),
      ),
    );
  }

  Widget _buildModernPicker(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
            Row(
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4361EE))),
                const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumDatePicker(BuildContext context, String title, int initial, Function(int) onSelect, {int max = 31}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        height: 350,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: initial - 1),
                itemExtent: 45,
                onSelectedItemChanged: (i) => onSelect(i + 1),
                children: List.generate(max, (i) => Center(child: Text("${i + 1}", style: const TextStyle(fontSize: 20)))),
              ),
            ),
            const SizedBox(height: 20),
            _buildActionButton("SEÇİMİ TAMAMLA", () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  // --- KAYDETME MANTIĞI ---
  void _saveDebt() {
    String finalName = (_selectedBank!['name'] == 'Diğer') 
        ? (_customBankNameController.text.isEmpty ? "Banka Hesabı" : _customBankNameController.text) 
        : _selectedBank!['name'];
        
    double amt = double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
    
    Debt newDebt;

    if (_selectedCategory == "Kredi Kartı") {
      newDebt = Debt(
        bankName: finalName,
        logo: _selectedBank!['logo'] ?? '',
        amount: amt,
        limit: double.tryParse(_limitController.text.replaceAll('.', '')) ?? 0,
        monthlyInstallment: 0,
        statementDay: _tempStatementDay,
        lastPaymentOffset: _tempOffset,
        payDay: (_tempStatementDay + _tempOffset) > 31 ? (_tempStatementDay + _tempOffset) - 31 : (_tempStatementDay + _tempOffset),
        type: "Kredi Kartı",
      );
    } else if (_selectedCategory == "Kredi") {
      double installment = _calculateLoanInstallment();
      newDebt = Debt(
        bankName: finalName,
        logo: _selectedBank!['logo'] ?? '',
        amount: amt,
        monthlyInstallment: installment,
        payDay: int.tryParse(_dayController.text) ?? 1,
        type: "Kredi",
        totalMonths: int.tryParse(_termController.text) ?? 1,
        paidMonths: int.tryParse(_paidMonthsController.text) ?? 0,
      );
    } else {
      newDebt = Debt(
        bankName: finalName,
        logo: _selectedBank!['logo'] ?? '',
        amount: amt,
        monthlyInstallment: 0,
        payDay: int.tryParse(_dayController.text) ?? 1,
        type: "Ek Hesap",
      );
    }

    setState(() { myDebts.add(newDebt); _showBankSelection = false; });
    _saveToDisk();
  }

  Widget _buildBankSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              IconButton(onPressed: () => setState(() => _showBankSelection = false), icon: const Icon(Icons.arrow_back_ios)),
              const Text("Banka Seçin", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.5, crossAxisSpacing: 15, mainAxisSpacing: 15),
            itemCount: _turkishBanks.length,
            itemBuilder: (context, index) {
              final bank = _turkishBanks[index];
              return InkWell(
                onTap: () {
                  setState(() { _selectedBank = bank; });
                  _showCategorySelection();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      bank['logo'].toString().isNotEmpty 
                        ? Image.asset(bank['logo'], height: 40, errorBuilder: (c,e,s) => const Icon(Icons.account_balance))
                        : const Icon(Icons.account_balance, size: 40),
                      const SizedBox(height: 10),
                      Text(bank['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCategorySelection() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text("Hesap Türü"),
        actions: [
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); setState(() => _selectedCategory = "Kredi Kartı"); _showAppleStyleForm("Yeni Kredi Kartı"); }, child: const Text("Kredi Kartı")),
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); setState(() => _selectedCategory = "Kredi"); _showAppleStyleForm("Yeni Kredi"); }, child: const Text("Kredi")),
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); setState(() => _selectedCategory = "Ek Hesap"); _showAppleStyleForm("Ek Hesap / KMH"); }, child: const Text("Ek Hesap / KMH")),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
      ),
    );
  }

  Widget _buildTypeGroup(String type, String title, IconData icon) {
    final filtered = myDebts.where((d) => d.type == type).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        Row(children: [Icon(icon, size: 14, color: Colors.grey), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2))]),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
          child: ListView.separated(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: filtered.length,
            separatorBuilder: (context, index) => Divider(height: 1, indent: 70, color: Colors.grey.withOpacity(0.05)),
            itemBuilder: (context, index) {
              final debt = filtered[index];
              return Dismissible(
                key: UniqueKey(),
                direction: DismissDirection.endToStart,
                background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.red, child: const Icon(CupertinoIcons.trash, color: Colors.white)),
                onDismissed: (direction) {
                  setState(() => myDebts.remove(debt));
                  _saveToDisk();
                },
                child: ListTile(
                  onTap: () => _editDebt(debt),
                  leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(15)), child: (debt.logo.isNotEmpty) ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.asset(debt.logo, errorBuilder: (c,e,s) => const Icon(Icons.account_balance))) : const Icon(Icons.account_balance, color: Color(0xFF4361EE))),
                  title: Text(debt.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text("Ödeme: Ayın ${debt.payDay}. Günü", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text("₺${_formatDisplay(debt.amount)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    GestureDetector(onTap: () => _showPaymentSheet(debt), child: Text(debt.isPaidThisMonth ? "ÖDENDİ" : "ÖDE >", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: debt.isPaidThisMonth ? Colors.green : const Color(0xFF4361EE)))),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _editDebt(Debt debt) {
    _amountController.text = _formatDisplay(debt.amount);
    _dayController.text = debt.payDay.toString();
    _termController.text = debt.totalMonths.toString();
    _paidMonthsController.text = debt.paidMonths.toString();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${debt.bankName} Düzenle", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(CupertinoIcons.trash, color: Colors.red), onPressed: () {
                setState(() { myDebts.remove(debt); });
                _saveToDisk();
                Navigator.pop(context);
              }),
            ],
          ),
          const SizedBox(height: 24),
          _buildClassicField(_amountController, "Güncel Kalan Borç", "₺", (v) => setModalState(() {}), isAmount: true),
          if (debt.type == "Kredi") ...[
            _buildClassicField(_termController, "Toplam Vade", "Ay", (v) => setModalState(() {})),
            _buildClassicField(_paidMonthsController, "Ödenmiş Taksit", "Ay", (v) => setModalState(() {})),
          ],
          _buildClassicField(_dayController, "Ödeme Günü", "", (v) {}),
          _buildActionButton("GÜNCELLE", () {
            setState(() {
              debt.amount = double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
              debt.payDay = int.tryParse(_dayController.text) ?? 1;
              debt.totalMonths = int.tryParse(_termController.text) ?? debt.totalMonths;
              debt.paidMonths = int.tryParse(_paidMonthsController.text) ?? debt.paidMonths;
            });
            _saveToDisk();
            Navigator.pop(context);
          }),
          const SizedBox(height: 32),
        ]),
      )),
    );
  }

  Widget _creativeCard(Color color, double rotate, double xOffset) {
    return Transform.translate(
      offset: Offset(xOffset, 0),
      child: Transform.rotate(
        angle: rotate * pi / 180,
        child: Container(
          width: 140, height: 90,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)]
          ),
        ),
      ),
    );
  }

  Widget _buildClassicField(TextEditingController ctrl, String label, String suffix, Function(String) onChanged, {bool isAmount = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          inputFormatters: isAmount ? [CurrencyInputFormatter()] : [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            suffixText: suffix,
            filled: true,
            fillColor: const Color(0xFFF2F2F7),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActionButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E264D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 4,
          shadowColor: const Color(0xFF1E264D).withOpacity(0.4),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
  }

  Widget _paymentOptionTile({required IconData icon, required String title, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFF8F9FE), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black.withOpacity(0.05))),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF4361EE)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))])),
          const Icon(Icons.chevron_right, color: Colors.grey)
        ]),
      ),
    );
  }
}