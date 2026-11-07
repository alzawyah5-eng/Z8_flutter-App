package com.nakhba.z8_portal

import io.flutter.embedding.android.FlutterActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.content.Context
import android.content.pm.PackageManager
import android.Manifest
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val notificationChannel = "com.nakhba.z8_portal/notifications"
  private val notificationLinkExtra = "z8_notification_link"
  private var notificationId = 0
  private var pendingNotificationLink: String? = null
  private var notificationMethodChannel: MethodChannel? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannel)
    notificationMethodChannel = channel
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "takePendingNotificationLink" -> {
          result.success(pendingNotificationLink)
          pendingNotificationLink = null
        }
        "showNotification" -> showSystemNotification(call, result)
        else -> result.notImplemented()
      }
    }
    pendingNotificationLink = intent?.getStringExtra(notificationLinkExtra)
    setIntent(Intent(this, MainActivity::class.java))
  }

  private fun showSystemNotification(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
    if (Build.VERSION.SDK_INT >= 33 &&
      checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
      result.error("permission-denied", "Notification permission is not granted", null)
      return
    }
    val id = (++notificationId).coerceAtLeast(1)
    val title = call.argument<String>("title") ?: "Z8"
    val body = call.argument<String>("body") ?: "You have a new update."
    val link = call.argument<String>("link") ?: ""
    val tapIntent = Intent(this, MainActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
      putExtra(notificationLinkExtra, link)
    }
    val tapAction = PendingIntent.getActivity(
      this,
      id,
      tapIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Notification.Builder(this, "z8_alerts")
    } else {
      @Suppress("DEPRECATION")
      Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
    }
    val notification = builder
      .setSmallIcon(R.drawable.ic_stat_z8)
      .setContentTitle(title)
      .setContentText(body)
      .setContentIntent(tapAction)
      .setAutoCancel(true)
      .setDefaults(Notification.DEFAULT_ALL)
      .build()
    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    manager.notify(id, notification)
    result.success(null)
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    val link = intent.getStringExtra(notificationLinkExtra) ?: return
    pendingNotificationLink = link
    notificationMethodChannel?.invokeMethod("notificationTapped", link)
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
