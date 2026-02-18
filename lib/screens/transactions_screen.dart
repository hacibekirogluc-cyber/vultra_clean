import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late Box spendingBox;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  final Color primaryBlue = const Color(0xFF4361EE);
  final Color secondaryBlue = const Color(0xFF3F37C9);
  final Color bgLight = const Color(0xFFF8F9FE);
  final Color textDark = const Color(0xFF1A1A1A);
  final Color textLight = const Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    spendingBox = Hive.box('spending');
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        height: 350,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text("Dönem Seçin", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: textDark)),
            const Divider(height: 30),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.monthYear,
                initialDateTime: DateTime(_selectedYear, _selectedMonth),
                onDateTimeChanged: (DateTime newDate) {
                  setState(() {
                    _selectedMonth = newDate.month;
                    _selectedYear = newDate.year;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("TAMAM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpenseEditor({Map? existingItem, int? index}) {
    TextEditingController amountCtrl = TextEditingController(
      text: existingItem != null ? NumberFormat.decimalPattern("tr_TR").format(existingItem['amount']) : ""
    );
    TextEditingController noteCtrl = TextEditingController(text: existingItem?['note'] ?? "");
    Map<String, dynamic>? selectedCategory;

    if (existingItem != null) {
      try {
        selectedCategory = AppData.categories.firstWhere((cat) => cat['name'] == existingItem['category']);
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 25),
              Text(existingItem == null ? "Yeni Harcama" : "İşlemi Düzenle", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: textDark)),
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: bgLight, borderRadius: BorderRadius.circular(24)),
                child: CupertinoTextField(
                  controller: amountCtrl,
                  autofocus: existingItem == null,
                  placeholder: "0,00",
                  prefix: Text("₺", style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 32)),
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: textDark),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                  decoration: null,
                ),
              ),
              const SizedBox(height: 16),

              CupertinoTextField(
                controller: noteCtrl,
                placeholder: "Kısa bir not ekleyin...",
                padding: const EdgeInsets.all(20),
                style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w600),
                decoration: BoxDecoration(color: bgLight, borderRadius: BorderRadius.circular(20)),
              ),
              const SizedBox(height: 24),

              Text("KATEGORİ SEÇİN", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: textLight, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppData.categories.length + 1,
                  itemBuilder: (context, i) {
                    final bool isOther = i == AppData.categories.length;
                    final cat = isOther ? {'name': 'Diğer', 'icon': Icons.grid_view_rounded, 'color': Colors.blueGrey} : AppData.categories[i];
                    bool isSelected = selectedCategory?['name'] == cat['name'];

                    return GestureDetector(
                      onTap: () => setModalState(() => selectedCategory = cat as Map<String, dynamic>),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryBlue : Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: isSelected ? primaryBlue : bgLight, width: 2),
                        ),
                        child: Row(
                          children: [
                            Icon(cat['icon'] as IconData, size: 18, color: isSelected ? Colors.white : textLight),
                            const SizedBox(width: 8),
                            Text(cat['name'] as String, style: TextStyle(color: isSelected ? Colors.white : textDark, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: textDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: () {
                    if (amountCtrl.text.isEmpty) return;
                    final data = {
                      'category': selectedCategory?['name'] ?? "Diğer",
                      'note': noteCtrl.text.trim(),
                      'amount': double.parse(amountCtrl.text.replaceAll('.', '').replaceAll(',', '.')),
                      'date': existingItem?['date'] ?? DateTime.now().toIso8601String(),
                      'icon': selectedCategory?['icon'] is IconData ? (selectedCategory?['icon'] as IconData).codePoint : 58823,
                      'color': (selectedCategory?['color'] as Color?)?.value ?? primaryBlue.value,
                    };
                    if (index != null) { spendingBox.putAt(index, data); } 
                    else { spendingBox.add(data); }
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: Text(existingItem == null ? "İŞLEMİ KAYDET" : "GÜNCELLE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder(
          valueListenable: spendingBox.listenable(),
          builder: (context, Box box, _) {
            final List<MapEntry<int, dynamic>> filteredList = [];
            for (int i = 0; i < box.length; i++) {
              var item = box.getAt(i);
              DateTime d = DateTime.parse(item['date']);
              if (d.month == _selectedMonth && d.year == _selectedYear) filteredList.add(MapEntry(i, item));
            }
            final expenses = filteredList.reversed.toList();
            double total = expenses.fold(0.0, (prev, e) => prev + (e.value['amount'] as num));

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("DÖNEMLİK", style: TextStyle(color: textLight, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Harcamalarım", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 32)),
                            GestureDetector(
                              onTap: () => _showExpenseEditor(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: Icon(Icons.add_rounded, color: primaryBlue, size: 28),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _showMonthPicker,
                          child: Row(
                            children: [
                              Text(DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(_selectedYear, _selectedMonth)), 
                                style: TextStyle(color: primaryBlue, fontSize: 14, fontWeight: FontWeight.w600)),
                              Icon(Icons.keyboard_arrow_down_rounded, color: primaryBlue, size: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [primaryBlue, secondaryBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("TOPLAM HARCAMA", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text("₺${NumberFormat.decimalPattern("tr_TR").format(total)}", 
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: Text("${expenses.length} İşlem", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Text("İŞLEMLER", style: TextStyle(color: textLight, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ),

                expenses.isEmpty 
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: Text("Henüz işlem yok", style: TextStyle(color: Colors.grey))),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 5, 24, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final entry = expenses[index];
                          return _buildDismissibleItem(entry.value, entry.key);
                        },
                        childCount: expenses.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- SOLA ÇEKİNCE SİLME ÖZELLİKLİ İTEM ---
  Widget _buildDismissibleItem(Map e, int originalIndex) {
    return Dismissible(
      key: Key(e['date'] + originalIndex.toString()), // Eşsiz anahtar
      direction: DismissDirection.endToStart, // Sadece sola çekince
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE63946),
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 25),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) async {
        await spendingBox.deleteAt(originalIndex);
        // Silme sonrası ana sayfadaki toplamların güncellenmesi için setState gerekebilir
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("İşlem başarıyla silindi"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: textDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
        ),
        child: ListTile(
          onTap: () => _showExpenseEditor(existingItem: e, index: originalIndex),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Color(e['color'] ?? 0xFF4361EE).withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: Icon(IconData(e['icon'] ?? 58823, fontFamily: 'MaterialIcons'), color: Color(e['color'] ?? 0xFF4361EE), size: 22),
          ),
          title: Text(e['note']?.isNotEmpty == true ? e['note'] : e['category'], style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
          subtitle: Text(DateFormat('d MMMM', 'tr_TR').format(DateTime.parse(e['date'])), style: TextStyle(color: textLight, fontSize: 12)),
          trailing: Text("-₺${NumberFormat.decimalPattern("tr_TR").format(e['amount'])}", 
            style: const TextStyle(color: Color(0xFFE63946), fontWeight: FontWeight.w900, fontSize: 16)),
        ),
      ),
    );
  }
}

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