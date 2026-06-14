import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/config/supabase_client.dart' show logger;
import '../../../core/theme/app_colors.dart';

class ProjectSitePhotosScreen extends StatefulWidget {
  final String projectId;

  const ProjectSitePhotosScreen({super.key, required this.projectId});

  @override
  State<ProjectSitePhotosScreen> createState() =>
      _ProjectSitePhotosScreenState();
}

class _ProjectSitePhotosScreenState extends State<ProjectSitePhotosScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  bool _uploading = false;
  List<_PhotoItem> _photos = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final files = await _client.storage
          .from(AppConstants.bucketProjectImages)
          .list(path: widget.projectId);

      final photos = files
          .where((f) => _isImageFile(f.name))
          .map((f) {
            final path = '${widget.projectId}/${f.name}';
            final url = _client.storage
                .from(AppConstants.bucketProjectImages)
                .getPublicUrl(path);
            return _PhotoItem(
              name: f.name,
              path: path,
              url: url,
              updatedAt: f.updatedAt != null
                  ? DateTime.tryParse(f.updatedAt!)
                  : null,
            );
          })
          .toList()
        ..sort((a, b) => (b.updatedAt ?? DateTime(0))
            .compareTo(a.updatedAt ?? DateTime(0)));

      if (mounted) {
        setState(() {
          _photos = photos;
          _loading = false;
        });
      }
    } catch (e) {
      logger.e('Failed to load site photos: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load photos: $e';
          _loading = false;
        });
      }
    }
  }

  bool _isImageFile(String name) {
    final ext = name.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'].contains(ext);
  }

  Future<void> _uploadPhoto() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromSource(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_outlined, color: AppColors.primary),
              title: const Text('Browse Files'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromFiles();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromSource(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      await _uploadBytes(
        bytes: bytes,
        name: picked.name,
        mime: ext == 'png' ? 'image/png' : 'image/jpeg',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not capture photo: $e')),
        );
      }
    }
  }

  Future<void> _pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);
    int uploaded = 0;
    int failed = 0;

    for (final file in result.files) {
      if (file.bytes == null) continue;
      try {
        await _uploadBytes(
          bytes: Uint8List.fromList(file.bytes!),
          name: file.name,
          mime: _mimeForFile(file.name),
          incrementCounter: false,
        );
        uploaded++;
      } catch (e) {
        logger.w('Failed to upload ${file.name}: $e');
        failed++;
      }
    }

    if (mounted) {
      setState(() => _uploading = false);
      await _loadPhotos();
      if (!mounted) return;
      final msg = failed == 0
          ? '$uploaded photo${uploaded > 1 ? 's' : ''} uploaded'
          : '$uploaded uploaded, $failed failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _uploadBytes({
    required Uint8List bytes,
    required String name,
    required String mime,
    bool incrementCounter = true,
  }) async {
    if (incrementCounter) setState(() => _uploading = true);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '${widget.projectId}/${timestamp}_$sanitized';

      await _client.storage
          .from(AppConstants.bucketProjectImages)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: mime),
          );

      if (incrementCounter && mounted) {
        setState(() => _uploading = false);
        await _loadPhotos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo uploaded')),
          );
        }
      }
    } catch (e) {
      if (incrementCounter && mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
      rethrow;
    }
  }

  String _mimeForFile(String name) {
    final ext = name.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _deletePhoto(_PhotoItem photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: const Text('This photo will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _client.storage
          .from(AppConstants.bucketProjectImages)
          .remove([photo.path]);
      await _loadPhotos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Site Photos'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadPhotos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _uploadPhoto,
        backgroundColor: AppColors.primary,
        icon: _uploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add_a_photo_outlined, color: Colors.white),
        label: Text(
          _uploading ? 'Uploading...' : 'Upload Photo',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_outlined,
                            size: 48, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadPhotos,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _photos.isEmpty
                  ? _EmptyState(onUpload: _uploadPhoto)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      child: GridView.builder(
                        itemCount: _photos.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemBuilder: (context, index) {
                          final photo = _photos[index];
                          return _PhotoTile(
                            photo: photo,
                            onTap: () => _openFullscreen(photo),
                            onDelete: () => _deletePhoto(photo),
                          );
                        },
                      ),
                    ),
    );
  }

  void _openFullscreen(_PhotoItem photo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenPhoto(photo: photo),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.add_a_photo_outlined,
              size: 34,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No site photos yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload photos to document progress\nand keep your team informed.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Upload First Photo'),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final _PhotoItem photo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PhotoTile({
    required this.photo,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Image.network(
              photo.url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(
                      color: AppColors.surfaceVariant,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
              errorBuilder: (_, e, st) => Container(
                color: AppColors.surfaceVariant,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AppColors.textHint),
                ),
              ),
            ),
          ),
          // Gradient overlay + delete button
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            child: Container(
              height: 48,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0x88000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenPhoto extends StatelessWidget {
  final _PhotoItem photo;
  const _FullscreenPhoto({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          photo.name,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            photo.url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (_, e, st) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined,
                      size: 48, color: Colors.white54),
                  SizedBox(height: 8),
                  Text('Failed to load image',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoItem {
  final String name;
  final String path;
  final String url;
  final DateTime? updatedAt;

  const _PhotoItem({
    required this.name,
    required this.path,
    required this.url,
    this.updatedAt,
  });
}
