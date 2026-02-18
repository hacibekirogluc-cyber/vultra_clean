import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart'; 
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

// EKRAN IMPORTLARI
import 'screens/analysis_screen.dart'; // Analiz sayfası
import 'currency_service.dart';
import 'screens/profile_screen.dart';
import 'notification_service.dart'; 
import 'screens/dashboard_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/banka_screen.dart'; 
import 'screens/calender_finance.dart';
import 'screens/login_screen.dart'; 

// --- DEBT SINIFI (AYNEN KORUNDU) ---
class Debt {
  String bankName;
  double amount;
  String type;
  int payDay;
  double monthlyInstallment;
  bool isPaidThisMonth;

  Debt({
    required this.bankName,
    required this.amount,
    required this.type,
    required this.payDay,
    this.monthlyInstallment = 0.0,
    this.isPaidThisMonth = false,
  });

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
    bankName: json['bankName'],
    amount: (json['amount'] as num).toDouble(),
    type: json['type'],
    payDay: json['payDay'],
    monthlyInstallment: (json['monthlyInstallment'] as num).toDouble(),
    isPaidThisMonth: json['isPaidThisMonth'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'bankName': bankName,
    'amount': amount,
    'type': type,
    'payDay': payDay,
    'monthlyInstallment': monthlyInstallment,
    'isPaidThisMonth': isPaidThisMonth,
  };
}

// --- GLOBAL DEĞİŞKEN ---
List<Debt> myDebts = []; 

// --- MERKEZİ VERİ KASASI ---
class AppData {
  static String userName = "Kullanıcı"; 
  static String selectedMonth = "Şubat"; 
  static double totalTargets = 0.0;           
  static double thisMonthInstallments = 0.0; 
  static double assigned = 0.0;               
  static double spent = 0.0;                  
  static String currency = "₺";
  static List<String> notifications = [];

  static List<Map<String, dynamic>> categories = [
    {'name': 'Kira', 'icon': Icons.key_rounded, 'color': const Color(0xFF5C6BC0)},
    {'name': 'Yemek', 'icon': Icons.fastfood_rounded, 'color': const Color(0xFFFF9800)},
    {'name': 'Market', 'icon': Icons.local_mall_rounded, 'color': const Color(0xFF4CAF50)},
    {'name': 'Kahve', 'icon': Icons.coffee_rounded, 'color': const Color(0xFF8D6E63)},
    {'name': 'Yakıt', 'icon': Icons.local_gas_station_rounded, 'color': const Color(0xFF607D8B)},
    {'name': 'Fatura', 'icon': Icons.bolt_rounded, 'color': const Color(0xFFE91E63)},
    {'name': 'Maaş', 'icon': Icons.monetization_on_rounded, 'color': const Color(0xFF4CAF50)},
  ];
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  await initializeDateFormatting('tr_TR', null);
  
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint("Bildirim başlatma hatası: $e");
  }

  await Hive.initFlutter();
  await Hive.openBox('incomes');      
  await Hive.openBox('investments');  
  await Hive.openBox('spending');     
  await Hive.openBox('settings');     
  await Hive.openBox('transactions'); 

  final prefs = await SharedPreferences.getInstance();
  AppData.userName = prefs.getString('user_name') ?? "Kullanıcı";

  runApp(const VultraApp());
}

