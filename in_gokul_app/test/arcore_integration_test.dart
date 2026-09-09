import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_gokul_app/core/platform/ar_channel.dart';
import 'package:in_gokul_app/models/ar_pose.dart';
import 'package:in_gokul_app/models/ar_tracking_state.dart';
import 'package:in_gokul_app/services/android_ar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARCore Models & Coordinate System', () {
    test('Vector3D serializes to and from JSON correctly', () {
      const vec = Vector3D(x: 1.5, y: -0.2, z: 4.8);
      final json = vec.toJson();
      expect(json['x'], 1.5);
      expect(json['y'], -0.2);
      expect(json['z'], 4.8);

      final decoded = Vector3D.fromJson(json);
      expect(decoded.x, 1.5);
      expect(decoded.y, -0.2);
      expect(decoded.z, 4.8);
    });

    test('Quaternion4D serializes to and from JSON correctly', () {
      const q = Quaternion4D(x: 0.1, y: 0.2, z: 0.3, w: 0.9);
      final json = q.toJson();
      expect(json['w'], 0.9);

      final decoded = Quaternion4D.fromJson(json);
      expect(decoded.x, 0.1);
      expect(decoded.w, 0.9);
    });

    test('ARPose correctly parses native ARCore 6DoF event map', () {
      final nativePayload = {
        'position': {'x': 2.14, 'y': 0.05, 'z': -3.80},
        'rotation': {'x': 0.0, 'y': 0.707, 'z': 0.0, 'w': 0.707},
        'trackingState': 'TRACKING',
        'timestamp': 1725880000000,
        'isMarkerPlaced': true,
      };

      final pose = ARPose.fromJson(nativePayload);
      expect(pose.position.x, closeTo(2.14, 0.001));
      expect(pose.position.z, closeTo(-3.80, 0.001));
      expect(pose.rotation.w, closeTo(0.707, 0.001));
      expect(pose.trackingState, 'TRACKING');
      expect(pose.isMarkerPlaced, true);
    });

    test('ARTrackingState extensions parse native state strings', () {
      expect(ARTrackingStateX.fromString('TRACKING'), ARTrackingState.tracking);
      expect(ARTrackingStateX.fromString('PAUSED'), ARTrackingState.paused);
      expect(ARTrackingStateX.fromString('STOPPED'), ARTrackingState.stopped);
      expect(ARTrackingStateX.fromString('INITIALIZING'), ARTrackingState.initializing);
      expect(ARTrackingStateX.fromString('UNKNOWN'), ARTrackingState.error);

      expect(ARTrackingState.tracking.displayName, 'Tracking');
      expect(ARTrackingState.error.displayName, 'Error / Unsupported');
    });
  });

  group('AndroidARService MethodChannel Integration', () {
    late AndroidARService arService;
    final List<MethodCall> calls = [];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ARChannel.methodChannel, (MethodCall call) async {
        calls.add(call);
        switch (call.method) {
          case 'checkARAvailability':
            return true;
          case 'checkCameraPermission':
            return true;
          case 'requestCameraPermission':
            return true;
          case 'startARSession':
            return true;
          case 'resumeARSession':
            return true;
          case 'pauseARSession':
            return true;
          case 'stopARSession':
            return true;
          case 'addNodeAnchor':
            return true;
          case 'updateNavigationRoute':
            return true;
          default:
            return null;
        }
      });
      arService = AndroidARService();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ARChannel.methodChannel, null);
      arService.dispose();
    });

    test('isARSupported queries checkARAvailability', () async {
      final supported = await arService.isARSupported();
      expect(supported, true);
      expect(calls.any((c) => c.method == 'checkARAvailability'), true);
    });

    test('addNodeAnchor transmits 3D coordinates to native ARCore', () async {
      final success = await arService.addNodeAnchor(3.5, 0.0, -2.1);
      expect(success, true);
      final call = calls.firstWhere((c) => c.method == 'addNodeAnchor');
      expect(call.arguments['x'], 3.5);
      expect(call.arguments['y'], 0.0);
      expect(call.arguments['z'], -2.1);
    });

    test('updateNavigationRoute transmits path waypoints & destination', () async {
      final points = [
        const Vector3D(x: 0, y: 0, z: 0),
        const Vector3D(x: 2, y: 0, z: 0),
        const Vector3D(x: 2, y: 0, z: 4),
      ];
      const dest = Vector3D(x: 2, y: 0, z: 4);

      final success = await arService.updateNavigationRoute(points, dest);
      expect(success, true);
      final call = calls.firstWhere((c) => c.method == 'updateNavigationRoute');
      final pointsArg = call.arguments['points'] as List;
      expect(pointsArg.length, 3);
      expect(call.arguments['destination']['z'], 4.0);
    });
  });
}
