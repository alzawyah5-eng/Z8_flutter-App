package com.nakhba.z8_portal

import io.flutter.embedding.android.FlutterActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.content.Context

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: android.os.Bundle?) {
    super.onCreate(savedInstanceState)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        "z8_alerts",
        "Z8 alerts",
        NotificationManager.IMPORTANCE_HIGH,
      ).apply {
        description = "Important account and service updates from Z8."
      }
      val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      manager.createNotificationChannel(channel)
    }
  }
}
