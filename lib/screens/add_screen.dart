import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Box incomeBox;
  late Box investmentBox;
  final currencyFormat = NumberFormat.currency(locale: "tr_TR", symbol: "₺", decimalDigits: 2);
  
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  // Sabit renkler
  final Color primaryBlue = const Color(0xFF4361EE);
  final Color bgLight = const Color(0xFFF8F9FE);
  final Color textDark = const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    incomeBox = Hive.box('incomes');
    investmentBox = Hive.box('investments');
  }

  // --- GELİŞMİŞ FİLTRELEME MOTORU ---
  List<MapEntry<dynamic, dynamic>> _getFilteredList(Box box) {
    List<MapEntry<dynamic, dynamic>> results = [];
    DateTime viewDate = DateTime(_selectedYear, _selectedMonth, 28);
    Map<String, MapEntry<dynamic, dynamic>> recurringTracker = {};

    for (var i = 0; i < box.length; i++) {
      var key = box.keyAt(i);
      var item = box.getAt(i);
      if (item == null) continue;
      
      DateTime itemDate = DateTime.parse(item['date']);
      bool isRecurring = item['isRecurring'] == true;

      // Mantık: Sabit ise geçmişten bugüne en güncelini al, değilse sadece o ayı al
      if (isRecurring) {
        if (itemDate.isBefore(viewDate) || (itemDate.month == _selectedMonth && itemDate.year == _selectedYear)) {
          String title = item['title'].toString().toLowerCase().trim();
          if (!recurringTracker.containsKey(title) || itemDate.isAfter(DateTime.parse(recurringTracker[title]!.value['date']))) {
            recurringTracker[title] = MapEntry(key, item);
          }
        }
      } else {
        if (itemDate.month == _selectedMonth && itemDate.year == _selectedYear) {
          results.add(MapEntry(key, item));
        }
      }
    }
    results.addAll(recurringTracker.values);
    return results;
  }

  double _calculateTotal(Box box) {
    double total = 0;
    for (var entry in _getFilteredList(box)) {
      total += (double.tryParse(entry.value['amount'].toString()) ?? 0);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: incomeBox.listenable(),
          builder: (context, Box b1, _) => ValueListenableBuilder(
            valueListenable: investmentBox.listenable(),
            builder: (context, Box b2, _) {
              double inc = _calculateTotal(incomeBox);
              double inv = _calculateTotal(investmentBox);
              
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildMonthStrip(),
                    const SizedBox(height: 20),
                    _buildMainCard(inc, inv),
                    const SizedBox(height: 25),
                    _buildSection("Gelirler", incomeBox, "Gelir"),
                    const SizedBox(height: 15),
                    _buildSection("Yatırımlar", investmentBox, "Yatırım"),
                    const SizedBox(height: 80), // Alt boşluk
                  ],
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showEditorModal(type: "Gelir", isNew: true),
      ),
    );
  }

  // --- UI BİLEŞENLERİ ---

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Varlık Yönetimi", style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: textDark)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedYear,
              icon: Icon(Icons.keyboard_arrow_down, color: primaryBlue),
              items: [2024, 2025, 2026].map((y) => DropdownMenuItem(value: y, child: Text("$y", style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue)))).toList(),
              onChanged: (y) => setState(() => _selectedYear = y!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthStrip() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 12,
        itemBuilder: (context, i) {
          int m = i + 1;
          bool isSel = _selectedMonth == m;
          return GestureDetector(
            onTap: () => setState(() => _selectedMonth = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: isSel ? primaryBlue : Colors.white, borderRadius: BorderRadius.circular(14), border: isSel ? null : Border.all(color: Colors.black12)),
              child: Center(child: Text(DateFormat('MMMM', 'tr_TR').format(DateTime(2024, m)), style: TextStyle(color: isSel ? Colors.white : Colors.black54, fontWeight: FontWeight.bold))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainCard(double inc, double inv) {
    double total = inc + inv;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [textDark, const Color(0xFF2C2C2E)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("TOPLAM VARLIK", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)), Text(currencyFormat.format(total), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))]),
              Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.wallet, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: LinearProgressIndicator(value: total > 0 ? (inc / total) : 0, backgroundColor: Colors.white10, color: primaryBlue, minHeight: 6, borderRadius: BorderRadius.circular(4))),
            ],
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Nakit: ${currencyFormat.format(inc)}", style: const TextStyle(color: Colors.white70, fontSize: 11)), Text("Yatırım: ${currencyFormat.format(inv)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 11))]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Box box, String type) {
    var list = _getFilteredList(box);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: Icon(Icons.add_circle, color: primaryBlue), onPressed: () => _showEditorModal(type: type, isNew: true)),
          ],
        ),
        if (list.isEmpty) 
          Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Text("Bu ay için kayıt bulunamadı.", style: TextStyle(color: Colors.black45), textAlign: TextAlign.center))
        else
          ...list.map((entry) {
            return Dismissible(
              key: ValueKey(entry.key),
              direction: DismissDirection.endToStart,
              background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.redAccent, child: const Icon(Icons.delete, color: Colors.white)),
              onDismissed: (_) => box.delete(entry.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: type == "Gelir" ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), child: Icon(type == "Gelir" ? Icons.arrow_upward : Icons.pie_chart, color: type == "Gelir" ? Colors.green : Colors.orange, size: 20)),
                  title: Text(entry.value['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(entry.value['isRecurring'] ? "Otomatik Devreden" : "Tek Seferlik", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: Text(currencyFormat.format(entry.value['amount']), style: const TextStyle(fontWeight: FontWeight.w900)),
                  onTap: () => _showEditorModal(type: type, existingKey: entry.key, existingItem: entry.value, isNew: false),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  // --- EDITOR MODAL (EKLEME/DÜZENLEME) ---
  void _showEditorModal({required String type, dynamic existingKey, dynamic existingItem, required bool isNew}) {
    final TextEditingController amountCtrl = TextEditingController(text: existingItem != null ? NumberFormat.decimalPattern("tr_TR").format(existingItem['amount']) : "");
    String selectedTitle = existingItem?['title'] ?? (type == "Gelir" ? "Maaş" : "Altın");
    bool isRecurring = existingItem?['isRecurring'] ?? true;
    
    // Yatırım veya Gelir için hazır etiketler
    List<String> suggestions = type == "Gelir" ? ["Maaş", "Prim", "Kira", "Freelance"] : ["Altın", "Döviz", "Fon", "Borsa", "BES"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 24, right: 24),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                Text(isNew ? "Yeni $type Ekle" : "$type Düzenle", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                // Hızlı Seçim Butonları
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: suggestions.map((tag) {
                      bool isSel = selectedTitle == tag;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedTitle = tag),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: isSel ? primaryBlue : bgLight, borderRadius: BorderRadius.circular(20)),
                          child: Text(tag, style: TextStyle(color: isSel ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                  decoration: InputDecoration(
                    labelText: "Tutar",
                    prefixIcon: const Icon(Icons.currency_lira),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: bgLight,
                  ),
                ),
                const SizedBox(height: 15),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Her Ay Tekrarlasın mı?", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Sabit gelir/giderler için önerilir", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: isRecurring,
                  activeColor: primaryBlue,
                  onChanged: (val) => setModalState(() => isRecurring = val),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: textDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () {
                      if (amountCtrl.text.isEmpty) return;
                      
                      double finalAmount = double.tryParse(amountCtrl.text.replaceAll('.', '')) ?? 0;
                      final newData = {
                        'title': selectedTitle,
                        'amount': finalAmount,
                        'isRecurring': isRecurring,
                        'date': existingItem != null ? existingItem['date'] : DateTime(_selectedYear, _selectedMonth, 1).toIso8601String(),
                        'unit': "TRY" // Şimdilik varsayılan TRY
                      };
                      
                      final box = type == "Gelir" ? incomeBox : investmentBox;
                      if (existingKey != null) {
                        box.put(existingKey, newData);
                      } else {
                        box.add(newData);
                      }
                      
                      Navigator.pop(context);
                      setState(() {});
                    },
                    child: const Text("KAYDET", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Para birimi formatlayıcı (1000 -> 1.000)
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    double value = double.parse(newValue.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final formatter = NumberFormat.decimalPattern("tr_TR");
    String newText = formatter.format(value);
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}