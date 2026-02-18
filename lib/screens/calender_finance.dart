import 'package:flutter/material.dart';
import '../main.dart'; // AppData ve myDebts'e ulaşmak için
import 'banka_screen.dart'; // Debt modeline ulaşmak için

class FinanceCalendarScreen extends StatefulWidget {
  const FinanceCalendarScreen({super.key});

  @override
  State<FinanceCalendarScreen> createState() => _FinanceCalendarScreenState();
}

class _FinanceCalendarScreenState extends State<FinanceCalendarScreen> {
  @override
  Widget build(BuildContext context) {
    // Toplam borç miktarını hesapla (Progress bar oranları için)
    double totalDebtCalc = 0;
    for (var d in myDebts) {
      totalDebtCalc += d.amount;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text("Borç Analizi", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCard(totalDebtCalc),
            const SizedBox(height: 24),
            const Text("Banka Dağılımı", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildDebtList(totalDebtCalc),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4361EE), Color(0xFF3F37C9)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Genel Toplam Borç", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text("${total.toStringAsFixed(0)}₺", 
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDebtList(double total) {
    if (myDebts.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.only(top: 40),
        child: Text("Henüz kayıtlı borç bulunmuyor."),
      ));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: myDebts.length,
      itemBuilder: (context, index) {
        final d = myDebts[index];
        // Payda 0 olmasın diye kontrol
        double safeTotal = total > 0 ? total : 1;
        double percentage = (d.amount / safeTotal);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(d.type, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  Text("${d.amount.toStringAsFixed(0)}₺", 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4361EE))),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF2F2F7),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4361EE)),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text("%${(percentage * 100).toStringAsFixed(1)}", 
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              )
            ],
          ),
        );
      },
    );
  }
}