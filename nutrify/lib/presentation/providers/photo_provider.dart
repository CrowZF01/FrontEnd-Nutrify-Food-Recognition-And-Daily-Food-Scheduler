import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';

class PhotoProvider extends ChangeNotifier {
  Uint8List? _imageBytes;
  Uint8List? _detectedImageBytes;
  bool _isLoading = false;
  String? _errorMessage;
  String _responseText = "Belum ada response";

  Uint8List? get imageBytes => _imageBytes;
  Uint8List? get detectedImageBytes => _detectedImageBytes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get responseText => _responseText;

  // Sediakan list kosong agar tidak ada error kompilasi jika widget lain mengaksesnya
  List<Map<String, dynamic>> get detectedIngredients => [];

  final ImagePicker _picker = ImagePicker();

  Future<void> pickFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo != null) {
        _imageBytes = await photo.readAsBytes();
        _detectedImageBytes = null;
        _responseText = "Belum ada response";
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Gagal mengambil foto: $e';
      _responseText = 'Error: $e';
      notifyListeners();
    }
  }

  Future<void> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        _imageBytes = await image.readAsBytes();
        _detectedImageBytes = null;
        _responseText = "Belum ada response";
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Gagal memilih gambar: $e';
      _responseText = 'Error: $e';
      notifyListeners();
    }
  }

  Future<void> detectIngredients() async {
    if (_imageBytes == null) return;

    _isLoading = true;
    _errorMessage = null;
    _responseText = "Mengirim...";
    _detectedImageBytes = null;
    notifyListeners();

    try {
      _detectedImageBytes = await ApiService.uploadPhotoForDetection(
        imageBytes: _imageBytes!,
      );
      _responseText = 'Berhasil! (${_detectedImageBytes!.length} bytes)';
    } catch (e) {
      _errorMessage = e.toString();
      _responseText = 'Error: $e';
      _detectedImageBytes = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  void setImageBytes(Uint8List bytes) {
    _imageBytes = bytes;
    _detectedImageBytes = null;
    _responseText = "Belum ada response";
    _errorMessage = null;
    notifyListeners();
  }

  void clearImage() {
    _imageBytes = null;
    _detectedImageBytes = null;
    _responseText = "Belum ada response";
    _errorMessage = null;
    notifyListeners();
  }
}
