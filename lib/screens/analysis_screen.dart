import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  // 0: Özet, 1: Raporlar
  int _mainTab = 0; 
  
  // 0: Harcamalar, 1: Kredi Kartı, 2: Kredi
  int _reportSubTab = 0; 
  
  DateTime _selectedDate = DateTime.now(); // Özet için
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1); // Rapor için
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0); // Rapor için

  late Box incomeBox;
  late Box spendingBox;
  List<dynamic> _allDebts = [];

  // --- STİL VE RENKLER (DÜZELTİLDİ) ---
  final Color primaryBlue = const Color(0xFF4361EE);
  final Color incomeGreen = const Color(0xFF00D26A);
  final Color expenseRed = const Color(0xFFFF565E);
  final Color textDark = const Color(0xFF1A1A1A); // EKSİK OLAN BU EKLENDİ
  final Color textGrey = const Color(0xFF94A3B8); // BU DA LAZIM OLABİLİR EKLENDİ
  
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: "tr_TR", symbol: "₺", decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    incomeBox = Hive.box('incomes');
    spendingBox = Hive.box('spending');
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('saved_debts');
    if (savedData != null) {
      setState(() {
        _allDebts = jsonDecode(savedData);
      });
    }
  }

  // --- HESAPLAMALAR ---
  double get totalIncome {
    double total = 0;
    for (var item in incomeBox.values) {
      DateTime d = DateTime.parse(item['date']);
      if (d.month == _selectedDate.month && d.year == _selectedDate.year) {
        total += (double.tryParse(item['amount'].toString()) ?? 0.0);
      }
    }
    return total;
  }

  double get totalGider {
    // 1. Harcamalar
    double spending = 0;
    for (var item in spendingBox.values) {
      var rd = item['date'];
      DateTime d = (rd is DateTime) ? rd : DateTime.tryParse(rd.toString()) ?? DateTime.now();
      if (d.month == _selectedDate.month && d.year == _selectedDate.year) {
        spending += (item['amount'] ?? 0.0);
      }
    }
    // 2. Kredi Taksitleri (Kartları burada gidere katmıyoruz, harcamalar zaten spending'de var)
    double debtPayments = 0;
    for (var debt in _allDebts) {
      if (debt['type'] == "Kredi") {
        debtPayments += (debt['monthlyInstallment'] ?? 0.0);
      }
    }
    return spending + debtPayments;
  }

  // Ödenen Kredileri Harcamalar Kutusundan Bul
  double get totalPaidLoans {
    double paid = 0;
    for (var item in spendingBox.values) {
      String cat = (item['category'] ?? "").toString().toLowerCase();
      if (cat.contains("kredi") || cat.contains("banka") || cat.contains("borç")) {
         paid += (item['amount'] ?? 0.0);
      }
    }
    return paid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text("Analiz", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true, backgroundColor: Colors.transparent, elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _buildMainNavigation(),
          Expanded(child: _mainTab == 0 ? _buildSummaryView() : _buildReportsView()),
        ],
      ),
    );
  }

  // --- 1. ÖZET GÖRÜNÜMÜ ---
  Widget _buildSummaryView() {
    double inc = totalIncome;
    double exp = totalGider;
    int days = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    double net = inc - exp;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildDateNavigator((d) => setState(() => _selectedDate = d), _selectedDate, true),
          const SizedBox(height: 30),
          Text("Net Akış", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          Text(_currencyFormat.format(net), style: GoogleFonts.plusJakartaSans(fontSize: 38, fontWeight: FontWeight.w900, color: net >= 0 ? incomeGreen : expenseRed)),
          const SizedBox(height: 30),
          Row(children: [
            Expanded(child: _miniStatCard("Gelir", inc, incomeGreen)),
            const SizedBox(width: 15),
            Expanded(child: _miniStatCard("Gider", exp, expenseRed)),
          ]),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              _dailyRow("Günlük Ortalama Gelir", inc/days, incomeGreen),
              const Divider(height: 30),
              _dailyRow("Günlük Ortalama Gider", exp/days, expenseRed),
            ]),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // --- 2. RAPORLAR GÖRÜNÜMÜ ---
  Widget _buildReportsView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               _datePill("Başlangıç", _startDate, (d) => setState(() => _startDate = d)),
               const Icon(Icons.arrow_right_alt, color: Colors.grey),
               _datePill("Bitiş", _endDate, (d) => setState(() => _endDate = d)),
            ],
          ),
        ),
        
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            _subTabBtn("Harcamalar", 0),
            _subTabBtn("Kredi Kartı Raporu", 1),
            _subTabBtn("Kredi Raporu", 2),
          ]),
        ),
        
        Expanded(child: _buildReportContent()),
      ],
    );
  }

  Widget _buildReportContent() {
    if (_reportSubTab == 0) return _buildDetailedSpendingList();
    if (_reportSubTab == 1) return _buildProCreditCardReport();
    return _buildLoanReport();
  }

  // --- 2.1 HARCAMALAR LİSTESİ ---
  Widget _buildDetailedSpendingList() {
    final filteredList = spendingBox.values.where((item) {
      DateTime d = DateTime.tryParse(item['date'].toString()) ?? DateTime.now();
      return d.isAfter(_startDate.subtract(const Duration(days: 1))) && 
             d.isBefore(_endDate.add(const Duration(days: 1)));
    }).toList();

    if (filteredList.isEmpty) return _emptyState("Bu tarihlerde harcama yok.");

    Map<String, List<dynamic>> groupedMap = {};
    for (var item in filteredList) {
      String cat = item['category'] ?? "Diğer";
      if (!groupedMap.containsKey(cat)) groupedMap[cat] = [];
      groupedMap[cat]!.add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: groupedMap.keys.length,
      itemBuilder: (context, index) {
        String category = groupedMap.keys.elementAt(index);
        List<dynamic> items = groupedMap[category]!;
        double totalAmount = items.fold(0, (sum, item) => sum + (item['amount'] ?? 0));

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _getCatColor(category).withOpacity(0.1), shape: BoxShape.circle), child: Icon(_getCatIcon(category), color: _getCatColor(category))),
              title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_currencyFormat.format(totalAmount), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
                  Text("${items.length} İşlem", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
              children: items.map((item) {
                DateTime date = DateTime.tryParse(item['date'].toString()) ?? DateTime.now();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(DateFormat('d MMMM, HH:mm', 'tr_TR').format(date), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                          if (item['note'] != null && item['note'].toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(item['note'], style: const TextStyle(fontSize: 13, color: Colors.black87))),
                      ]),
                      Text(_currencyFormat.format(item['amount']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ]),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // --- 2.2 PRO KREDİ KARTI RAPORU ---
  Widget _buildProCreditCardReport() {
    final cards = _allDebts.where((d) => d['type'] == "Kredi Kartı" || d['type'] == "Ek Hesap").toList();
    
    double totalDebt = cards.fold(0, (sum, item) => sum + (item['amount'] ?? 0));
    int cardCount = cards.length;
    double maxDebt = 0;
    String maxDebtBank = "-";
    
    for (var c in cards) {
      double amt = (c['amount'] ?? 0).toDouble();
      if (amt > maxDebt) {
        maxDebt = amt;
        maxDebtBank = c['bankName'];
      }
    }
    
    double minPayment = totalDebt * 0.20;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Toplam Kart Borcu", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(_currencyFormat.format(totalDebt), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black)),
          
          const SizedBox(height: 20),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: 0.6, minHeight: 12, color: Colors.orange, backgroundColor: Colors.grey[200])),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerRight, child: Text("Kullanım Yoğunluğu", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))),

          const SizedBox(height: 30),
          
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.5,
            children: [
              _infoBox(Icons.credit_card, "$cardCount Adet", "Aktif Kart", primaryBlue),
              _infoBox(Icons.star_border, _currencyFormat.format(maxDebt), "En Yüksek ($maxDebtBank)", Colors.redAccent),
              _infoBox(Icons.savings_outlined, _currencyFormat.format(minPayment), "Tahmini Asgari", Colors.orange),
              _infoBox(Icons.account_balance_wallet, _currencyFormat.format(totalDebt), "Toplam Borç", textDark), // ARTIK HATA VERMEYECEK
            ],
          ),
          
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                const Icon(Icons.date_range, color: Colors.orange),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Hesap Kesim Dönemleri", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepOrange)),
                      Text("Genellikle Ayın 1'i - 30'u Arası", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.deepOrange)),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- 2.3 KREDİ RAPORU ---
  Widget _buildLoanReport() {
    final loans = _allDebts.where((d) => d['type'] == "Kredi").toList();
    double total = loans.fold(0, (sum, item) => sum + item['amount']);
    double monthly = loans.fold(0, (sum, item) => sum + item['monthlyInstallment']);
    double paidTotal = totalPaidLoans;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Toplam Borç Durumu", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(_currencyFormat.format(total), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black)),
          
          const SizedBox(height: 20),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: 0.15, minHeight: 12, color: incomeGreen, backgroundColor: Colors.grey[200])),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: Text("%${paidTotal > 0 ? ((paidTotal / (total + paidTotal))*100).toInt() : 0} Ödendi", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),

          const SizedBox(height: 30),
          
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.5,
            children: [
              _infoBox(Icons.account_balance, "${loans.length} Adet", "Aktif Kredi", primaryBlue),
              _infoBox(Icons.calendar_today, _currencyFormat.format(monthly), "Aylık Taksit", Colors.orange),
              _infoBox(Icons.check_circle_outline, _currencyFormat.format(paidTotal), "Toplam Ödenen", incomeGreen),
              _infoBox(Icons.hourglass_bottom, _currencyFormat.format(total), "Kalan Borç", expenseRed),
            ],
          ),
          
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: Color(0xFF2E7D32)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Tahmini Bitiş Tarihi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1B5E20))),
                      Text(_calcEndDate(total, monthly), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B5E20))),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- UI YARDIMCILARI ---

  Widget _buildMainNavigation() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20), padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
      child: Row(children: [
        _navBtn("Özet", 0), 
        _navBtn("Raporlar", 1), 
      ]),
    );
  }

  Widget _navBtn(String label, int idx) {
    bool isSel = _mainTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mainTab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSel ? primaryBlue : Colors.transparent, borderRadius: BorderRadius.circular(25)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSel ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildDateNavigator(Function(DateTime) onChange, DateTime date, bool isMonth) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => onChange(DateTime(date.year, date.month - 1))),
      Text(DateFormat(isMonth ? 'MMMM yyyy' : 'd MMM yyyy', 'tr_TR').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => onChange(DateTime(date.year, date.month + 1))),
    ]);
  }

  Widget _datePill(String label, DateTime date, Function(DateTime) onPick) {
    return GestureDetector(
      onTap: () async {
        DateTime? picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2023), lastDate: DateTime(2030));
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
        child: Row(children: [
          Text(DateFormat('d MMM', 'tr_TR').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 5),
          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _miniStatCard(String label, double val, Color col) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        const SizedBox(height: 5),
        FittedBox(child: Text(_currencyFormat.format(val), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20))),
      ]),
    );
  }

  Widget _dailyRow(String title, double val, Color col) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.show_chart, color: col, size: 18)),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        Text(_currencyFormat.format(val), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ]))
    ]);
  }

  Widget _subTabBtn(String label, int idx) {
    bool isSel = _reportSubTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _reportSubTab = idx),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: isSel ? const Color(0xFFD8E5FF) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSel ? primaryBlue : Colors.grey.shade200)),
        child: Text(label, style: TextStyle(color: isSel ? primaryBlue : Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _infoBox(IconData icon, String val, String label, Color col) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: col), const SizedBox(height: 8),
        FittedBox(child: Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }

  Widget _emptyState(String msg) => Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(msg, style: const TextStyle(color: Colors.grey))));

  String _calcEndDate(double total, double monthly) {
    if (monthly <= 0) return "Belirsiz";
    int months = (total / monthly).ceil();
    DateTime end = DateTime.now().add(Duration(days: months * 30));
    return DateFormat('MMMM yyyy', 'tr_TR').format(end);
  }
  
  IconData _getCatIcon(String cat) {
    if (cat.contains("Market")) return Icons.shopping_cart;
    if (cat.contains("Yemek")) return Icons.restaurant;
    if (cat.contains("Fatura")) return Icons.bolt;
    if (cat.contains("Yakıt")) return Icons.local_gas_station;
    return Icons.category;
  }

  Color _getCatColor(String cat) {
    if (cat.contains("Market")) return Colors.green;
    if (cat.contains("Yemek")) return Colors.orange;
    if (cat.contains("Fatura")) return Colors.purple;
    return primaryBlue;
  }
}