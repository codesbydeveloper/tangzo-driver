package com.tangzo.driver

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val url = call.argument<String>("url")
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    OrderRingtoneService.start(this, url, title, body)
                    result.success(true)
                }
                "stop" -> {
                    OrderRingtoneService.stop(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val CHANNEL = "tangzo/order_ringtone"
    }
}
