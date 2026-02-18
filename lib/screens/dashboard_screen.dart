import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

// Arka planda kurları çeken servis dosyanı import ediyoruz
import '../currency_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late Box incomeBox;
  late Box investmentBox;
  Timer? _timer;
  
  final currencyFormat = NumberFormat.currency(locale: "tr_TR", symbol: "₺", decimalDigits: 2);
  
  // Varsayılan olarak bugünün yılı ve ayı
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  
  // Başlangıç değerleri
  Map<String, double> rates = {"TRY": 1.0, "USD": 0.0, "EUR": 0.0, "GRAM_ALTIN": 0.0};
  bool _isLoadingRates = true;

  // Tasarım Renkleri
  final Color primaryBlue = const Color(0xFF4361EE);
  final Color bgLight = const Color(0xFFF8F9FE);
  final Color textDark = const Color(0xFF1A1A1A);
  final Color textLight = const Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    incomeBox = Hive.box('incomes');
    investmentBox = Hive.box('investments');
    _fetchLiveRates();
    
    _timer = Timer.periodic(const Duration(seconds: 60), (Timer t) {
      if (mounted) _fetchLiveRates();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- CANLI KUR SERVİSİ ---
  Future<void> _fetchLiveRates() async {
    try {
      final liveData = await CurrencyService().getLiveRates();
      if (mounted) {
        setState(() {
          rates["USD"] = liveData['USD'] ?? 0.0;
          rates["EUR"] = liveData['EUR'] ?? 0.0;
          rates["GRAM_ALTIN"] = liveData['GRAM_ALTIN'] ?? 0.0;
          _isLoadingRates = false;
        });
      }
    } catch (e) {
      debugPrint("Kur çekme hatası: $e");
      if (mounted) setState(() => _isLoadingRates = false);
    }
  }

  // --- VERGİ VE MAAŞ MOTORU ---
  
  double _calculateRealCumulativeMatrah(int currentMonth) {
    double totalPastMatrah = 0.0;
    for (int m = 1; m < currentMonth; m++) {
      double monthGross = _getGrossForMonth(m, _selectedYear);
      if (monthGross > 0) {
         const double tavan = 247725.30; 
         double esasK = monthGross > tavan ? tavan : monthGross;
         double sgk = esasK * 0.14;
         double issizlik = esasK * 0.01;
         totalPastMatrah += (monthGross - sgk - issizlik);
      }
    }
    return totalPastMatrah;
  }

  double _calculateNetSalary(double grossAmount, int targetMonth) {
    if (grossAmount <= 0) return 0.0;
    
    final List<double> vergiDilimleri = [190000, 430000, 1280000, 4000000];
    final List<double> vergiOranlari = [0.15, 0.20, 0.27, 0.35, 0.40];
    const double asgariBrut = 33030.04; 
    const double sgkTavani = 247725.30; 
    
    double esasKazanc = grossAmount > sgkTavani ? sgkTavani : grossAmount;
    double sgkIsci = esasKazanc * 0.14;
    double issizlikIsci = esasKazanc * 0.01;
    double aylikMatrah = grossAmount - sgkIsci - issizlikIsci;

    double gercekKumulatifMatrah = _calculateRealCumulativeMatrah(targetMonth);
    double hamVergi = _calculateLayeredTax(aylikMatrah, gercekKumulatifMatrah, vergiDilimleri, vergiOranlari);
    
    double damgaVergisi = grossAmount * 0.00759;
    double araNet = grossAmount - sgkIsci - issizlikIsci - hamVergi - damgaVergisi;

    double asgariMatrah = asgariBrut * 0.85; 
    double asgariKumulatif = asgariMatrah * (targetMonth - 1);
    double gvIstisnasi = _calculateLayeredTax(asgariMatrah, asgariKumulatif, vergiDilimleri, vergiOranlari);
    double dvIstisnasi = asgariBrut * 0.00759; 

    return double.parse((araNet + gvIstisnasi + dvIstisnasi).toStringAsFixed(2));
  }

  double _calculateLayeredTax(double monthlyTaxable, double startCum, List<double> limits, List<double> rates) {
    double tax = 0;
    double remaining = monthlyTaxable;
    double currentCum = startCum;
    
    for (int i = 0; i < limits.length; i++) {
      if (currentCum < limits[i]) {
        double gap = limits[i] - currentCum;
        double taxableInThisBracket = remaining > gap ? gap : remaining;
        tax += taxableInThisBracket * rates[i];
        remaining -= taxableInThisBracket;
        currentCum += taxableInThisBracket;
      }
      if (remaining <= 0) break;
    }
    if (remaining > 0) tax += remaining * rates.last;
    return tax;
  }

  // DÜZELTİLDİ: Artık sadece ismi "Maaş" olanı değil, "isGross" (Brüt) olan her şeyi bulur.
  double _getGrossForMonth(int month, int year) {
    double lastFoundGross = 0.0;
    DateTime targetDate = DateTime(year, month, 28);
    
    var entries = incomeBox.values.where((item) {
      if (item == null) return false;
      
      // ÖNEMLİ DEĞİŞİKLİK: İsim kontrolünü kaldırdık, sadece Brüt mü diye bakıyoruz.
      bool isGross = item['isGross'] == true;
      
      DateTime itemDate = DateTime.parse(item['date']);
      bool dateValid = item['isRecurring'] == true 
          ? itemDate.isBefore(targetDate.add(const Duration(days: 1)))
          : (itemDate.month == month && itemDate.year == year);
          
      return isGross && dateValid;
    }).toList();

    if (entries.isNotEmpty) {
      entries.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
      lastFoundGross = double.tryParse(entries.last['grossAmount'].toString()) ?? 0.0;
    }
    return lastFoundGross;
  }

  double _calculateMonthlyIncome() {
    double total = 0.0;
    DateTime viewDate = DateTime(_selectedYear, _selectedMonth, 28);
    
    for (var item in incomeBox.values) {
      // Brüt maaşları burada atla, onları aşağıda özel hesaplayacağız
      if (item == null || item['isGross'] == true) continue;
      
      DateTime itemDate = DateTime.parse(item['date']);
      bool isActive = item['isRecurring'] == true 
          ? (itemDate.isBefore(viewDate.add(const Duration(days: 1))))
          : (itemDate.month == _selectedMonth && itemDate.year == _selectedYear);
          
      if (isActive) total += (double.tryParse(item['amount']?.toString() ?? "0") ?? 0.0);
    }
    
    // Brüt Maaş varsa hesapla ve ekle
    double currentGross = _getGrossForMonth(_selectedMonth, _selectedYear);
    if (currentGross > 0) {
      total += _calculateNetSalary(currentGross, _selectedMonth);
    }
    
    return total;
  }

  double _calculateCumulativeInvestment() {
    double totalTRY = 0.0;
    DateTime viewDate = DateTime(_selectedYear, _selectedMonth, 28);
    Map<String, dynamic> currentAssets = {};

    for (var item in investmentBox.values) {
      if (item == null) continue;
      DateTime itemDate = DateTime.parse(item['date']);
      
      if (itemDate.isBefore(viewDate.add(const Duration(days: 1)))) {
        String title = item['title'].toString().toLowerCase().trim();
        if (!currentAssets.containsKey(title) || itemDate.isAfter(DateTime.parse(currentAssets[title]['date']))) {
          currentAssets[title] = item;
        }
      }
    }
    
    currentAssets.forEach((k, v) {
      double quantity = double.tryParse(v['amount'].toString()) ?? 0.0;
      String unit = v['unit'] ?? "TRY";
      double rate = 1.0;
      if (unit == "USD") rate = rates["USD"] ?? 1.0;
      if (unit == "EUR") rate = rates["EUR"] ?? 1.0;
      if (unit == "XAU") rate = rates["GRAM_ALTIN"] ?? 1.0;
      totalTRY += quantity * rate;
    });
    return totalTRY;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder(
          valueListenable: incomeBox.listenable(),
          builder: (context, Box b1, _) => ValueListenableBuilder(
            valueListenable: investmentBox.listenable(),
            builder: (context, Box b2, _) {
              final double inc = _calculateMonthlyIncome();
              final double inv = _calculateCumulativeInvestment();
              
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildHeader(),
                  _buildLiveCurrencyStrip(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                      child: _buildMainCard(inc, inv),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                      child: Column(
                        children: [
                          _buildExpandableSection("Gelirler", incomeBox, "Gelir"),
                          const SizedBox(height: 15),
                          _buildExpandableSection("Yatırımlar", investmentBox, "Yatırım"),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- UI BİLEŞENLERİ ---

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text("PİYASA CANLI", style: GoogleFonts.plusJakartaSans(color: textLight, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ],
                ),
                _isLoadingRates 
                  ? const CupertinoActivityIndicator(radius: 8)
                  : GestureDetector(
                      onTap: _fetchLiveRates,
                      child: Icon(CupertinoIcons.refresh_circled_solid, size: 20, color: primaryBlue.withOpacity(0.5)),
                    ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Varlıklarım", style: GoogleFonts.plusJakartaSans(color: textDark, fontWeight: FontWeight.bold, fontSize: 28)),
                _buildYearPickerPopUp(),
              ],
            ),
            const SizedBox(height: 15),
            _buildMonthStrip(),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCurrencyStrip() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 5),
        child: Row(
          children: [
            _currencySmallCard("DOLAR", rates["USD"]!, "\$", Colors.green),
            const SizedBox(width: 10),
            _currencySmallCard("EURO", rates["EUR"]!, "€", Colors.blue),
            const SizedBox(width: 10),
            _currencySmallCard("ALTIN", rates["GRAM_ALTIN"]!, "gr", Colors.amber),
          ],
        ),
      ),
    );
  }

  Widget _currencySmallCard(String title, double val, String sign, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: textLight)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(sign, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(width: 4),
                FittedBox(
                  child: Text(
                    val == 0 ? "..." : val.toStringAsFixed(2), 
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)
                  )
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(double inc, double inv) {
    double balanceProgress = (inv / ((inc + inv) > 0 ? (inc + inv) : 1)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C1E), Color(0xFF3A3A3C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]
      ),
      child: Column(
        children: [
          Row(
            children: [
              _summaryItem("AYLIK NET GELİR", inc, Colors.white54),
              Container(width: 1, height: 30, color: Colors.white10),
              _summaryItem("TOPLAM VARLIK", inv, Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 25),
          _buildModernProgressBar("Yatırım Oranı", balanceProgress),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double value, Color labelColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(currencyFormat.format(value), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildModernProgressBar(String title, double percent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            Text("%${(percent * 100).toInt()}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableSection(String title, Box box, String type) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)],
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        leading: Icon(type == "Gelir" ? CupertinoIcons.money_dollar_circle : CupertinoIcons.chart_bar_square, color: primaryBlue),
        title: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: textDark, fontSize: 17)),
        trailing: IconButton(
          icon: const Icon(CupertinoIcons.plus_circle_fill, size: 24),
          color: primaryBlue,
          onPressed: () => _showEditorModal(type: type),
        ),
        children: [
          _buildDataList(box, type),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildDataList(Box box, String type) {
    final List<MapEntry> entries = [];
    DateTime viewDate = DateTime(_selectedYear, _selectedMonth, 28);
    
    for (var i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      final key = box.keyAt(i);
      if (item == null) continue;

      DateTime itemDate = DateTime.parse(item['date']);
      bool isRecurring = item['isRecurring'] == true;
      bool isCurrent = itemDate.month == _selectedMonth && itemDate.year == _selectedYear;
      
      bool isActive = isRecurring 
          ? (itemDate.isBefore(viewDate.add(const Duration(days: 1)))) 
          : isCurrent;

      if (isActive) {
        entries.add(MapEntry(key, item));
      }
    }

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text("Kayıt bulunamadı.", style: TextStyle(color: textLight, fontSize: 12)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final item = entry.value;
        final String unit = item['unit'] ?? "TRY";
        double amount = (double.tryParse(item['amount']?.toString() ?? "0") ?? 0.0);
        
        double rate = 1.0;
        if (type == "Yatırım") {
          if (unit == "USD") rate = rates["USD"] ?? 1.0;
          if (unit == "EUR") rate = rates["EUR"] ?? 1.0;
          if (unit == "XAU") rate = rates["GRAM_ALTIN"] ?? 1.0;
        }

        double displayValue = 0.0;
        
        // ÖNEMLİ DEĞİŞİKLİK: Sadece ismi "Maaş" olana bakmıyor, Brüt seçiliyse hesaplıyor.
        if (type == "Gelir" && item['isGross'] == true) {
           double gross = double.tryParse(item['grossAmount'].toString()) ?? 0.0;
           displayValue = _calculateNetSalary(gross, _selectedMonth);
        } else {
           displayValue = amount * rate;
        }

        return Dismissible(
          key: ValueKey(entry.key),
          direction: DismissDirection.endToStart,
          background: Container(
            padding: const EdgeInsets.only(right: 20),
            color: Colors.redAccent,
            alignment: Alignment.centerRight,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => box.delete(entry.key),
          child: ListTile(
            dense: true,
            leading: _getLeadingIcon(type, unit),
            title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("${item['isRecurring'] == true ? "Sabit" : "Tek Seferlik"} ${unit != 'TRY' ? '($amount $unit)' : ''}", style: const TextStyle(fontSize: 10)),
            trailing: Text(currencyFormat.format(displayValue), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            onTap: () => _showEditorModal(type: type, existingKey: entry.key, existingItem: item),
          ),
        );
      },
    );
  }

  void _showEditorModal({required String type, dynamic existingKey, dynamic existingItem}) {
    final tCon = TextEditingController(text: existingItem?['title'] ?? "");
    final aCon = TextEditingController(text: existingItem?['amount']?.toString() ?? "");
    final gCon = TextEditingController(text: existingItem?['grossAmount']?.toString() ?? "");
    
    bool isRec = existingItem?['isRecurring'] ?? false;
    bool isGross = existingItem?['isGross'] ?? false;
    String unit = existingItem?['unit'] ?? "TRY";
    
    ValueNotifier<double> liveTL = ValueNotifier(0.0);
    void updateLive() {
      double amt = double.tryParse(aCon.text) ?? 0.0;
      double r = 1.0;
      if (unit == "USD") r = rates["USD"] ?? 1.0;
      if (unit == "EUR") r = rates["EUR"] ?? 1.0;
      if (unit == "XAU") r = rates["GRAM_ALTIN"] ?? 1.0;
      liveTL.value = amt * r;
    }
    aCon.addListener(updateLive);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setMState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("$type Düzenle", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(controller: tCon, decoration: InputDecoration(hintText: "Başlık", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
              const SizedBox(height: 15),
              
              if (type == "Gelir") ...[
                Row(
                  children: [
                    const Text("Brüt Maaş mı?"),
                    const Spacer(),
                    Switch(value: isGross, onChanged: (v) => setMState(() => isGross = v)),
                  ],
                ),
                if (isGross) 
                  TextField(controller: gCon, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: "Brüt Tutar (Örn: 50000)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
              ],
              
              if (!isGross)
                Row(
                  children: [
                    Expanded(flex: 2, child: TextField(controller: aCon, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: "Miktar", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        items: ["TRY", "USD", "EUR", "XAU"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) { unit = v!; updateLive(); setMState(() {}); },
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                      ),
                    ),
                  ],
                ),
                
              ValueListenableBuilder(
                valueListenable: liveTL,
                builder: (context, double val, _) {
                  if (unit == "TRY" || val == 0) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text("= ${currencyFormat.format(val)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  );
                }
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  const Text("Her ay tekrarlansın"),
                  const Spacer(),
                  Switch(value: isRec, onChanged: (v) => setMState(() => isRec = v)),
                ],
              ),
              const SizedBox(height: 25),
              
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: () {
                    // SEÇİLİ OLAN AY VE YILA KAYDET
                    String recordDate;
                    if (existingItem != null) {
                       recordDate = existingItem['date'];
                    } else {
                       recordDate = DateTime(_selectedYear, _selectedMonth, 1).toIso8601String();
                    }

                    final data = {
                      'title': tCon.text,
                      'amount': double.tryParse(aCon.text) ?? 0.0,
                      'grossAmount': double.tryParse(gCon.text) ?? 0.0,
                      'isGross': isGross,
                      'isRecurring': isRec,
                      'unit': unit,
                      'date': recordDate,
                    };
                    
                    if (existingKey != null) (type == "Gelir" ? incomeBox : investmentBox).put(existingKey, data);
                    else (type == "Gelir" ? incomeBox : investmentBox).add(data);
                    
                    setState(() {}); 
                    Navigator.pop(context);
                  },
                  child: const Text("Kaydet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getLeadingIcon(String type, String unit) {
    IconData icon = type == "Gelir" ? CupertinoIcons.money_dollar : CupertinoIcons.chart_pie_fill;
    Color color = type == "Gelir" ? Colors.green : primaryBlue;
    if (unit == "XAU") color = Colors.amber;
    if (unit == "USD") color = Colors.green;
    if (unit == "EUR") color = Colors.blue;
    return CircleAvatar(radius: 16, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 16));
  }

  Widget _buildMonthStrip() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 12,
        itemBuilder: (context, index) {
          int m = index + 1;
          bool isSel = _selectedMonth == m;
          return GestureDetector(
            onTap: () => setState(() => _selectedMonth = m),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: isSel ? primaryBlue : Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(DateFormat('MMM', 'tr_TR').format(DateTime(2024, m)), style: TextStyle(color: isSel ? Colors.white : textDark, fontSize: 12, fontWeight: FontWeight.bold))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildYearPickerPopUp() {
    return PopupMenuButton<int>(
      onSelected: (y) => setState(() => _selectedYear = y),
      itemBuilder: (context) => [2024, 2025, 2026].map((y) => PopupMenuItem(value: y, child: Text("$y"))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Text("$_selectedYear", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryBlue)),
      ),
    );
  }
}