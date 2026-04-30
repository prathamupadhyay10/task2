import 'package:flutter/widgets.dart';

import '../core/constants/app_constants.dart';
import '../models/video_item.dart';
import '../services/video_controller_service.dart';

class VideoWallProvider extends ChangeNotifier {
  late final List<VideoItem> items;
  final VideoControllerService controllerService = VideoControllerService();

  VideoWallProvider() {
    _buildItems();
  }

  void _buildItems() {
    items = List.generate(
      kTotalTiles,
      (i) => VideoItem(
        index: i,
        assetPath: kVideoAssets[i % kVideoCount],
        label: kTileLabels[i % kTileLabels.length],
        aspectRatio: kGridTileAspectRatio,
      ),
    );
  }

  @override
  void dispose() {
    controllerService.dispose();
    super.dispose();
  }
}
