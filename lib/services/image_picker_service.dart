import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_bootstrap.dart';

class PickedImageFile {
  const PickedImageFile({
    required this.file,
    required this.name,
    this.downloadUrl,
  });

  final XFile file;
  final String name;
  final String? downloadUrl;
}

class ImagePickerService {
  ImagePickerService._();

  static final ImagePickerService instance = ImagePickerService._();
  final ImagePicker _picker = ImagePicker();

  Future<PickedImageFile?> pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (file == null) return null;
    return PickedImageFile(file: file, name: _fileName(file));
  }

  Future<PickedImageFile?> pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2048,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return null;
    return PickedImageFile(file: file, name: _fileName(file));
  }

  Future<PickedImageFile?> pickDocument({required bool useCamera}) {
    return useCamera ? pickFromCamera() : pickFromGallery();
  }

  Future<PickedImageFile> uploadToStorage({
    required PickedImageFile image,
    required String storagePath,
  }) async {
    if (!FirebaseBootstrap.isReady) {
      return image;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return image;

    final ref = FirebaseStorage.instance.ref(storagePath);
    await ref.putFile(File(image.file.path));
    final url = await ref.getDownloadURL();
    return PickedImageFile(
      file: image.file,
      name: image.name,
      downloadUrl: url,
    );
  }

  String _fileName(XFile file) {
    final path = file.name.isNotEmpty ? file.name : file.path;
    return path.split(RegExp(r'[\\/]')).last;
  }
}
