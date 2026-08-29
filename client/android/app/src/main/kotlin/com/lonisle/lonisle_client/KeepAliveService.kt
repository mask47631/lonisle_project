package com.lonisle.lonisle_client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * 后台保活前台服务：常驻通知保持进程存活，使 Flutter 引擎与各服务器
 * 的 WebSocket 长连接在应用退到后台后持续收发消息（无 FCM 设备的
 * 离线接收方案）。仅在用户于设置中主动开启后由 Dart 侧启停。
 *
 * 已知限制：若系统仍强杀进程，START_STICKY 会重建服务（通知恢复），
 * 但 Flutter 引擎不会自动重启，消息同步需用户再次打开应用。
 */
class KeepAliveService : Service() {

    companion object {
        const val CHANNEL_ID = "lonisle_keepalive"
        const val NOTIFICATION_ID = 20260829

        fun start(context: Context) {
            val intent = Intent(context, KeepAliveService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, KeepAliveService::class.java))
        }
    }

    override fun onCreate() {
        super.onCreate()
        startForegroundWithNotification()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 被系统回收后自动重建（通知恢复；引擎限制见类注释）
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startForegroundWithNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "后台保活",
                NotificationManager.IMPORTANCE_MIN, // 常驻通知不发声不振动
            ).apply { description = "保持 LonIsle 在线以接收消息" }
            manager.createNotificationChannel(channel)
        }
        val notification: Notification =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
                    .setContentTitle("LonIsle 保持在线")
                    .setContentText("正在后台接收消息，点按打开应用")
                    .setSmallIcon(R.drawable.ic_notification)
                    .setOngoing(true)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
                    .setContentTitle("LonIsle 保持在线")
                    .setContentText("正在后台接收消息，点按打开应用")
                    .setSmallIcon(R.drawable.ic_notification)
                    .setOngoing(true)
                    .build()
            }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ 必须声明前台服务类型（special-use，见 Manifest property）
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }
}
