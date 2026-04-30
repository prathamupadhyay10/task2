import 'dart:async';
import 'package:flutter/material.dart';

/// Delays execution of [action] until [delay] has passed without a new call.
/// Used to debounce rapid visibility changes during fast scrolling.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
