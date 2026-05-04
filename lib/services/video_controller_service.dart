import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../core/constants/app_constants.dart';

class VideoControllerService extends ChangeNotifier {
  final Map<int, VideoPlayerController> _pool = {};
  final Map<int, VoidCallback> _pauseCallbacks = {};
  final Set<int> _playingTiles = {};
  bool _foregrounded = true;

  Set<int> get playingTiles => _playingTiles;
  bool get foregrounded => _foregrounded;
  bool get hasCapacity => _pool.length < kMaxActiveControllers;

  VideoPlayerController? controllerFor(int index) => _pool[index];

  bool ownsController(int index, VideoPlayerController? controller) {
    return controller != null && identical(_pool[index], controller);
  }

  Future<VideoPlayerController?> register(
    int index,
    String networkUrl,
    VoidCallback pauseCallback,
  ) async {
    if (_pool.containsKey(index)) {
      _pauseCallbacks[index] = pauseCallback;
      return _pool[index];
    }

    if (_pool.length >= kMaxActiveControllers) {
      _evictFarthest(pivot: index);
    }

    final controller = VideoPlayerController.asset(
      networkUrl,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _pool[index] = controller;
    _pauseCallbacks[index] = pauseCallback;

    try {
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0);
      debugPrint('✅ VideoControllerService: Initialized controller for index $index');
      return controller;
    } catch (e) {
      debugPrint('❌ VideoControllerService: Failed to initialize index $index: $e');
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
    _playingTiles.remove(index);
    _disposeAfterFrame(controller);

    notifyListeners();
  }

  Future<void> requestPlay(int index) async {
    if (!_foregrounded) return;
    if (_playingTiles.contains(index)) return;

    _playingTiles.add(index);
    await _pool[index]?.play();
    notifyListeners();
  }

  void pauseTile(int index) {
    _pool[index]?.pause();
    _playingTiles.remove(index);
    notifyListeners();
  }

  void pauseAll() {
    for (final cb in _pauseCallbacks.values) {
      cb();
    }
    for (final ctrl in _pool.values) {
      ctrl.pause();
    }
    _playingTiles.clear();
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
      if (_playingTiles.contains(key)) continue;
      final distance = (key - pivot).abs();
      if (distance > maxDistance) {
        maxDistance = distance;
        victim = key;
      }
    }

    victim ??= _pool.keys.first;

    final controller = _pool.remove(victim);
    final pauseCallback = _pauseCallbacks.remove(victim);

    pauseCallback?.call();
    _playingTiles.remove(victim);
    _disposeAfterFrame(controller);

    notifyListeners();
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
    _playingTiles.clear();
    super.dispose();
  }
}
