package com.smartkhata.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Explicitly clear FLAG_SECURE to allow taking screenshots and screen recordings
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
