import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Arquivo escolhido pelo aluno, já em memória para upload.
class PickedMedia {
  const PickedMedia({required this.bytes, required this.name, required this.isVideo});

  final Uint8List bytes;
  final String name;
  final bool isVideo;
}

/// Abstração da galeria/câmera, para que as telas possam ser testadas com um seletor falso.
abstract class MediaPickerService {
  Future<List<PickedMedia>> pickFromGallery({required bool multiple, required bool allowVideo, required bool videoOnly});
  Future<PickedMedia?> capture({required bool video});
}

class DeviceMediaPicker implements MediaPickerService {
  DeviceMediaPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const _maxDimension = 1600.0;
  static const _quality = 85;
  static const _maxVideo = Duration(seconds: 90);

  @override
  Future<List<PickedMedia>> pickFromGallery({
    required bool multiple,
    required bool allowVideo,
    required bool videoOnly,
  }) async {
    final List<XFile> files;
    if (videoOnly) {
      final video = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: _maxVideo);
      files = video == null ? const [] : [video];
    } else if (multiple && allowVideo) {
      files = await _picker.pickMultipleMedia(maxWidth: _maxDimension, maxHeight: _maxDimension, imageQuality: _quality, limit: 10);
    } else if (multiple) {
      files = await _picker.pickMultiImage(maxWidth: _maxDimension, maxHeight: _maxDimension, imageQuality: _quality, limit: 10);
    } else if (allowVideo) {
      final file = await _picker.pickMedia(maxWidth: _maxDimension, maxHeight: _maxDimension, imageQuality: _quality);
      files = file == null ? const [] : [file];
    } else {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxDimension,
        maxHeight: _maxDimension,
        imageQuality: _quality,
      );
      files = file == null ? const [] : [file];
    }
    return Future.wait(files.map(_read));
  }

  @override
  Future<PickedMedia?> capture({required bool video}) async {
    final file = video
        ? await _picker.pickVideo(source: ImageSource.camera, maxDuration: _maxVideo)
        : await _picker.pickImage(
            source: ImageSource.camera,
            maxWidth: _maxDimension,
            maxHeight: _maxDimension,
            imageQuality: _quality,
          );
    return file == null ? null : _read(file);
  }

  Future<PickedMedia> _read(XFile file) async {
    final name = file.name.toLowerCase();
    final mime = file.mimeType ?? '';
    final isVideo = mime.startsWith('video/') || name.endsWith('.mp4') || name.endsWith('.mov') || name.endsWith('.m4v');
    return PickedMedia(bytes: await file.readAsBytes(), name: file.name, isVideo: isVideo);
  }
}
