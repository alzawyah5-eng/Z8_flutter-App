package com.nakhba.z8_portal

import io.flutter.embedding.android.FlutterActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.os.Build
import android.content.Context
import android.content.pm.PackageManager
import android.Manifest
import android.os.Bundle
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val notificationChannel = "com.nakhba.z8_portal/notifications"
  private var notificationId = 0

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannel)
      .setMethodCallHandler { call, result ->
        if (call.method != "showNotification") {
          result.notImplemented()
          return@setMethodCallHandler
        }
        if (Build.VERSION.SDK_INT >= 33 &&
          checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
          result.error("permission-denied", "Notification permission is not granted", null)
          return@setMethodCallHandler
        }
        val title = call.argument<String>("title") ?: "Z8"
        val body = call.argument<String>("body") ?: "You have a new update."
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          Notification.Builder(this, "z8_alerts")
        } else {
          @Suppress("DEPRECATION")
          Notification.Builder(this)
        }
          .setSmallIcon(R.drawable.ic_stat_z8)
          .setContentTitle(title)
          .setContentText(body)
          .setAutoCancel(true)
          .build()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(++notificationId, notification)
        result.success(null)
      }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
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
