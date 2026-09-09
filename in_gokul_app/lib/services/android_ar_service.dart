import 'dart:async';
import 'package:flutter/services.dart';
import '../core/platform/ar_channel.dart';
import '../models/ar_pose.dart';
import '../models/ar_tracking_state.dart';
import 'ar_service.dart';

class AndroidARService implements ARService {
  final StreamController<ARTrackingState> _trackingStateController =
      StreamController<ARTrackingState>.broadcast();
  final StreamController<ARPose> _poseController =
      StreamController<ARPose>.broadcast();

  StreamSubscription? _eventSubscription;

  AndroidARService() {
    _initEventChannel();
  }

  void _initEventChannel() {
    _eventSubscription = ARChannel.trackingEventChannel
        .receiveBroadcastStream()
        .listen((dynamic event) {
      if (event is Map) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(event);
        if (data.containsKey('trackingState')) {
          final state = ARTrackingStateX.fromString(data['trackingState'] as String?);
          _trackingStateController.add(state);
        }
        if (data.containsKey('pose')) {
          final poseJson = Map<String, dynamic>.from(data['pose'] as Map);
          final pose = ARPose.fromJson(poseJson);
          _poseController.add(pose);
        }
      }
    }, onError: (error) {
      _trackingStateController.add(ARTrackingState.error);
    });
  }

  @override
  Future<bool> isARSupported() async {
    try {
      final bool? result =
          await ARChannel.methodChannel.invokeMethod<bool>('checkARAvailability');
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> checkCameraPermission() async {
    try {
      final bool? result =
          await ARChannel.methodChannel.invokeMethod<bool>('checkCameraPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestCameraPermission() async {
    try {
      final bool? result =
          await ARChannel.methodChannel.invokeMethod<bool>('requestCameraPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> startARSession() async {
    try {
      final bool? result =
          await ARChannel.methodChannel.invokeMethod<bool>('startARSession');
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> resumeARSession() async {
    try {
      final bool? result =
          await ARChannel.methodChannel.invokeMethod<bool>('resumeARSession');
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> pauseARSession() async {
    try {
      final bool? result =
          await ARChannel.methodChannel.invokeMethod<bool>('pauseARSession');
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> stopARSession() async {
    try {
      final bool? result =
          await ARChannel.methodChannel.invokeMethod<bool>('stopARSession');
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> resetARSession() async {
    try {
      final bool? result =
          await ARChannel.methodChannel.invokeMethod<bool>('resetARSession');
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> placeTestMarker() async {
    try {
      final bool? result =
          await ARChannel.methodChannel.invokeMethod<bool>('placeTestMarker');
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> addNodeAnchor(double x, double y, double z) async {
    try {
      final bool? result = await ARChannel.methodChannel.invokeMethod<bool>(
        'addNodeAnchor',
        {'x': x, 'y': y, 'z': z},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> clearNodeAnchors() async {
    try {
      final bool? result =
          await ARChannel.methodChannel.invokeMethod<bool>('clearNodeAnchors');
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> updateNavigationRoute(
    List<Vector3D> routePoints,
    Vector3D destinationPoint,
  ) async {
    try {
      final List<Map<String, double>> pointsJson =
          routePoints.map((p) => {'x': p.x, 'y': p.y, 'z': p.z}).toList();
      final Map<String, double> destJson = {
        'x': destinationPoint.x,
        'y': destinationPoint.y,
        'z': destinationPoint.z,
      };

      final bool? result = await ARChannel.methodChannel.invokeMethod<bool>(
        'updateNavigationRoute',
        {
          'points': pointsJson,
          'destination': destJson,
        },
      );
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> clearNavigationRoute() async {
    try {
      final bool? result =
          await ARChannel.methodChannel.invokeMethod<bool>('clearNavigationRoute');
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getCameraDiagnostics() async {
    try {
      final Map<dynamic, dynamic>? result =
          await ARChannel.methodChannel.invokeMethod('getCameraDiagnostics');
      return result?.cast<String, dynamic>() ?? {};
    } on PlatformException {
      return {};
    } catch (_) {
      return {};
    }
  }

  @override
  Stream<ARTrackingState> get trackingStateStream =>
      _trackingStateController.stream;

  @override
  Stream<ARPose> get poseStream => _poseController.stream;

  void dispose() {
    _eventSubscription?.cancel();
    _trackingStateController.close();
    _poseController.close();
  }
}
