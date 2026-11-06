import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../core/app_colors.dart';
import '../services/cloudinary_service.dart';

// ---------------------------------------------------------------------------
// Add Car Screen
// ---------------------------------------------------------------------------

/// Full "Add Car" form with media uploads via Cloudinary and Firestore storage.
///
/// Required fields (all compulsory):
///   Media  – 4 car photos, 2 RC photos, 1 Aadhaar photo, 1 pollution cert photo,
///             1 insurance cert photo, 2 chassis-number photos, 1 vehicle video
///   Text   – model, variant/option, price, description, tyre %, fuel type,
///             owner mobile number
class AddCarScreen extends StatefulWidget {
  const AddCarScreen({super.key});

  @override
  State<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends State<AddCarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // ── Text controllers ──────────────────────────────────────────────────────
  final _modelCtrl = TextEditingController();
  final _optionCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tyreCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();

  // ── Dropdown selections ───────────────────────────────────────────────────
  String? _fuelType;
  static const _fuelTypes = ['Petrol', 'Diesel', 'CNG', 'Electric', 'Hybrid'];

  // ── Media picks ───────────────────────────────────────────────────────────
  /// 4 car exterior/interior photos
  final List<File?> _carPhotos = List.filled(4, null);

  /// 2 RC (Registration Certificate) photos – front & back
  final List<File?> _rcPhotos = List.filled(2, null);

  /// 1 Owner Aadhaar photo
  File? _aadhaarPhoto;

  /// 1 Pollution Certificate photo
  File? _pollutionPhoto;

  /// 1 Insurance Certificate photo
  File? _insurancePhoto;

  /// 2 Chassis number photos
  final List<File?> _chassisPhotos = List.filled(2, null);

  /// 1 Vehicle video
  File? _vehicleVideo;
  VideoPlayerController? _videoController;

  // ── Upload state ──────────────────────────────────────────────────────────
  bool _uploading = false;
  String _uploadStatus = '';

