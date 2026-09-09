package com.example.in_gokul_app.ar

class ARCoordinateSystem {
    var originX: Float = 0.0f
    var originY: Float = 0.0f
    var originZ: Float = 0.0f

    fun resetOrigin(x: Float, y: Float, z: Float) {
        originX = x
        originY = y
        originZ = z
    }

    fun toFloorCoords(arX: Float, arY: Float, arZ: Float): FloatArray {
        return floatArrayOf(arX - originX, arY - originY, arZ - originZ)
    }
}
