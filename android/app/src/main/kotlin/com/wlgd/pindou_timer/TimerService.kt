package com.wlgd.pindou_timer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * 常驻通知栏：把正在计时的桌位挂在通知栏，App 退到后台也能看还剩多久。
 *
 * Dart 只推一次「每桌的目标时间/起始时间」，剩下每秒刷新由这里自己算，
 * 所以拿到的是一份不依赖 Flutter 引擎的实时显示。
 */
class TimerService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var payload: JSONObject? = null

    private val tick = object : Runnable {
        override fun run() {
            if (!hasItems()) {
                shutdown()
                return
            }
            notifyNow()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getStringExtra(EXTRA_PAYLOAD)?.let { raw ->
            payload = try {
                JSONObject(raw)
            } catch (_: Exception) {
                null
            }
        }
        if (!hasItems()) {
            shutdown()
            return START_NOT_STICKY
        }
        startForegroundCompat()
        handler.removeCallbacksAndMessages(null)
        handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun hasItems(): Boolean = (payload?.optJSONArray("items")?.length() ?: 0) > 0

    private fun startForegroundCompat() {
        val type = if (Build.VERSION.SDK_INT >= 34) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        ServiceCompat.startForeground(this, NOTIFY_ID, buildNotification(), type)
    }

    private fun notifyNow() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFY_ID, buildNotification())
    }

    private fun shutdown() {
        handler.removeCallbacksAndMessages(null)
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildNotification(): Notification {
        val items = payload?.optJSONArray("items") ?: JSONArray()
        val shop = payload?.optString("shop").orEmpty().ifEmpty { "我勒个豆计时器" }
        val now = System.currentTimeMillis()
        val lines = ArrayList<String>()

        for (i in 0 until items.length()) {
            val o = items.optJSONObject(i) ?: continue
            val name = o.optString("name")
            val text = when (o.optString("kind")) {
                "down" -> {
                    val left = o.optLong("target") - now
                    if (left <= 0) "已到点" else "剩 " + hms(left)
                }
                "up" -> "已用 " + hms(now - o.optLong("base"))
                "paused" -> "已暂停 " + o.optString("frozen")
                else -> "已到点"
            }
            lines.add("$name    $text")
        }

        ensureChannel()
        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(
            this, 0, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_timer)
            .setContentTitle("$shop · ${lines.size} 台在计中")
            .setContentText(lines.joinToString("　"))
            .setStyle(NotificationCompat.BigTextStyle().bigText(lines.joinToString("\n")))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setSilent(true)
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val ch = NotificationChannel(CHANNEL_ID, "桌位计时", NotificationManager.IMPORTANCE_LOW)
        ch.description = "显示各个桌位还剩多少时间"
        ch.setShowBadge(false)
        ch.enableVibration(false)
        ch.setSound(null, null)
        nm.createNotificationChannel(ch)
    }

    private fun hms(ms: Long): String {
        var t = ms / 1000
        if (t < 0) t = 0
        return String.format("%02d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
    }

    companion object {
        private const val CHANNEL_ID = "wlgd_timer"
        private const val NOTIFY_ID = 1001
        private const val EXTRA_PAYLOAD = "payload"

        fun push(ctx: Context, json: String) {
            val i = Intent(ctx, TimerService::class.java).putExtra(EXTRA_PAYLOAD, json)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(i)
            } else {
                ctx.startService(i)
            }
        }
    }
}
