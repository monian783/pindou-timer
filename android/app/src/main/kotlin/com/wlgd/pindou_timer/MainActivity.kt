package com.wlgd.pindou_timer

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Dart 那边通过 wlgd/timer_notify 这个通道把「哪些桌位还在计时」推过来，
 * 剩下的每秒刷新交给 TimerService 自己做，省得每秒都过一次通道。
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val payload = call.argument<String>("payload") ?: "{}"
                        TimerService.push(this, payload)
                        result.success(true)
                    }
                    "stop" -> {
                        stopService(Intent(this, TimerService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        askNotifyPermission()
    }

    /** 安卓13以上通知要用户点同意，第一次打开App时问一下 */
    private fun askNotifyPermission() {
        if (Build.VERSION.SDK_INT < 33) return
        val ok = ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (ok) return
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQ_NOTIFY
        )
    }

    companion object {
        private const val CHANNEL = "wlgd/timer_notify"
        private const val REQ_NOTIFY = 1001
    }
}
