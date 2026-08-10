import 'package:flutter/material.dart';
import 'dart:typed_data' show Uint8List;
import 'dart:convert' show base64Encode;

part 'adaptyui_custom_assets_image.dart';
part 'adaptyui_custom_assets_video.dart';
part 'adaptyui_custom_assets_color.dart';
part 'adaptyui_custom_assets_gradient.dart';

sealed class AdaptyCustomAsset {
  const AdaptyCustomAsset();

  const factory AdaptyCustomAsset.localImageData({
    required Uint8List data,
  }) = AdaptyCustomAssetLocalImageData;

  const factory AdaptyCustomAsset.localImageAsset({
    required String assetId,
  }) = AdaptyCustomAssetLocalImageAsset;

  const factory AdaptyCustomAsset.localImageFile({
    required String path,
  }) = AdaptyCustomAssetLocalImageFile;

  const factory AdaptyCustomAsset.localVideoAsset({
    required String assetId,
  }) = AdaptyCustomAssetLocalVideoAsset;

  const factory AdaptyCustomAsset.localVideoFile({
    required String path,
  }) = AdaptyCustomAssetLocalVideoFile;

  const factory AdaptyCustomAsset.color({
    required Color color,
  }) = AdaptyCustomAssetColor;

  const factory AdaptyCustomAsset.linearGradient({
    required LinearGradient gradient,
  }) = AdaptyCustomAssetLinearGradient;

  Map<String, dynamic> get jsonValue;
}
