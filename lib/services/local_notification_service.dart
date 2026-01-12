import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io' show Platform;

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
      
  // The Android channel details must be defined here for Android 8.0+
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // ID: Must match the ID in AndroidManifest.xml
    'High Importance Notifications', // Name shown to the user
    description: 'This channel is used for important notifications from the app.', 
    importance: Importance.max,
    showBadge: true,
  );

  static void initialize() {
    // 1. Android Initialization Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon'); 

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      // We skip iOS/Darwin settings as we are Android-only
    );

    _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // This callback is triggered when the user taps the notification
        // Add navigation/action logic here based on response.payload
      },
    );
    
    // Create the channel on Android 8.0 (Oreo) and above
    if (Platform.isAndroid) {
       // This line now works because AndroidFlutterLocalNotificationsPlugin is imported
       _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()!
          .createNotificationChannel(_channel);
    }
  }

  // Method to display the notification
  static void display(RemoteMessage message) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      final notification = message.notification;
      if (notification == null) return;

      // Use the channel ID we defined above
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        _channel.id, 
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        // The default icon set in AndroidManifest will be used unless overridden here.
      );

      NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics, // This line is correct now!
      );

      await _notificationsPlugin.show(
        id, 
        notification.title,
        notification.body,
        platformChannelSpecifics,
        payload: message.data['action'] ?? 'no_action', // Use custom data from FCM payload
      );
    } on Exception catch (e) {
      debugPrint("Error displaying local notification: $e");
    }
  }
}