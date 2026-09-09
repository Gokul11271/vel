package com.example.in_gokul_app.ar

import android.util.Log
import com.google.ar.core.Anchor
import com.google.ar.core.Pose
import com.google.ar.core.Session
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.sqrt

class ARAnchorManager {
    companion object {
        private const val TAG = "INDOOR_AR"
    }

    private val activeAnchors = CopyOnWriteArrayList<Anchor>()
    private val anchorReferencePoses = ConcurrentHashMap<Anchor, Pose>()

    fun createAnchorAtPose(session: Session, pose: Pose): Anchor? {
        return try {
            val anchor = session.createAnchor(pose)
            activeAnchors.add(anchor)
            anchorReferencePoses[anchor] = pose
            Log.i(TAG, "INDOOR_AR ANCHOR_CREATED id=${anchor.hashCode()} pos=(${pose.tx()}, ${pose.ty()}, ${pose.tz()}) total_count=${activeAnchors.size}")
            anchor
        } catch (e: Exception) {
            Log.e(TAG, "INDOOR_AR ANCHOR_FAILED pos=(${pose.tx()}, ${pose.ty()}, ${pose.tz()})", e)
            null
        }
    }

    fun getObservedAnchorDisplacementMeters(anchor: Anchor): Float {
        val ref = anchorReferencePoses[anchor] ?: return 0f
        val curr = anchor.pose
        val dx = curr.tx() - ref.tx()
        val dy = curr.ty() - ref.ty()
        val dz = curr.tz() - ref.tz()
        val dist = sqrt(dx * dx + dy * dy + dz * dz)
        if (dist > 0.05f) {
            Log.d(TAG, "INDOOR_AR ANCHOR_DISPLACEMENT id=${anchor.hashCode()} displacement_m=${String.format("%.3f", dist)}")
        }
        return dist
    }

    fun clearAnchors() {
        Log.i(TAG, "INDOOR_AR ANCHORS_CLEARED count=${activeAnchors.size}")
        for (anchor in activeAnchors) {
            anchor.detach()
        }
        activeAnchors.clear()
        anchorReferencePoses.clear()
    }

    fun getActiveAnchors(): List<Anchor> = ArrayList(activeAnchors)
    fun hasActiveAnchor(): Boolean = activeAnchors.isNotEmpty()
}
