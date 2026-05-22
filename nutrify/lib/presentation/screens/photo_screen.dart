import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../providers/photo_provider.dart';

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key});

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isInitializingCamera = false;

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (_isInitializingCamera) return;
    setState(() {
      _isInitializingCamera = true;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final backCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );

        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      } else {
        _showError('Kamera tidak ditemukan di perangkat ini.');
      }
    } catch (e) {
      _showError('Gagal menginisialisasi kamera: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializingCamera = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _capturePhoto(PhotoProvider photoProv) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();
      photoProv.setImageBytes(bytes);
      _closeCamera();
    } catch (e) {
      _showError('Gagal mengambil gambar: $e');
    }
  }

  void _closeCamera() {
    _cameraController?.dispose();
    _cameraController = null;
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoProvider>(
      builder: (context, photoProv, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deteksi Makanan', style: AppTextStyles.heading2),
                const SizedBox(height: 4),
                Text('Ambil foto makanan untuk mendeteksi bahan',
                    style: AppTextStyles.bodySmall),
                const SizedBox(height: 20),

                // If camera is initialized, show live preview & centered shutter button
                if (_isCameraInitialized) ...[
                  // Camera preview
                  Container(
                    width: double.infinity,
                    height: 420,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: _cameraController != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: 1,
                                height: _cameraController!.value.aspectRatio,
                                child: CameraPreview(_cameraController!),
                              ),
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: SizedBox(
                      width: 200,
                      child: ElevatedButton.icon(
                        onPressed: () => _capturePhoto(photoProv),
                        icon: const Icon(Icons.camera, size: 18),
                        label: const Text('Ambil Foto'),
                      ),
                    ),
                  ),
                ] else if (photoProv.imageBytes != null) ...[
                  // 1. Original Image Section
                  const Text(
                    "Original:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.memory(
                      photoProv.imageBytes!,
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Status / Response Card
                  if (photoProv.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: Card(
                        margin: EdgeInsets.zero,
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.divider),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Response Server:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(photoProv.responseText),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 3. Response Image Section
                  if (photoProv.detectedImageBytes != null) ...[
                    const Text(
                      "Response Image:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(
                        photoProv.detectedImageBytes!,
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Buttons for Upload / Retake / Clear
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: photoProv.isLoading
                          ? null
                          : () => photoProv.detectIngredients(),
                      icon: const Icon(Icons.send, size: 18),
                      label: Text(photoProv.detectedImageBytes != null
                          ? 'Kirim Ulang'
                          : 'Deteksi Bahan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.calories,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: photoProv.isLoading
                              ? null
                              : () {
                                  photoProv.clearImage();
                                  _initializeCamera();
                                },
                          icon: const Icon(Icons.camera_alt, size: 16),
                          label: const Text('Ambil Ulang'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: photoProv.isLoading
                              ? null
                              : () => photoProv.clearImage(),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Hapus Foto'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Default state when no photo is loaded and camera is not active
                  Container(
                    width: double.infinity,
                    height: 420,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isInitializingCamera
                            ? const CircularProgressIndicator(
                                color: AppColors.primary,
                              )
                            : Icon(Icons.camera_alt_outlined,
                                size: 56, color: AppColors.textLight),
                        const SizedBox(height: 8),
                        Text(
                          _isInitializingCamera
                              ? 'Membuka kamera...'
                              : 'Ambil atau pilih foto makanan',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isInitializingCamera
                              ? null
                              : () {
                                  photoProv.clearImage();
                                  _initializeCamera();
                                },
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Kamera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isInitializingCamera
                              ? null
                              : () {
                                  _closeCamera();
                                  photoProv.pickFromGallery();
                                },
                          icon: const Icon(Icons.photo_library, size: 18),
                          label: const Text('Galeri'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
