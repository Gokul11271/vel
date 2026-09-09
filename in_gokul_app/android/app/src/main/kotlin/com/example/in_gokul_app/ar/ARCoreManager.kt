package com.example.in_gokul_app.ar

import android.content.Context
import android.util.Log
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Pose
import com.google.ar.core.TrackingState

class ARCoreManager(private val context: Context) {
    companion object {
        private const val TAG = "INDOOR_AR_MANAGER"
    }

    val sessionManager = ARSessionManager(context)
    val poseManager = ARPoseManager()
    val anchorManager = ARAnchorManager()
    val coordinateSystem = ARCoordinateSystem()
    val renderer = ARRenderer()

    var isARSupported: Boolean = false
        private set

    var isSessionActive: Boolean = false
        private set

    @Volatile
    var latestPoseData: ARPoseData? = null
        private set

    fun checkARAvailability(): Boolean {
        return try {
            val availability = ArCoreApk.getInstance().checkAvailability(context)
            isARSupported = availability.isSupported
            Log.i(TAG, "checkARAvailability supported=$isARSupported")
            isARSupported
        } catch (t: Throwable) {
            Log.e(TAG, "checkARAvailability failed", t)
            isARSupported = false
            false
        }
    }

    fun startARCoreSession(): Boolean {
        return try {
            if (sessionManager.arSession == null) {
                val session = sessionManager.createSession() ?: return false
                renderer.setSession(session)
            }
            val resumed = sessionManager.resumeSession()
            if (!resumed) return false

            renderer.onFrameUpdateListener = { frame, session ->
                val camera = frame.camera
                latestPoseData = poseManager.extractPose(
                    camera.pose,
                    camera.trackingState,
                    anchorManager.hasActiveAnchor()
                )
                renderer.activeAnchors = anchorManager.getActiveAnchors()
            }

            isSessionActive = true
            Log.i(TAG, "startARCoreSession succeeded")
            true
        } catch (t: Throwable) {
            Log.e(TAG, "startARCoreSession failed", t)
            isSessionActive = false
            false
        }
    }

    fun resumeARCoreSession() {
        if (isSessionActive) {
            sessionManager.resumeSession()
        }
    }

    fun pauseARCoreSession() {
        sessionManager.pauseSession()
    }

    fun stopARCoreSession() {
        isSessionActive = false
        anchorManager.clearAnchors()
        sessionManager.destroySession()
        latestPoseData = null
    }

    fun placeTestMarker(): Boolean {
        val session = sessionManager.arSession ?: return false
        return try {
            val lastPose = latestPoseData
            val pose = if (lastPose != null) {
                Pose.makeTranslation(lastPose.positionX, lastPose.positionY - 0.1f, lastPose.positionZ - 0.5f)
            } else {
                Pose.makeTranslation(0f, -0.1f, -1.0f)
            }
            val anchor = anchorManager.createAnchorAtPose(session, pose)
            anchor != null
        } catch (t: Throwable) {
            Log.e(TAG, "placeTestMarker failed safely", t)
            false
        }
    }

    fun addNodeAnchor(x: Float, y: Float, z: Float): Boolean {
        val session = sessionManager.arSession ?: return false
        return try {
            // Avoid duplicate anchor at exact same spot
            val existing = anchorManager.getActiveAnchors().find { a ->
                val p = a.pose
                val dx = p.tx() - x
                val dy = p.ty() - y
                val dz = p.tz() - z
                (dx * dx + dy * dy + dz * dz) < 0.0025f
            }
            if (existing != null) {
                renderer.activeAnchors = anchorManager.getActiveAnchors()
                return true
            }

            val pose = Pose.makeTranslation(x, y, z)
            val anchor = anchorManager.createAnchorAtPose(session, pose)
            if (anchor != null) {
                renderer.activeAnchors = anchorManager.getActiveAnchors()
                Log.i(TAG, "addNodeAnchor placed at ($x, $y, $z)")
                true
            } else {
                false
            }
        } catch (t: Throwable) {
            Log.e(TAG, "addNodeAnchor exception", t)
            false
        }
    }

    fun resetSession() {
        anchorManager.clearAnchors()
    }

    fun getCurrentPose(): ARPoseData? {
        return latestPoseData ?: ARPoseData(
            0f, 0f, 0f, 0f, 0f, 0f, 1f,
            TrackingState.STOPPED.name,
            System.currentTimeMillis(),
            anchorManager.hasActiveAnchor()
        )
    }

    fun getTrackingState(): String {
        return latestPoseData?.trackingState ?: TrackingState.STOPPED.name
    }

    fun setNavigationRoute(points: List<FloatArray>, destination: FloatArray?) {
        renderer.setNavigationRoute(points, destination)
    }

    fun clearNavigationRoute() {
        renderer.clearNavigationRoute()
    }

    fun getCameraDiagnostics(): Map<String, Any> {
        val session = sessionManager.arSession
        val config = try { session?.cameraConfig } catch (e: Exception) { null }
        val focusMode = try { session?.config?.focusMode?.name } catch (e: Exception) { "AUTO" }

        return mapOf(
            "cameraConfigResolution" to "${config?.textureSize?.width ?: 0}x${config?.textureSize?.height ?: 0}",
            "cameraConfigFps" to "${config?.fpsRange?.lower ?: 30}-${config?.fpsRange?.upper ?: 30}",
            "focusMode" to (focusMode ?: "AUTO"),
            "trackingState" to getTrackingState(),
            "anchorCount" to anchorManager.getActiveAnchors().size
        )
    }
}