class VultraApp extends StatelessWidget {
  const VultraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vultra',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR')],
      locale: const Locale('tr', 'TR'),
      theme: ThemeData(
        useMaterial3: true, 
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        colorSchemeSeed: const Color(0xFF4361EE),
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const RootShell(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF4361EE))),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const RootShell();
        }
        return const LoginScreen();
      },
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  final GlobalKey<_HomeScreenState> _homeKey = GlobalKey();
  
  Widget _screenForIndex(int i) {
    switch (i) {
      case 0: return HomeScreen(key: _homeKey);
      case 1: return const DashboardScreen();
      case 2: return const TransactionsScreen();
      case 3: return const BankaScreen();
      case 4: return const AnalysisScreen(); 
      default: return HomeScreen(key: _homeKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      body: _screenForIndex(_index), 
      bottomNavigationBar: _buildBottomNavBar()
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.98), 
          borderRadius: BorderRadius.circular(35), 
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10))
          ]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.home_filled, "Ana Sayfa"),
            _navItem(1, Icons.account_tree_rounded, "Plan"),
            _navItem(2, Icons.local_atm_rounded, "Harcama"),
            _navItem(3, Icons.account_balance_rounded, "Hesaplar"),
            _navItem(4, Icons.insights_rounded, "Analiz"), 
          ],
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    bool isSelected = _index == i;
    return GestureDetector(
      onTap: () {
        setState(() => _index = i);
        if (i == 0) {
          _homeKey.currentState?._loadAndRefresh();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Icon(
              icon, 
              size: isSelected ? 28 : 24,
              color: isSelected ? const Color(0xFF4361EE) : Colors.black38
            ),
            const SizedBox(height: 4),
            Text(
              label, 
              style: TextStyle(
                fontSize: 10, 
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF4361EE) : Colors.black38
              )
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCalendarExpanded = false; 
  bool _isUpcomingExpanded = true;  

  @override
  void initState() {
    super.initState();
    _loadAndRefresh();
    
    // --- DÖVİZ TESTİ ---
    try {
      CurrencyService().getLiveRates().then((rates) {
        debugPrint("Kurlar Güncellendi");
      });
    } catch (e) {
      debugPrint("Hata: $e");
    }
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return "Günaydın";
    if (hour < 18) return "Tünaydın";
    return "İyi Akşamlar";
  }

  String _formatCurrency(double value) {
    return NumberFormat.decimalPattern("tr_TR").format(value);
  }

  List<Debt> _getUpcomingDebts() {
    int today = DateTime.now().day;
    return myDebts.where((d) => 
      d.payDay >= today && 
      d.payDay <= (today + 7) && 
      !d.isPaidThisMonth
    ).toList()..sort((a, b) => a.payDay.compareTo(b.payDay));
  }

  Future<void> _loadAndRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('saved_debts');
    
    if (savedData != null) {
      final List<dynamic> decoded = jsonDecode(savedData);
      setState(() {
        myDebts = decoded.map((d) => Debt.fromJson(d)).toList();
        _calculateTotals();
      });
    } else {
      _calculateTotals();
    }
  }

  void _calculateTotals() {
    double totalDebt = 0; 
    double monthInstallment = 0;
    double totalSpending = 0;
    double totalPaid = 0;

    for (var d in myDebts) { 
      totalDebt += d.amount; 
      double currentInstallment = (d.type == "Kredi") ? d.monthlyInstallment : d.amount;
      monthInstallment += currentInstallment; 
      if (d.isPaidThisMonth) {
        totalPaid += currentInstallment;
      }
    }

    try {
      if (Hive.isBoxOpen('spending')) {
        var box = Hive.box('spending');
        totalSpending = 0;
        for (var item in box.values) {
          totalSpending += (item['amount'] ?? 0);
        }
      }
    } catch (e) { debugPrint("Hive Hatası: $e"); }

    setState(() { 
      AppData.totalTargets = totalDebt; 
      AppData.thisMonthInstallments = monthInstallment;
      AppData.assigned = totalSpending; 
      AppData.spent = totalPaid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4361EE), Color(0xFF4CC9F0), Color(0xFFF2F2F7)],
          begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0.0, 0.25, 0.7]
        )
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_getGreeting()}, ${FirebaseAuth.instance.currentUser?.displayName ?? 'Kullanıcı'} 👋", 
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.normal)
              ),
              const Text(
                "Vultra", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline_rounded, color: Colors.white), 
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              }
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white), 
              onPressed: _loadAndRefresh
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildMotivationCard(), 
              const SizedBox(height: 12),
              _buildSummarySection(), 
              const SizedBox(height: 12),
              _buildUpcomingSection(), 
              const SizedBox(height: 12),
              _buildCollapsibleCalendar(),
              const SizedBox(height: 100)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMotivationCard() {
    double progress = AppData.thisMonthInstallments > 0 ? (AppData.spent / AppData.thisMonthInstallments) : 0;
    String message = "Finansal sağlığın yolunda! 🚀";
    if (progress > 0.8) message = "Bu ay ödemelerin çoğunu tamamladın! 🎉";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2))
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white, 
            child: Icon(Icons.auto_awesome, color: Color(0xFF4361EE), size: 18)
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1), 
              shape: BoxShape.circle
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  // --- MODERNLEŞTİRİLMİŞ ÖZET BÖLÜMÜ (ANALİZ SAYFASI STİLİ) ---
  Widget _buildSummarySection() {
    double progress = AppData.thisMonthInstallments > 0 ? (AppData.spent / AppData.thisMonthInstallments) : 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)]
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Şubat 2026 Özeti", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Icon(Icons.auto_graph_rounded, color: const Color(0xFF4361EE).withOpacity(0.7), size: 18),
              ],
            ),
            const SizedBox(height: 15),
            
            // --- BÜYÜTÜLMÜŞ ve İKONLU KARTLAR ---
            GridView.count(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.4, // Kartları büyüttük
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _infoBox("Toplam Borç", "${_formatCurrency(AppData.totalTargets)}₺", Icons.account_balance_wallet, const Color(0xFF4361EE)),
                _infoBox("Taksit", "${_formatCurrency(AppData.thisMonthInstallments)}₺", Icons.calendar_month, Colors.orange),
                _infoBox("Harcamalar", "${_formatCurrency(AppData.assigned)}₺", Icons.shopping_bag, Colors.redAccent),
                _infoBox("Ödenen", "${_formatCurrency(AppData.spent)}₺", Icons.check_circle, Colors.green),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionBtn("Harcama Ekle", Icons.add_shopping_cart_rounded, Colors.orange, () => _showQuickExpense()),
                _actionBtn("Borç Öde", Icons.check_circle_outline_rounded, Colors.green, () => _showSummaryDetail("Bu Ayki Taksit")),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Ödeme Tamamlama", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                    Text("%${(progress * 100).toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4361EE))),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      height: 6,
                      width: (MediaQuery.of(context).size.width - 64) * (progress > 1 ? 1 : progress),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF4361EE), Color(0xFF4CC9F0)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- YENİ MODERN KART TASARIMI ---
  Widget _infoBox(String title, String value, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _showSummaryDetail(title == "Taksit" ? "Bu Ayki Taksit" : title),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.grey.withOpacity(0.05))
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            FittedBox(
              child: Text(
                value, 
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.black87)
              )
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showQuickExpense() {
    final TextEditingController amountCtrl = TextEditingController();
    String selectedCat = AppData.categories[1]['name'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Hızlı Harcama Ekle", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: "Tutar (₺)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCat,
              items: AppData.categories.map((c) => DropdownMenuItem(value: c['name'] as String, child: Text(c['name'] as String))).toList(),
              onChanged: (v) => selectedCat = v!,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4361EE), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: () async {
                  if (amountCtrl.text.isNotEmpty) {
                    var box = Hive.box('spending');
                    await box.add({
                      'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                      'category': selectedCat,
                      'date': DateTime.now().toIso8601String(),
                    });
                    Navigator.pop(context);
                    _loadAndRefresh();
                  }
                },
                child: const Text("Kaydet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showSummaryDetail(String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        Widget content = const SizedBox();

        if (title == "Toplam Borç") {
          content = Column(
            children: myDebts.isEmpty 
              ? [const Padding(padding: EdgeInsets.all(20), child: Text("Kayıtlı borç bulunamadı."))]
              : myDebts.map((d) => ListTile(
                  leading: const Icon(Icons.account_balance_rounded, color: Colors.blueAccent),
                  title: Text(d.bankName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(d.type),
                  trailing: Text("${_formatCurrency(d.amount)}₺", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                )).toList(),
          );
        } 
        else if (title == "Bu Ayki Taksit") {
          content = Column(
            children: myDebts.isEmpty 
              ? [const Padding(padding: EdgeInsets.all(20), child: Text("Bu ay taksit bulunmuyor."))]
              : myDebts.map((d) {
                  return ListTile(
                    leading: Icon(Icons.calendar_today, color: d.isPaidThisMonth ? Colors.green : Colors.orange),
                    title: Text(d.bankName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(d.isPaidThisMonth ? "Ödendi" : "Ödeme Bekliyor"),
                    trailing: d.isPaidThisMonth 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : ElevatedButton(
                          onPressed: () async {
                            d.isPaidThisMonth = true;
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('saved_debts', jsonEncode(myDebts.map((e) => e.toJson()).toList()));
                            Navigator.pop(context);
                            _loadAndRefresh();
                          },
                          child: const Text("Öde"),
                        ),
                  );
                }).toList(),
          );
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                Text("$title Detayları", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                content,
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpcomingSection() {
    final upcoming = _getUpcomingDebts();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)]
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: const Text("Yaklaşan Ödemeler", style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(_isUpcomingExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
            onTap: () => setState(() => _isUpcomingExpanded = !_isUpcomingExpanded),
          ),
          if (_isUpcomingExpanded)
            upcoming.isEmpty 
            ? const Padding(padding: EdgeInsets.all(20), child: Text("Ödeme yok.", style: TextStyle(fontSize: 12, color: Colors.grey)))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: upcoming.length,
                itemBuilder: (context, index) {
                  final d = upcoming[index];
                  // --- KREDİ KARTI SIFIR GÖZÜKME HATASI DÜZELTİLDİ ---
                  double amountToShow = (d.type == "Kredi") ? d.monthlyInstallment : d.amount;
                  String label = (d.type == "Kredi") ? "Kredi Taksiti" : "Kredi Kartı Borcu";
                  
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.red.withOpacity(0.1),
                      child: Text("${d.payDay}", style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(d.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), // EKLEDİĞİMİZ ETİKET
                    trailing: Text("${_formatCurrency(amountToShow)}₺", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)]
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: const Text("Ödeme Takvimi", style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(_isCalendarExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
            onTap: () => setState(() => _isCalendarExpanded = !_isCalendarExpanded),
          ),
          if (_isCalendarExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, 
                  mainAxisSpacing: 8, 
                  crossAxisSpacing: 8
                ),
                itemCount: 31,
                itemBuilder: (context, index) {
                  int day = index + 1;
                  
                  // --- YEŞİL RENK DÜZELTMESİ BURADA ---
                  List<Debt> daysDebts = myDebts.where((d) => d.payDay == day).toList();
                  bool hasDebt = daysDebts.isNotEmpty;
                  bool isFullyPaid = hasDebt && daysDebts.every((d) => d.isPaidThisMonth);

                  Color boxColor = Colors.grey.withOpacity(0.05);
                  Color textColor = Colors.black38;

                  if (isFullyPaid) {
                    boxColor = Colors.green.withOpacity(0.2); // Ödendiyse Yeşil
                    textColor = Colors.green;
                  } else if (hasDebt) {
                    boxColor = Colors.red.withOpacity(0.1); // Ödenmediyse Kırmızı
                    textColor = Colors.red;
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text("$day", style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showDayDetails(int day, List<Debt> debts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Ayın $day. Günü Ödemeleri", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(height: 32),
            ...debts.map((d) => ListTile(
              title: Text(d.bankName, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text("${_formatCurrency(d.monthlyInstallment)}₺"),
            )).toList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}