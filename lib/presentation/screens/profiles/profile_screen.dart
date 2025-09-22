import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/error_message_helper.dart';
import '../../../domain/services/image_upload_service.dart';
import '../../../domain/entities/user.dart';
import '../../providers/auth_provider.dart';
import '../auth/sign_in_screen.dart';
import 'edit_profile_screen.dart';
import '../profiles/update_password_screen.dart';
import '../../widgets/common/offline_avatar.dart';
import '../../../core/services/network_sync_service.dart';
import '../../../domain/services/image_sync_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _hasPerformedInitialSync = false;

  @override
  void initState() {
    super.initState();
    // Perform sync check when entering profile screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performImageSyncCheck();
    });
  }

  Future<void> _performImageSyncCheck() async {
    if (_hasPerformedInitialSync) return;

    try {
      final user = ref.read(authProvider).user;
      if (user == null) return;

      print(
          '🔄 ProfileScreen: Performing image sync check for user ${user.userId}');

      // Check if user has local image changes that need sync
      if (user.profilePath != null &&
          user.profilePath!.startsWith('local://')) {
        print(
            '📱 ProfileScreen: User has local image changes, adding to sync queue');
        NetworkSyncService.addPendingSync(user.userId);
      }

      // Trigger immediate sync for this user
      await ImageSyncService.syncWithRetry(user.userId);

      _hasPerformedInitialSync = true;
      print('✅ ProfileScreen: Image sync check completed');
    } catch (e) {
      print('❌ ProfileScreen: Image sync check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userStream = ref.watch(userServiceProvider).watchCurrentUser();
    print('🔄 Profile Screen: Building with userStream');

    return StreamBuilder<User?>(
      stream: userStream,
      builder: (context, snapshot) {
        print(
            '🔄 Profile Screen StreamBuilder: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, hasError=${snapshot.hasError}');
        // Handle error state
        if (snapshot.hasError) {
          print('Profile Screen Stream Error: ${snapshot.error}');
          return Scaffold(
            backgroundColor: AppColors.cblack,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading profile: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Refresh
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.cblack,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyellow),
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          // If no user is logged in, redirect to sign in
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const SignInScreen()),
              (route) => false,
            );
          });
          return const Scaffold(
            backgroundColor: AppColors.cblack,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyellow),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.cblack,
          body: SafeArea(
            child: Column(
              children: [
                // Header with back button and title
                _buildHeader(context),

                // Profile section with avatar and user info
                _buildProfileSection(user),

                // Action cards
                Expanded(
                  child: _buildActionCards(context, user),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 24,
            ),
          ),
          const Spacer(),
          const Text(
            'My Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 24), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildProfileSection(User user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        children: [
          // Profile picture with camera icon
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: OfflineAvatar(
                  user: user,
                  radius: 58,
                  backgroundColor: AppColors.clightgray,
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showImagePicker(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.cblack,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // User name
          Text(
            user.fullName.isNotEmpty ? user.fullName : 'Unknown User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // User email
          Text(
            user.email ?? 'No email provided',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards(BuildContext context, User user) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Edit Profile
            _buildActionTile(
              context: context,
              icon: Icons.person_outline,
              title: 'Edit Profile',
              onTap: () => _navigateToEditProfile(context, user),
            ),

            const SizedBox(height: 16),

            // Update Password
            _buildActionTile(
              context: context,
              icon: Icons.lock_outline,
              title: 'Update Password',
              onTap: () => _navigateToUpdatePassword(context),
            ),

            const SizedBox(height: 16),

            // Logout
            _buildActionTile(
              context: context,
              icon: Icons.logout,
              title: 'Logout',
              iconColor: Colors.red,
              onTap: () => _showLogoutDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: iconColor ?? Colors.grey.shade800,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Change Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImagePickerOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                _buildImagePickerOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.cyellow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              color: AppColors.cyellow,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _pickImageFromCamera() async {
    try {
      final File? imageFile = await ImageUploadService.pickImage(
        source: ImageSource.camera,
      );

      if (imageFile != null) {
        await _handleImageSelection(imageFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                ErrorMessageHelper.getShortErrorMessage('Camera error: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _pickImageFromGallery() async {
    try {
      final File? imageFile = await ImageUploadService.pickImage(
        source: ImageSource.gallery,
      );

      if (imageFile != null) {
        await _handleImageSelection(imageFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                ErrorMessageHelper.getShortErrorMessage('Gallery error: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleImageSelection(File imageFile) async {
    try {
      final user = ref.read(authProvider).user;
      if (user == null) return;

      // Show loading dialog with upload states
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.cyellow),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Uploading image...',
                    style: TextStyle(
                      color: AppColors.cblack,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Use offline-first method
      final String imageUrl =
          await ImageUploadService.updateProfileImageOfflineFirst(
        imageFile: imageFile,
        userId: user.userId,
        currentAvatarVersion: user.avatarVersion,
      );

      // Update user profile with new image URL and incremented version
      final userService = ref.read(userServiceProvider);
      await userService.updateProfileImage(
        user.userId,
        imageUrl,
        user.avatarVersion + 1,
      );

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessageHelper.getShortErrorMessage(
                'Failed to update profile picture: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToEditProfile(BuildContext context, User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(user: user),
      ),
    );
  }

  void _navigateToUpdatePassword(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UpdatePasswordScreen(),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _logout(context);
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) {
    ref.read(authProvider.notifier).signOut();

    // Navigate to sign in screen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
      (route) => false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logged out successfully'),
        backgroundColor: AppColors.cyellow,
      ),
    );
  }
}
