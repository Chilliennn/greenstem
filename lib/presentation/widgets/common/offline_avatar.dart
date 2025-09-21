import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/services/image_upload_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/network_service.dart';

class OfflineAvatar extends ConsumerStatefulWidget {
  final User user;
  final double radius;
  final Widget? child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? defaultText;

  const OfflineAvatar({
    super.key,
    required this.user,
    this.radius = 20.0,
    this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.defaultText,
  });

  @override
  ConsumerState<OfflineAvatar> createState() => _OfflineAvatarState();
}

class _OfflineAvatarState extends ConsumerState<OfflineAvatar> {
  String? _imagePath;
  Timer? _versionCheckTimer;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _startVersionCheck();
  }

  @override
  void didUpdateWidget(OfflineAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.userId != widget.user.userId ||
        oldWidget.user.avatarVersion != widget.user.avatarVersion ||
        oldWidget.user.profilePath != widget.user.profilePath) {
      _loadImage();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _versionCheckTimer?.cancel();
    super.dispose();
  }

  void _startVersionCheck() {
    // Check for avatar updates every 2 minutes when online
    _versionCheckTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!_isDisposed && mounted) {
        _checkForAvatarUpdates();
      }
    });
  }

  Future<void> _checkForAvatarUpdates() async {
    if (_isDisposed || !mounted) return;

    try {
      // Only check if we have network connection
      if (!await NetworkService.hasConnection()) {
        return;
      }

      // Check if we have a remote URL to check against
      if (widget.user.profilePath == null || widget.user.profilePath!.isEmpty) {
        return;
      }

      // Try to get the latest avatar image (this will check remote version)
      final latestImagePath = await ImageUploadService.getAvatarImage(
        userId: widget.user.userId,
        avatarVersion: widget.user.avatarVersion,
        remoteUrl: widget.user.profilePath,
      );

      // If we got a different image path, update the UI
      if (mounted && latestImagePath != _imagePath) {
        setState(() {
          _imagePath = latestImagePath;
        });
        print('🔄 Avatar updated for user ${widget.user.userId}');
      }
    } catch (e) {
      print('❌ Error checking avatar updates: $e');
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    try {
      // Use ImageUploadService to get the best available image
      final imagePath = await ImageUploadService.getAvatarImage(
        userId: widget.user.userId,
        avatarVersion: widget.user.avatarVersion,
        remoteUrl: widget.user.profilePath,
      );

      if (mounted) {
        setState(() {
          _imagePath = imagePath;
        });
      }
    } catch (e) {
      print('❌ Failed to load avatar image: $e');
      if (mounted) {
        setState(() {
          _imagePath = null;
        });
      }
    }
  }

  ImageProvider? _getImageProvider() {
    if (_imagePath == null || _imagePath!.isEmpty) {
      return null;
    }

    // Check if it's a local file path
    if (_imagePath!.startsWith('/') || _imagePath!.startsWith('file://')) {
      final file = File(_imagePath!.replaceFirst('file://', ''));
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    // Check if it's a remote URL (should not happen with our caching strategy)
    if (_imagePath!.startsWith('http')) {
      return NetworkImage(_imagePath!);
    }

    return null;
  }

  Widget _buildDefaultChild() {
    if (widget.child != null) {
      return widget.child!;
    }

    // Use default text or user's first letter
    final text = widget.defaultText ??
        (widget.user.username?.isNotEmpty == true
            ? widget.user.username![0].toUpperCase()
            : '?');

    return Text(
      text,
      style: TextStyle(
        color: widget.foregroundColor ?? Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: widget.radius * 0.6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor ?? AppColors.clightgray,
      backgroundImage: _getImageProvider(),
      child: _getImageProvider() == null ? _buildDefaultChild() : null,
    );
  }
}
