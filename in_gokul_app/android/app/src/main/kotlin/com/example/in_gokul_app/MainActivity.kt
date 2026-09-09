package com.example.in_gokul_app

import androidx.annotation.NonNull
import com.example.in_gokul_app.ar.ARCoreManager
import com.example.in_gokul_app.ar.ARViewFactory
import com.example.in_gokul_app.bridge.ARMessageHandler
import com.example.in_gokul_app.bridge.ARMethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var arCoreManager: ARCoreManager
    private lateinit var arMethodChannel: ARMethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        arCoreManager = ARCoreManager(this)
        arCoreManager.renderer.displayRotationSupplier = {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                display?.rotation ?: 0
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay.rotation
            }
        }

        // Register Platform View for AR Camera Feed & 3D OpenGL ES Surface
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("com.example.indoornavigation/ar_view", ARViewFactory(arCoreManager))

        // Register MethodChannel for ARCore control
        arMethodChannel = ARMethodChannel(this, arCoreManager)
        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.indoornavigation/ar_channel"
        )
        methodChannel.setMethodCallHandler(arMethodChannel)

        // Register EventChannel for live 6DoF pose stream
        val eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.indoornavigation/ar_events"
        )
        eventChannel.setStreamHandler(ARMessageHandler(arCoreManager))
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (::arMethodChannel.isInitialized) {
            arMethodChannel.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun onResume() {
        super.onResume()
        if (::arCoreManager.isInitialized && arCoreManager.isSessionActive) {
            arCoreManager.resumeARCoreSession()
        }
    }

    override fun onPause() {
        super.onPause()
        if (::arCoreManager.isInitialized && arCoreManager.isSessionActive) {
            arCoreManager.pauseARCoreSession()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::arCoreManager.isInitialized) {
            arCoreManager.stopARCoreSession()
        }
    }
}
