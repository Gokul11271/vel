import 'package:flutter/services.dart';

class ARChannel {
  static const MethodChannel methodChannel =
      MethodChannel('com.example.indoornavigation/ar_channel');

  static const EventChannel trackingEventChannel =
      EventChannel('com.example.indoornavigation/ar_events');

  static const String viewType = 'com.example.indoornavigation/ar_view';
}
