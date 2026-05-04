import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/video_item.dart';
import '../screens/fullscreen_player_screen.dart';
import '../services/video_controller_service.dart';

class VideoTileCard extends StatefulWidget {
  final VideoItem item;
  final VideoControllerService service;

  const VideoTileCard({
    super.key,
    required this.item,
    required this.service,
  });

  @override
  State<VideoTileCard> createState() => _VideoTileCardState();
}

class _VideoTileCardState extends State<VideoTileCard>
    with TickerProviderStateMixin {
  VideoPlayerController? _ctrl;
  bool _initialising = false;
  bool _disposed = false;
  bool _fullscreenOpen = false;

  late final AnimationController _pressAnim;
  late final Animation<double> _scale;

  late final AnimationController _hoverAnim;
  late final Animation<double> _hoverScale;
  late final Animation<double> _hoverBlur;
  late final Animation<double> _hoverOpacity;

  bool _isHovering = false;
  bool _showOverlay = false;
  Timer? _overlayTimer;
  Timer? _visDebounce;
  late final Key _visKey;

  @override
  void initState() {
    super.initState();
    _visKey = Key('tile_${widget.item.index}');

    _pressAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressAnim, curve: Curves.easeOut),
    );

    _hoverAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _hoverScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _hoverAnim, curve: Curves.easeOutCubic),
    );
    _hoverBlur = Tween<double>(begin: 0.0, end: 3.0).animate(
      CurvedAnimation(parent: _hoverAnim, curve: Curves.easeOutCubic),
    );
    _hoverOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverAnim, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant VideoTileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.index != widget.item.index ||
        oldWidget.service != widget.service) {
      final hadController = _ctrl != null;
      _detachController();
      if (hadController) {
        oldWidget.service.release(oldWidget.item.index);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _visDebounce?.cancel();
    _overlayTimer?.cancel();
    _pressAnim.dispose();
    _hoverAnim.dispose();
    _releaseController();
    super.dispose();
  }

  void _detachController() {
    _ctrl = null;
    _initialising = false;
  }

  void _releaseController() {
    final hadController = _ctrl != null;
    _detachController();

    if (hadController) {
      widget.service.release(widget.item.index);
    }
  }

  void _pauseCallback() {
    if (_disposed || !mounted) return;

    if (!widget.service.ownsController(widget.item.index, _ctrl)) {
      _detachController();
    }

    setState(() {});
  }

  VideoPlayerController? get _activeController {
    final controller = _ctrl;
    if (controller == null) return null;

    if (!identical(widget.service.controllerFor(widget.item.index), controller)) {
      _detachController();
      return null;
    }

    return controller;
  }

  Future<void> _activateTile() async {
    if (_initialising || _activeController != null || _disposed) return;
    if (_ctrl != null) _detachController();
    _initialising = true;

    try {
      final controller = await widget.service.register(
        widget.item.index,
        widget.item.assetPath,
        _pauseCallback,
      );

      debugPrint('🎬 VideoTileCard: register returned for index ${widget.item.index}, controller=${controller != null}');

      if (_disposed || !mounted) {
        if (controller != null) {
          widget.service.release(widget.item.index);
        }
        return;
      }

      if (controller != null &&
          identical(widget.service.controllerFor(widget.item.index), controller)) {
        setState(() => _ctrl = controller);
        debugPrint('▶️ VideoTileCard: Set state with controller for index ${widget.item.index}');
        await widget.service.requestPlay(widget.item.index);
        if (mounted && !_disposed) {
          setState(() {});
          debugPrint('🎥 VideoTileCard: isInitialized=${controller.value.isInitialized}, isPlaying=${controller.value.isPlaying}');
        }
      }
    } finally {
      _initialising = false;
    }
  }

  Future<void> _deactivateTile() async {
    if (_activeController == null || _fullscreenOpen) return;
    widget.service.pauseTile(widget.item.index);
    _releaseController();
    if (mounted && !_disposed) {
      setState(() {});
    }
  }

  void _onVisibility(VisibilityInfo info) {
    if (_fullscreenOpen) return;

    _visDebounce?.cancel();
    _visDebounce = Timer(const Duration(milliseconds: 80), () {
      if (_disposed || !mounted || _fullscreenOpen) return;

      final frac = info.visibleFraction;
      debugPrint('👁️ VideoTileCard: index=${widget.item.index}, visibleFraction=$frac');
      if (frac >= kPlayThreshold) {
        debugPrint('🟢 VideoTileCard: Activating tile ${widget.item.index}');
        _activateTile();
      } else if (frac < kPauseThreshold) {
        debugPrint('🔴 VideoTileCard: Deactivating tile ${widget.item.index}');
        _deactivateTile();
      }
    });
  }

  Future<void> _openFullscreen() async {
    if (_fullscreenOpen) return;

    _fullscreenOpen = true;
    final position = widget.service.positionOf(widget.item.index);
    widget.service.pauseTile(widget.item.index);

    try {
      await Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: FullscreenPlayerScreen(
              item: widget.item,
              startPosition: position,
              heroTag: 'video_hero_${widget.item.index}',
            ),
          ),
        ),
      );
    } finally {
      _fullscreenOpen = false;
    }

    if (!mounted || _disposed) return;

    if (_activeController != null) {
      await widget.service.requestPlay(widget.item.index);
      if (mounted && !_disposed) {
        setState(() {});
      }
    } else {
      await _activateTile();
    }
  }

  void _showTileOverlay() {
    _overlayTimer?.cancel();
    _hoverAnim.forward();
    setState(() => _showOverlay = true);
    _overlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_disposed) {
        _hoverAnim.reverse();
        setState(() => _showOverlay = false);
      }
    });
  }

  void _onHoverEnter() {
    if (_disposed || !mounted) return;
    _isHovering = true;
    _hoverAnim.forward();
  }

  void _onHoverExit() {
    if (_disposed || !mounted) return;
    _isHovering = false;
    _hoverAnim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _visKey,
      onVisibilityChanged: _onVisibility,
      child: MouseRegion(
        onEnter: (_) => _onHoverEnter(),
        onExit: (_) => _onHoverExit(),
        child: GestureDetector(
          onTap: _openFullscreen,
          onLongPress: _showTileOverlay,
          onTapDown: (_) => _pressAnim.forward(),
          onTapUp: (_) => _pressAnim.reverse(),
          onTapCancel: () => _pressAnim.reverse(),
          child: AnimatedBuilder(
            animation: Listenable.merge([_scale, _hoverScale]),
            builder: (_, child) => Transform.scale(
              scale: _scale.value * _hoverScale.value,
              child: child,
            ),
            child: RepaintBoundary(child: _buildCard()),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final controller = _activeController;
    final isPlaying = controller != null &&
        controller.value.isInitialized &&
        controller.value.isPlaying;

    return AspectRatio(
      aspectRatio: widget.item.aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'video_hero_${widget.item.index}',
              child: _buildVideoLayer(controller),
            ),
            _buildBottomGradient(),
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_hoverAnim, _pressAnim]),
                builder: (_, __) => _buildHoverOverlay(),
              ),
            ),
            if (isPlaying)
              const Positioned(
                top: 8,
                right: 8,
                child: _LiveDot(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoLayer(VideoPlayerController? controller) {
    if (controller != null && controller.value.isInitialized) {
      return RepaintBoundary(
        child: VideoPlayer(controller),
      );
    }

    return _Shimmer();
  }

  Widget _buildBottomGradient() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 28, 10, 10),
        decoration: const BoxDecoration(gradient: AppTheme.cardGradient),
        child: Text(
          widget.item.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildHoverOverlay() {
    final showOverlay = _showOverlay || _isHovering;
    final blurAmount = _hoverBlur.value;
    final overlayAlpha = _hoverOpacity.value;

    return AnimatedOpacity(
      opacity: showOverlay ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
          child: Container(
            color: Color.fromARGB(
              (overlayAlpha * 136).toInt(),
              0,
              0,
              0,
            ),
            child: Center(
              child: Icon(
                Icons.play_circle_filled_rounded,
                color: AppTheme.accentRed.withValues(alpha: 0.5 + 0.5 * overlayAlpha),
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1C1C1C),
              Color.lerp(
                const Color(0xFF1C1C1C),
                const Color(0xFF2E2E2E),
                _anim.value,
              )!,
              const Color(0xFF1C1C1C),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.accentRed.withValues(alpha: 0.6 + 0.4 * _anim.value),
        ),
      ),
    );
  }
}
