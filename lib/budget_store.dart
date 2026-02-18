import 'package:flutter/foundation.dart';
// DebtStore'u buraya import etmelisin
// import 'package:vultra_clean/store/debt_store.dart'; 

enum TxType { income, expense }

class TxDraft {
  final TxType type;
  final String category;
  final String? bankName; // Borç ödemesi ise banka adını tutmak için
  final double amount;

  const TxDraft({
    required this.type,
    required this.category,
    required this.amount,
    this.bankName,
  });
}

class BudgetState {
  final double atanacak; // Toplam Gelir
  final double butcelenen;
  final double harcanan; // Yapılan harcamalar + Ödenen taksitler
  final Map<String, double> availableByCategory;

  const BudgetState({
    required this.atanacak,
    required this.butcelenen,
    required this.harcanan,
    required this.availableByCategory,
  });

  // ANALİZ: Harcanabilir net tutar hesaplaması
  // Toplam Gelir - Toplam Harcama
  double get netHarcayabilecegin => atanacak - harcanan;

  double get toplamKalan =>
      availableByCategory.values.fold<double>(0, (a, b) => a + b);

  BudgetState copyWith({
    double? atanacak,
    double? butcelenen,
    double? harcanan,
    Map<String, double>? availableByCategory,
  }) {
    return BudgetState(
      atanacak: atanacak ?? this.atanacak,
      butcelenen: butcelenen ?? this.butcelenen,
      harcanan: harcanan ?? this.harcanan,
      availableByCategory: availableByCategory ?? this.availableByCategory,
    );
  }
}

class BudgetStore extends ValueNotifier<BudgetState> {
  BudgetStore._()
      : super(
          const BudgetState(
            atanacak: 25000, // Bu değer ileride Gelir Ekle'den gelecek
            butcelenen: 0,
            harcanan: 0,
            availableByCategory: {
              "Kira": 0,
              "Faturalar": 0,
              "Market": 0,
              "Tatil": 0,
              "Acil Durum": 0,
              "Banka Ödemeleri": 0, // Yeni kategori
            },
          ),
        );

  static final BudgetStore instance = BudgetStore._();

  // Borç Ödeme Entegrasyonu
  // Banka sayfasında "Öde"ye basıldığında bu fonksiyon çağrılacak
  void payDebt(String bankName, double amount) {
    applyTransaction(TxDraft(
      type: TxType.expense,
      category: "Banka Ödemeleri",
      bankName: bankName,
      amount: amount,
    ));
  }

  void applyTransaction(TxDraft tx) {
    final amt = tx.amount;
    if (amt <= 0) return;

    if (tx.type == TxType.income) {
      value = value.copyWith(atanacak: value.atanacak + amt);
      return;
    }

    // Gider İşlemi
    final newMap = Map<String, double>.from(value.availableByCategory);
    
    // Eğer kategori listede yoksa (dinamik kategoriler için) ekle
    if (!newMap.containsKey(tx.category)) {
      newMap[tx.category] = 0;
    }
    
    newMap[tx.category] = (newMap[tx.category] ?? 0) - amt;

    value = value.copyWith(
      harcanan: value.harcanan + amt, // Toplam harcanan artar
      availableByCategory: newMap,
    );
  }

  // Maaş/Gelir Güncelleme (Plan ekranındaki + butonu için)
  void updateIncome(double newIncome) {
    value = value.copyWith(atanacak: newIncome);
  }
}