import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- ENUM VE SABİTLER ---
enum DebtType { kredi, krediKarti, ekHesap }

// --- MODEL SINIFI (Main.dart ile uyumlu hale getirildi) ---
class Debt {
  final String id;
  final String bankName;
  final String type; // String olarak tutmak Hive için daha güvenlidir
  final double amount; // Toplam borç veya kalan ana para
  
  // Kredi Detayları
  final double monthlyInstallment;
  final int totalMonths;
  final int paidMonths;
  final int payDay; // Ödeme günü (Ayın kaçı?)
  
  // Durum
  bool isPaidThisMonth;

  Debt({
    required this.id,
    required this.bankName,
    required this.type,
    required this.amount,
    this.monthlyInstallment = 0.0,
    this.totalMonths = 1,
    this.paidMonths = 0,
    this.payDay = 1,
    this.isPaidThisMonth = false,
  });

  // --- ABONELİK SİSTEMİ İÇİN HAZIRLIK ---
  // İleride "remainingMonths" gösterirken işine yarayacak
  int get remainingMonths => totalMonths - paidMonths;

  // --- HIVE & JSON DÖNÜŞÜMLERİ (Veri Kaybını Önler) ---
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bankName': bankName,
      'type': type,
      'amount': amount,
      'monthlyInstallment': monthlyInstallment,
      'totalMonths': totalMonths,
      'paidMonths': paidMonths,
      'payDay': payDay,
      'isPaidThisMonth': isPaidThisMonth,
    };
  }

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      bankName: json['bankName'] ?? 'Bilinmeyen Banka',
      type: json['type'] ?? 'Kredi',
      amount: (json['amount'] ?? 0.0).toDouble(),
      monthlyInstallment: (json['monthlyInstallment'] ?? 0.0).toDouble(),
      totalMonths: json['totalMonths'] ?? 1,
      paidMonths: json['paidMonths'] ?? 0,
      payDay: json['payDay'] ?? 1,
      isPaidThisMonth: json['isPaidThisMonth'] ?? false,
    );
  }
}

// --- BORÇ YÖNETİM SERVİSİ (Store yerine Service) ---
class DebtService {
  static const String _storageKey = 'saved_debts';

  // --- 1. BORÇLARI GETİR ---
  static Future<List<Debt>> getDebts() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_storageKey);
    if (data != null) {
      List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => Debt.fromJson(e)).toList();
    }
    return [];
  }

  // --- 2. BORÇ EKLE (Premium Kontrolü Buraya Eklendi) ---
  static Future<void> addDebt(Debt newDebt, {bool isPremium = false}) async {
    List<Debt> currentDebts = await getDebts();

    // --- ABONELİK (PREMIUM) MANTIĞI BURADA ---
    // Eğer kullanıcı Free ise ve 3'ten fazla borcu varsa ekletme
    if (!isPremium && currentDebts.length >= 3) {
      throw Exception("Free versiyonda en fazla 3 borç eklenebilir. Premium'a geçin!");
    }

    currentDebts.add(newDebt);
    await _saveToDisk(currentDebts);
  }

  // --- 3. BORÇ SİL ---
  static Future<void> deleteDebt(String id) async {
    List<Debt> currentDebts = await getDebts();
    currentDebts.removeWhere((d) => d.id == id);
    await _saveToDisk(currentDebts);
  }

  // --- 4. ÖDEME DURUMUNU GÜNCELLE (Ödendi/Ödenmedi) ---
  static Future<void> togglePaidStatus(String id) async {
    List<Debt> currentDebts = await getDebts();
    final index = currentDebts.indexWhere((d) => d.id == id);
    if (index != -1) {
      // Durumu tersine çevir
      currentDebts[index].isPaidThisMonth = !currentDebts[index].isPaidThisMonth;
      
      // Eğer "Ödendi" işaretlendiyse ve bu bir KREDİ ise, ödenen ay sayısını artırabiliriz
      // (Opsiyonel: Kullanıcı deneyimine göre bu mantık dashboard'da da kurulabilir)
      /* if (currentDebts[index].isPaidThisMonth && currentDebts[index].type == 'Kredi') {
         // currentDebts[index].paidMonths++; 
      }
      */
      
      await _saveToDisk(currentDebts);
    }
  }

  // --- 5. DİSKE KAYDET (Gizli Fonksiyon) ---
  static Future<void> _saveToDisk(List<Debt> list) async {
    final prefs = await SharedPreferences.getInstance();
    String encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  // --- KREDİ HESAPLAMA MOTORU (Yardımcı Fonksiyon) ---
  static double calculateMonthlyPayment({
    required double principal,
    required double annualRate,
    required int months,
  }) {
    if (months <= 0 || annualRate <= 0) return 0.0;
    
    // Faiz Oranı (Yıllık % -> Aylık Ondalık)
    // Örn: %3.5 aylık faiz için -> (3.5 * 12) / 100 / 12 ... 
    // Basit banka formülü: r = (YıllıkFaiz / 100) / 12
    double r = (annualRate / 100) / 12;
    
    // Formül: P * [r(1+r)^n] / [(1+r)^n – 1]
    double powVal = pow(1 + r, months).toDouble();
    if (powVal == 1) return principal / months; // Faizsiz durum
    
    return principal * (r * powVal) / (powVal - 1);
  }
}