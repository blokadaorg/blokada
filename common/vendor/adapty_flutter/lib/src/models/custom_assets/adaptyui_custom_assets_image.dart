part of 'adaptyui_custom_assets.dart';

final class AdaptyCustomAssetLocalImageAsset extends AdaptyCustomAsset {
  final String assetId;

  const AdaptyCustomAssetLocalImageAsset({
    required this.assetId,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'image',
      'asset_id': assetId,
    };
  }
}

final class AdaptyCustomAssetLocalImageData extends AdaptyCustomAsset {
  final Uint8List data;

  const AdaptyCustomAssetLocalImageData({
    required this.data,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'image',
      'value': base64Encode(data),
    };
  }
}

final class AdaptyCustomAssetLocalImageFile extends AdaptyCustomAsset {
  final String path;

  const AdaptyCustomAssetLocalImageFile({
    required this.path,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'image',
      'path': path,
    };
  }
}
