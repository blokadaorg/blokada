part of 'adaptyui_custom_assets.dart';

final class AdaptyCustomAssetLocalVideoAsset extends AdaptyCustomAsset {
  final String assetId;

  const AdaptyCustomAssetLocalVideoAsset({
    required this.assetId,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'video',
      'asset_id': assetId,
    };
  }
}

final class AdaptyCustomAssetLocalVideoFile extends AdaptyCustomAsset {
  final String path;

  const AdaptyCustomAssetLocalVideoFile({
    required this.path,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'video',
      'path': path,
    };
  }
}
