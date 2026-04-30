import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../core/constants/app_constants.dart';

/// Shared controller pool for the masonry wall.
///
/// Rules:
/// - Keep at most [kMaxActiveControllers] alive at once.
/// - Only one tile plays at a time.
/// - Evict the farthest tile first when the pool is full.
class VideoControllerService extends ChangeNotifier {
  final Map<int, VideoPlayerController> _pool = {};
  final Map<int, VoidCallback> _pauseCallbacks = {};

  int? _playingIndex;
  bool _foregrounded = true;

  int? get playingIndex => _playingIndex;
  bool get foregrounded => _foregrounded;
  bool get hasCapacity => _pool.length < kMaxActiveControllers;

  VideoPlayerController? controllerFor(int index) => _pool[index];

  bool ownsController(int index, VideoPlayerController? controller) {
    return controller != null && identical(_pool[index], controller);
  }

  Future<VideoPlayerController?> register(
    int index,
    String assetPath,
    VoidCallback pauseCallback,
  ) async {
    if (_pool.containsKey(index)) {
      _pauseCallbacks[index] = pauseCallback;
      return _pool[index];
    }

    if (_pool.length >= kMaxActiveControllers) {
      _evictFarthest(pivot: index);
    }

    final controller = VideoPlayerController.asset(assetPath);
    _pool[index] = controller;
    _pauseCallbacks[index] = pauseCallback;

    try {
      await controller.initialize();
      controller.setLooping(true);
      return controller;
    } catch (_) {
      _pool.remove(index);
      _pauseCallbacks.remove(index);
      controller.dispose();
      return null;
    }
  }

  void release(int index) {
    final controller = _pool.remove(index);
    final pauseCallback = _pauseCallbacks.remove(index);

    pauseCallback?.call();
    _disposeAfterFrame(controller);

    if (_playingIndex == index) {
      _playingIndex = null;
      notifyListeners();
    }
  }

  Future<void> requestPlay(int index) async {
    if (!_foregrounded) return;
    if (_playingIndex == index) return;

    if (_playingIndex != null) {
      _pauseCallbacks[_playingIndex]?.call();
      _pool[_playingIndex]?.pause();
    }

    _playingIndex = index;
    await _pool[index]?.play();
    notifyListeners();
  }

  void pauseTile(int index) {
    _pool[index]?.pause();
    if (_playingIndex == index) {
      _playingIndex = null;
      notifyListeners();
    }
  }

  void pauseAll() {
    for (final cb in _pauseCallbacks.values) {
      cb();
    }
    for (final ctrl in _pool.values) {
      ctrl.pause();
    }
    _foregrounded = false;
    notifyListeners();
  }

  void resumeForeground() {
    _foregrounded = true;
    notifyListeners();
  }

  Duration positionOf(int index) {
    return _pool[index]?.value.position ?? Duration.zero;
  }

  void _evictFarthest({required int pivot}) {
    if (_pool.isEmpty) return;

    int? victim;
    var maxDistance = -1;

    for (final key in _pool.keys) {
      final distance = (key - pivot).abs();
      if (distance > maxDistance) {
        maxDistance = distance;
        victim = key;
      }
    }

    if (victim == null) return;

    final controller = _pool.remove(victim);
    final pauseCallback = _pauseCallbacks.remove(victim);

    pauseCallback?.call();
    _disposeAfterFrame(controller);

    if (_playingIndex == victim) {
      _playingIndex = null;
      notifyListeners();
    }
  }

  void _disposeAfterFrame(VideoPlayerController? controller) {
    if (controller == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  @override
  void dispose() {
    for (final ctrl in _pool.values) {
      ctrl.dispose();
    }
    _pool.clear();
    _pauseCallbacks.clear();
    super.dispose();
  }
}
