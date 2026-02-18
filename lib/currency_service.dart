import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CurrencyService {
  // Dolar ve Euro'nun kesin geldiği o sihirli adres:
  static const String _dovizUrl = "https://api.bigpara.hurriyet.com.tr/doviz/headerlist/anasayfa";

  Future<Map<String, double>> getLiveRates() async {
    double dolar = 0.0;
    double euro = 0.0;
    double gramAltin = 0.0;

    try {
      final response = await http.get(Uri.parse(_dovizUrl));

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        List list = (json is List) ? json : (json['data'] ?? []);
        
        for (var item in list) {
          String s = (item['SEMBOL'] ?? "").toString().toUpperCase();
          double p = _parse(item['SATIS']);

          // 1. DOLAR & EURO (Zaten geliyordu)
          if (s == "USDTRY") dolar = p;
          if (s == "EURTRY") euro = p;

          // 2. ALTIN (Bu listede gizlenen ne varsa yakalıyoruz)
          // BigPara döviz listesinde altın "GRAM ALTIN" veya "GLDGR" adıyla durur
          if (s == "GLDGR" || s.contains("ALTIN") || s.contains("GOLD")) {
            if (p > 100) gramAltin = p; // Mantıksız küçük değerleri (değişim oranı vb) elemek için
          }
        }
      }

      // --- YEDEK ALTIN KAPISI ---
      // Eğer ana listede Altın bulamazsa, sadece Altın için özel kapıya hızlıca vurup çıkıyoruz
      if (gramAltin == 0.0) {
        final resAltin = await http.get(Uri.parse("https://api.bigpara.hurriyet.com.tr/altin/headerlist/anasayfa"));
        if (resAltin.statusCode == 200) {
          var gJson = jsonDecode(resAltin.body);
          List gList = (gJson is List) ? gJson : (gJson['data'] ?? []);
          for (var item in gList) {
            String s = (item['SEMBOL'] ?? "").toString().toUpperCase();
            if (s.contains("GRAM") || s == "GLDGR") {
              gramAltin = _parse(item['SATIS']);
            }
          }
        }
      }

      return {
        'USD': dolar,
        'EUR': euro,
        'GRAM_ALTIN': gramAltin,
        'GUMUS': 0.0, // Gümüş şimdilik dinleniyor
      };
    } catch (e) {
      debugPrint("⚠️ Hata: $e");
      return {'USD': 0.0, 'EUR': 0.0, 'GRAM_ALTIN': 0.0, 'GUMUS': 0.0};
    }
  }

  double _parse(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }
}