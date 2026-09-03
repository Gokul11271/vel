# 🧭 Indoor AR Navigation System

A comprehensive 3D Augmented Reality (AR) Indoor Navigation System built with Flutter, Dijkstra Shortest Path routing, Sensor Fusion (Compass + Step Detection PDR), and a Three.js 3D Floor Plan Node Creator.

---

## 📦 APK File Locations

The Android APK files are located at:

### 1. **Release APK (Recommended for Installation)**:
```
D:\vel\in_gokul_app\build\app\outputs\flutter-apk\app-release.apk
```
*Direct link:* [app-release.apk](file:///d:/vel/in_gokul_app/build/app/outputs/flutter-apk/app-release.apk) (Size: ~47.2 MB)

*(Also available under:* `D:\vel\in_gokul_app\build\app\outputs\apk\release\app-release.apk`*)*

### 2. **Debug APK**:
```
D:\vel\in_gokul_app\build\app\outputs\flutter-apk\app-debug.apk
```

---

## 📲 How to Install the APK on Your Phone

### Method 1: Automatic 1-Click Install via USB (ADB)
1. Enable **Developer Options** and **USB Debugging** on your Android phone.
2. Connect your phone to your PC via USB cable.
3. Double-click the file:
   ```
   D:\vel\install_apk.bat
   ```
   *Direct link:* [install_apk.bat](file:///d:/vel/install_apk.bat)

---

### Method 2: Direct File Transfer (WhatsApp / Google Drive / USB Transfer)
1. Copy the APK file [`app-release.apk`](file:///d:/vel/in_gokul_app/build/app/outputs/flutter-apk/app-release.apk) to your phone via USB cable, Google Drive, or messaging app.
2. Open the file on your Android device.
3. Allow **"Install from unknown sources"** when prompted.
4. Tap **Install** and launch the app!

---

## 🚀 How to Run the Project (Development & Testing)

### 1. **Run in Web Browser (Instant Simulation & Testing)**
- **1-Click**: Double-click [`run_web.bat`](file:///d:/vel/run_web.bat)
- **Terminal**:
  ```powershell
  cd D:\vel\in_gokul_app
  flutter run -d chrome --web-port=8080
  ```
- **URL**: Open [http://localhost:8080](http://localhost:8080) in your browser.

---

### 2. **Run on Connected Mobile Device via Flutter**
- **1-Click**: Double-click [`run_mobile.bat`](file:///d:/vel/run_mobile.bat)
- **Terminal**:
  ```powershell
  cd D:\vel\in_gokul_app
  flutter run
  ```

---

### 3. **Rebuild the APK from Source**
- **1-Click**: Double-click [`build_apk.bat`](file:///d:/vel/build_apk.bat)
- **Terminal**:
  ```powershell
  cd D:\vel\in_gokul_app
  flutter build apk --release
  ```

---

### 4. **Run the 3D Floor Plan Node Creator Tool (Three.js)**
- **1-Click**: Double-click [`run_3d_editor.bat`](file:///d:/vel/run_3d_editor.bat)
- **Terminal**:
  ```powershell
  cd D:\vel
  python -m http.server 3000
  ```
- **URL**: Open [http://localhost:3000](http://localhost:3000) in your browser.
- **Usage**: Click anywhere on the 3D building model to place navigation nodes and export `nodes.json`.

---

## 🏛️ Project Architecture & Key Files

| Component | File Path | Description |
| :--- | :--- | :--- |
| **Pathfinding Engine** | [`dijkstra.dart`](file:///d:/vel/in_gokul_app/lib/algorithms/dijkstra.dart) | Computes 3D shortest path across map waypoints |
| **Graph Service** | [`graph_service.dart`](file:///d:/vel/in_gokul_app/lib/services/graph_service.dart) | Loads and manages nodes & edges from JSON |
| **3D World Alignment** | [`world_alignment_service.dart`](file:///d:/vel/in_gokul_app/lib/services/world_alignment_service.dart) | Coordinate transformations & yaw matrix rotation |
| **Sensor Fusion Tracking** | [`native_ar_position_provider.dart`](file:///d:/vel/in_gokul_app/lib/tracking/native_ar_position_provider.dart) | Compass heading + Accelerometer step detection |
| **AR Direction Arrow** | [`ar_arrow.dart`](file:///d:/vel/in_gokul_app/lib/ar/ar_arrow.dart) | 3D relative bearing calculations & directional cue |
| **Navigation State Machine** | [`navigation_controller.dart`](file:///d:/vel/in_gokul_app/lib/controllers/navigation_controller.dart) | Manages route progress, turns, and arrival thresholds |
| **Camera Service** | [`camera_service.dart`](file:///d:/vel/in_gokul_app/lib/services/camera_service.dart) | Live camera feed integration with graceful fallback |
| **AR Navigation Screen** | [`ar_navigation_screen.dart`](file:///d:/vel/in_gokul_app/lib/screens/ar_navigation_screen.dart) | Main HUD screen with live AR arrow, turns & progress |
| **Calibration Screen** | [`calibration_screen.dart`](file:///d:/vel/in_gokul_app/lib/screens/calibration_screen.dart) | Space alignment & reticle anchoring screen |
| **3D Web Node Editor** | [`main.js`](file:///d:/vel/main.js) | Three.js GLB model viewer and node creator tool |
