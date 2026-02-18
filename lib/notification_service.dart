import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    
    // Android ayarları
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS ayarları (Apple Standartlarına Uygun)
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: false, // Özel izin gerektirir, App Store'da sorun çıkmaması için false
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Kullanıcı bildirime tıkladığında yapılacak işlem buraya gelir
        debugPrint("Bildirime tıklandı: ${details.payload}");
      },
    );
  }

  // iOS için manuel izin isteme (Eğer otomatik istemezse)
  static Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<void> scheduleDebtNotification({
    required int id,
    required String bankName,
    required double amount,
    required int payDay,
  }) async {
    try {
      final scheduledDate = _nextInstanceOfDay(payDay);
      
      await _notificationsPlugin.zonedSchedule(
        id,
        'Vultra: Ödeme Hatırlatıcı 🔔', // Marka ismini başlığa ekledik
        '$bankName için ${amount.toStringAsFixed(0)}₺ tutarındaki ödemeniz bugün.',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'vultra_debt_channel', // Kanal ID'si güncellendi
            'Borç Hatırlatıcılar',
            channelDescription: 'Ödeme tarihlerini hatırlatır.',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime, // Her ay aynı gün tekrarlatır
      );
      debugPrint("Bildirim Planlandı: $bankName - Tarih: $scheduledDate");
    } catch (e) {
      debugPrint("Bildirim planlama hatası: $e");
    }
  }

  static tz.TZDateTime _nextInstanceOfDay(int day) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    
    // Geçerli bir gün kontrolü (Şubat 29-30-31 durumları için)
    int targetDay = day;
    int lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    if (targetDay > lastDayOfMonth) targetDay = lastDayOfMonth;
    
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, targetDay, 10, 0); // Saat 10:00 idealdir
    
    if (scheduledDate.isBefore(now)) {
      // Eğer tarih geçtiyse bir sonraki aya planla
      int nextMonth = now.month + 1;
      int nextYear = now.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      scheduledDate = tz.TZDateTime(tz.local, nextYear, nextMonth, targetDay, 10, 0);
    }
    return scheduledDate;
  }

  // Tüm bildirimleri iptal etme (Abonelik biterse veya kullanıcı isterse)
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}