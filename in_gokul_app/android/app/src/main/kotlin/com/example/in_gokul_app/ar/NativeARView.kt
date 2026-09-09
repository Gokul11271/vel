package com.example.in_gokul_app.ar

import android.content.Context
import android.opengl.GLSurfaceView
import android.util.Log
import android.view.View
import io.flutter.plugin.platform.PlatformView

class NativeARView(
    context: Context,
    private val id: Int,
    creationParams: Map<String, Any>?,
    private val arCoreManager: ARCoreManager
) : PlatformView {

    companion object {
        private const val TAG = "NATIVE_AR_VIEW"
    }

    private val glSurfaceView: GLSurfaceView = GLSurfaceView(context).apply {
        preserveEGLContextOnPause = true
        setEGLContextClientVersion(2)
        setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        setRenderer(arCoreManager.renderer)
        renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        onResume()
    }

    init {
        Log.i(TAG, "NativeARView created with id=$id")
    }

    override fun getView(): View {
        return glSurfaceView
    }

    override fun dispose() {
        Log.i(TAG, "NativeARView disposed id=$id")
        glSurfaceView.onPause()
    }
}
