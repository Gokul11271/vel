import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  String? _errorMessage;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized && _controller != null && _controller!.value.isInitialized;
  String? get errorMessage => _errorMessage;

  /// Requests camera permission and initializes the back camera
  Future<bool> initializeCamera() async {
    if (isInitialized) return true;

    try {
      // 1. Request camera permission on mobile platforms
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          _errorMessage = 'Camera permission was denied. Please grant permission in App Settings.';
          debugPrint(_errorMessage);
          return false;
        }
      }

      // 2. Discover available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _errorMessage = 'No camera hardware found on this device.';
        debugPrint(_errorMessage);
        return false;
      }

      // 3. Select back camera, or fallback to first
      final backCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      // 4. Initialize CameraController
      await _controller?.dispose();
      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _isInitialized = true;
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to initialize camera: $e';
      debugPrint(_errorMessage);
      _isInitialized = false;
      return false;
    }
  }

  /// Pause/dispose camera when leaving screen
  Future<void> disposeCamera() async {
    _isInitialized = false;
    await _controller?.dispose();
    _controller = null;
  }
}
