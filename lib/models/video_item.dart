/// Immutable data model representing one tile in the masonry wall.
class VideoItem {
  final int index;
  final String assetPath;
  final String label;
  final double aspectRatio;

  const VideoItem({
    required this.index,
    required this.assetPath,
    required this.label,
    required this.aspectRatio,
  });

  @override
  String toString() =>
      'VideoItem(index: $index, asset: $assetPath, label: $label)';
}