  @override
  void dispose() {
    _modelCtrl.dispose();
    _optionCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _tyreCtrl.dispose();
    _mobileCtrl.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Pickers
  // ---------------------------------------------------------------------------

  Future<void> _pickImage({
    required void Function(File file) onPicked,
  }) async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile == null) return;
    setState(() => onPicked(File(xfile.path)));
  }

  Future<void> _pickVideo() async {
    final xfile = await _picker.pickVideo(source: ImageSource.gallery);
    if (xfile == null) return;
    _videoController?.dispose();
    final ctrl = VideoPlayerController.file(File(xfile.path));
    await ctrl.initialize();
    if (!mounted) return;
    setState(() {
      _vehicleVideo = File(xfile.path);
      _videoController = ctrl;
    });
  }

  // ---------------------------------------------------------------------------
  // Validation helpers
  // ---------------------------------------------------------------------------

  /// Returns true if all required media has been picked.
  bool get _allMediaPicked {
    final carOk = _carPhotos.every((f) => f != null);
    final rcOk = _rcPhotos.every((f) => f != null);
    final chassisOk = _chassisPhotos.every((f) => f != null);
    return carOk &&
        rcOk &&
        _aadhaarPhoto != null &&
        _pollutionPhoto != null &&
        _insurancePhoto != null &&
        chassisOk &&
        _vehicleVideo != null;
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_allMediaPicked) {
      _showSnack('Please fill all required photos and video.');
      return;
    }

    setState(() {
      _uploading = true;
      _uploadStatus = 'Uploading media to Cloudinary…';
    });

    try {
      // We use a temporary folder name based on timestamp; a real car doc id
      // could be used once the Firestore document is created first.
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      final folder = 'cars/$ts';

      // ── Upload car photos ────────────────────────────────────────────────
      _setStatus('Uploading car photos (1/7)…');
      final carPhotoUrls = <String>[];
      for (int i = 0; i < _carPhotos.length; i++) {
        final url = await CloudinaryService.uploadImage(
          _carPhotos[i]!,
          folder: '$folder/car_photos',
        );
        carPhotoUrls.add(url);
      }

      // ── Upload RC photos ─────────────────────────────────────────────────
      _setStatus('Uploading RC photos (2/7)…');
      final rcPhotoUrls = <String>[];
      for (final f in _rcPhotos) {
        rcPhotoUrls.add(await CloudinaryService.uploadImage(
          f!,
          folder: '$folder/rc',
        ));
      }

      // ── Upload Aadhaar photo ─────────────────────────────────────────────
      _setStatus('Uploading Aadhaar photo (3/7)…');
      final aadhaarUrl = await CloudinaryService.uploadImage(
        _aadhaarPhoto!,
        folder: '$folder/aadhaar',
      );

      // ── Upload Pollution Certificate ─────────────────────────────────────
      _setStatus('Uploading Pollution Certificate (4/7)…');
      final pollutionUrl = await CloudinaryService.uploadImage(
        _pollutionPhoto!,
        folder: '$folder/pollution',
      );

      // ── Upload Insurance Certificate ─────────────────────────────────────
      _setStatus('Uploading Insurance Certificate (5/7)…');
      final insuranceUrl = await CloudinaryService.uploadImage(
        _insurancePhoto!,
        folder: '$folder/insurance',
      );

      // ── Upload Chassis photos ────────────────────────────────────────────
      _setStatus('Uploading Chassis photos (6/7)…');
      final chassisUrls = <String>[];
      for (final f in _chassisPhotos) {
        chassisUrls.add(await CloudinaryService.uploadImage(
          f!,
          folder: '$folder/chassis',
        ));
      }

      // ── Upload Vehicle video ─────────────────────────────────────────────
      _setStatus('Uploading Vehicle video (7/7)…');
      final videoUrl = await CloudinaryService.uploadVideo(
        _vehicleVideo!,
        folder: '$folder/video',
      );

      // ── Save to Firestore ────────────────────────────────────────────────
      _setStatus('Saving to Firestore…');
      await FirebaseFirestore.instance.collection('cars').add({
        'model': _modelCtrl.text.trim(),
        'option': _optionCtrl.text.trim(),
        'price': int.tryParse(_priceCtrl.text.trim()) ?? 0,
        'description': _descCtrl.text.trim(),
        'tyrePercent': int.tryParse(_tyreCtrl.text.trim()) ?? 0,
        'fuelType': _fuelType,
        'ownerMobile': _mobileCtrl.text.trim(),
        'carPhotos': carPhotoUrls,
        'rcPhotos': rcPhotoUrls,
        'aadhaarPhotoUrl': aadhaarUrl,
        'pollutionCertUrl': pollutionUrl,
        'insuranceCertUrl': insuranceUrl,
        'chassisPhotos': chassisUrls,
        'videoUrl': videoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnack('Car added successfully! 🎉', isError: false);
      _resetForm();
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _uploadStatus = msg);
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _modelCtrl.clear();
    _optionCtrl.clear();
    _priceCtrl.clear();
    _descCtrl.clear();
    _tyreCtrl.clear();
    _mobileCtrl.clear();
    _videoController?.dispose();
    setState(() {
      _fuelType = null;
      for (int i = 0; i < 4; i++) _carPhotos[i] = null;
      for (int i = 0; i < 2; i++) _rcPhotos[i] = null;
      for (int i = 0; i < 2; i++) _chassisPhotos[i] = null;
      _aadhaarPhoto = null;
      _pollutionPhoto = null;
      _insurancePhoto = null;
      _vehicleVideo = null;
      _videoController = null;
    });
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Decorative arcs
          Positioned(top: -50, left: -50, child: _Arc()),
          Positioned(bottom: -50, right: -50, child: _Arc(flip: true)),

          SafeArea(
            child: Column(
              children: [
                _Header(),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        // ── Car Photos ───────────────────────────────────────
                        _SectionTitle(title: '🚗 Car Photos', subtitle: '4 required'),
                        _PhotoGrid(
                          count: 4,
                          files: _carPhotos,
                          labels: ['Front', 'Rear', 'Interior', 'Side'],
                          onPick: (i) => _pickImage(
                            onPicked: (f) => setState(() => _carPhotos[i] = f),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── RC Photos ────────────────────────────────────────
                        _SectionTitle(title: '📄 Registration Certificate (RC)', subtitle: '2 required'),
                        _PhotoGrid(
                          count: 2,
                          files: _rcPhotos,
                          labels: ['RC Front', 'RC Back'],
                          onPick: (i) => _pickImage(
                            onPicked: (f) => setState(() => _rcPhotos[i] = f),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Aadhaar Photo ────────────────────────────────────
                        _SectionTitle(title: '🪪 Owner Aadhaar', subtitle: '1 required'),
                        _SinglePhotoTile(
                          file: _aadhaarPhoto,
                          label: 'Aadhaar Photo',
                          onPick: () => _pickImage(onPicked: (f) => setState(() => _aadhaarPhoto = f)),
                        ),
                        const SizedBox(height: 20),

                        // ── Pollution Certificate ────────────────────────────
                        _SectionTitle(title: '🌿 Pollution Certificate', subtitle: '1 required'),
                        _SinglePhotoTile(
                          file: _pollutionPhoto,
                          label: 'Pollution Cert',
                          onPick: () => _pickImage(onPicked: (f) => setState(() => _pollutionPhoto = f)),
                        ),
                        const SizedBox(height: 20),

                        // ── Insurance Certificate ────────────────────────────
                        _SectionTitle(title: '🛡️ Insurance Certificate', subtitle: '1 required'),
                        _SinglePhotoTile(
                          file: _insurancePhoto,
                          label: 'Insurance Cert',
                          onPick: () => _pickImage(onPicked: (f) => setState(() => _insurancePhoto = f)),
                        ),
                        const SizedBox(height: 20),

                        // ── Chassis Photos ───────────────────────────────────
                        _SectionTitle(title: '🔩 Chassis Number', subtitle: '2 required'),
                        _PhotoGrid(
                          count: 2,
                          files: _chassisPhotos,
                          labels: ['Chassis 1', 'Chassis 2'],
                          onPick: (i) => _pickImage(
                            onPicked: (f) => setState(() => _chassisPhotos[i] = f),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Vehicle Video ────────────────────────────────────
                        _SectionTitle(title: '🎥 Vehicle Video', subtitle: '1 required'),
                        _VideoPickerTile(
                          file: _vehicleVideo,
                          controller: _videoController,
                          onPick: _pickVideo,
                        ),
                        const SizedBox(height: 28),

                        // ── Text Fields ──────────────────────────────────────
                        _SectionTitle(title: '📋 Car Details', subtitle: 'All fields required'),
                        const SizedBox(height: 12),

                        _RcTextField(
                          controller: _modelCtrl,
                          label: 'Model',
                          hint: 'e.g. Hyundai Creta',
                          icon: Icons.directions_car_outlined,
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        _RcTextField(
                          controller: _optionCtrl,
                          label: 'Variant / Option',
                          hint: 'e.g. SX(O) Turbo',
                          icon: Icons.tune_outlined,
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        _RcTextField(
                          controller: _priceCtrl,
                          label: 'Price (₹)',
                          hint: 'e.g. 850000',
                          icon: Icons.currency_rupee_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        _RcTextField(
                          controller: _mobileCtrl,
                          label: 'Owner Mobile Number',
                          hint: 'e.g. 9876543210',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (v.trim().length != 10) return 'Enter a valid 10-digit mobile number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _RcTextField(
                          controller: _tyreCtrl,
                          label: 'Tyre Condition (%)',
                          hint: 'e.g. 80',
                          icon: Icons.radio_button_unchecked_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final val = int.tryParse(v.trim());
                            if (val == null || val < 0 || val > 100) {
                              return 'Enter a value between 0 and 100';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Fuel type dropdown
                        _FuelTypeDropdown(
                          value: _fuelType,
                          items: _fuelTypes,
                          onChanged: (v) => setState(() => _fuelType = v),
                        ),
                        const SizedBox(height: 14),

                        _RcTextField(
                          controller: _descCtrl,
                          label: 'Description',
                          hint: 'Describe the vehicle condition, features…',
                          icon: Icons.notes_outlined,
                          maxLines: 4,
                          validator: _required,
                        ),
                        const SizedBox(height: 32),

                        // ── Submit button ────────────────────────────────────
                        _SubmitButton(
                          uploading: _uploading,
                          statusText: _uploadStatus,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Full-screen upload overlay
          if (_uploading) _UploadOverlay(status: _uploadStatus),
        ],
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
}

// ---------------------------------------------------------------------------
// Header widget
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.8),
              color: AppColors.surface,
            ),
            child: ClipOval(
              child: Image.asset('assets/images/rc_logo.jpg', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add New Car',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  )),
              Text('Fill all details before submitting',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section title
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Text(subtitle,
                style: const TextStyle(
                    color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo grid (n slots)
// ---------------------------------------------------------------------------

class _PhotoGrid extends StatelessWidget {
  final int count;
  final List<File?> files;
  final List<String> labels;
  final void Function(int index) onPick;

  const _PhotoGrid({
    required this.count,
    required this.files,
    required this.labels,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (_, i) => _PhotoSlot(
        file: files[i],
        label: labels[i],
        onTap: () => onPick(i),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual photo slot
// ---------------------------------------------------------------------------

class _PhotoSlot extends StatelessWidget {
  final File? file;
  final String label;
  final VoidCallback onTap;

  const _PhotoSlot({required this.file, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file != null ? AppColors.gold : AppColors.border,
            width: file != null ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: file != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(file!, fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined,
                        color: AppColors.gold, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  const Text('Tap to add',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single photo tile (full-width)
// ---------------------------------------------------------------------------

class _SinglePhotoTile extends StatelessWidget {
  final File? file;
  final String label;
  final VoidCallback onPick;

  const _SinglePhotoTile(
      {required this.file, required this.label, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file != null ? AppColors.gold : AppColors.border,
            width: file != null ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: file != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(file!, fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined,
                        color: AppColors.gold, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      const Text('Tap to select photo',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Video picker tile
// ---------------------------------------------------------------------------

class _VideoPickerTile extends StatelessWidget {
  final File? file;
  final VideoPlayerController? controller;
  final VoidCallback onPick;

  const _VideoPickerTile(
      {required this.file, required this.controller, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file != null ? AppColors.gold : AppColors.border,
            width: file != null ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: file != null && controller != null && controller!.value.isInitialized
            ? Stack(
                fit: StackFit.expand,
                children: [
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller!.value.size.width,
                      height: controller!.value.size.height,
                      child: VideoPlayer(controller!),
                    ),
                  ),
                  // Play / pause overlay
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 32),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: const Text(
                        'Vehicle Video • Tap to change',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.videocam_outlined,
                        color: AppColors.gold, size: 28),
                  ),
                  const SizedBox(height: 10),
                  const Text('Vehicle Video',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Tap to select a video from gallery',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable text field
// ---------------------------------------------------------------------------

class _RcTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _RcTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.gold, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fuel type dropdown
// ---------------------------------------------------------------------------

class _FuelTypeDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FuelTypeDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((t) => DropdownMenuItem(
                value: t,
                child: Text(t,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
              ))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Please select fuel type' : null,
      dropdownColor: AppColors.surface,
      icon: const Icon(Icons.arrow_drop_down, color: AppColors.gold),
      decoration: InputDecoration(
        labelText: 'Fuel Type',
        labelStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: const Icon(Icons.local_gas_station_outlined,
            color: AppColors.gold, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Submit button
// ---------------------------------------------------------------------------

class _SubmitButton extends StatelessWidget {
  final bool uploading;
  final String statusText;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.uploading,
    required this.statusText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (statusText.isNotEmpty) ...[
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gold, fontSize: 13),
          ),
          const SizedBox(height: 10),
        ],
        GestureDetector(
          onTap: uploading ? null : onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 54,
            decoration: BoxDecoration(
              gradient: uploading
                  ? null
                  : const LinearGradient(
                      colors: [AppColors.gold, AppColors.goldLight],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              color: uploading ? AppColors.border : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: uploading
                  ? []
                  : [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Center(
              child: uploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.gold),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            color: AppColors.background, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Upload & Add Car',
                          style: TextStyle(
                            color: AppColors.background,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Upload overlay
// ---------------------------------------------------------------------------

class _UploadOverlay extends StatelessWidget {
  final String status;
  const _UploadOverlay({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.gold),
              const SizedBox(height: 20),
              const Text('Uploading…',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Decorative arc (same as dashboard)
// ---------------------------------------------------------------------------

class _Arc extends StatelessWidget {
  final bool flip;
  const _Arc({this.flip = false});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flip ? -1 : 1,
      scaleY: flip ? -1 : 1,
      child: CustomPaint(
        size: const Size(160, 160),
        painter: _ArcPainter(),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 0; i < 3; i++) {
      final o = i * 22.0;
      canvas.drawArc(
        Rect.fromLTWH(o, o, size.width * 1.2, size.height * 1.2),
        0,
        3.14 / 2,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
