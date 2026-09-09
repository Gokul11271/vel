package com.example.in_gokul_app.ar

import android.app.Activity
import android.content.Context
import android.util.Log
import com.google.ar.core.ArCoreApk
import com.google.ar.core.CameraConfig
import com.google.ar.core.CameraConfigFilter
import com.google.ar.core.Config
import com.google.ar.core.Session

class ARSessionManager(private val context: Context) {
    companion object {
        private const val TAG = "INDOOR_AR_SESSION"
    }

    var arSession: Session? = null
        private set

    fun createSession(): Session? {
        return try {
            if (context is Activity) {
                var userRequestedInstall = true
                when (ArCoreApk.getInstance().requestInstall(context, userRequestedInstall)) {
                    ArCoreApk.InstallStatus.INSTALL_REQUESTED -> {
                        Log.i(TAG, "ARCore install requested")
                        return null
                    }
                    ArCoreApk.InstallStatus.INSTALLED -> {}
                }
            }
            val session = Session(context)

            // Select highest resolution rear camera config
            try {
                val filter = CameraConfigFilter(session).apply {
                    facingDirection = CameraConfig.FacingDirection.BACK
                }
                val configs = session.getSupportedCameraConfigs(filter)
                val bestConfig = configs.maxByOrNull { config ->
                    val texArea = config.textureSize.width * config.textureSize.height
                    val imgArea = config.imageSize.width * config.imageSize.height
                    texArea * 10 + imgArea
                }
                if (bestConfig != null) {
                    session.cameraConfig = bestConfig
                    Log.i(TAG, "CAMERA_CONFIG_SELECTED resolution=${bestConfig.textureSize.width}x${bestConfig.textureSize.height}")
                }
            } catch (e: Exception) {
                Log.w(TAG, "CAMERA_CONFIG_SELECTION_FAILED", e)
            }

            val config = Config(session).apply {
                focusMode = Config.FocusMode.AUTO
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                lightEstimationMode = Config.LightEstimationMode.AMBIENT_INTENSITY
            }
            session.configure(config)
            Log.i(TAG, "ARCore session created and configured with focusMode=AUTO")
            arSession = session
            session
        } catch (t: Throwable) {
            Log.e(TAG, "ARCore SESSION_CREATE_FAILED", t)
            arSession = null
            null
        }
    }

    fun resumeSession(): Boolean {
        return try {
            val session = arSession
            if (session != null) {
                val config = session.config
                config.focusMode = Config.FocusMode.AUTO
                session.configure(config)
                session.resume()
                Log.i(TAG, "ARCore session resumed")
            }
            true
        } catch (t: Throwable) {
            Log.e(TAG, "ARCore SESSION_RESUME_FAILED", t)
            false
        }
    }

    fun pauseSession() {
        try {
            arSession?.pause()
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to pause ARCore session", t)
        }
    }

    fun destroySession() {
        try {
            arSession?.close()
            arSession = null
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to destroy ARCore session", t)
            arSession = null
        }
    }
}
