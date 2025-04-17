package com.aliasgar.routino

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Start service to detect app kill
        val serviceIntent = Intent(this, AppKillService::class.java)
        startService(serviceIntent)
    }
}
