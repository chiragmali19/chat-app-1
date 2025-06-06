import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/services/storage_service.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/common/gradient_background.dart';
import '../widgets/common/loading_heart.dart';
import 'auth_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final TextEditingController _nameController = TextEditingController();
  bool _isEditing = false;
  bool _isUploading = false;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _showOnlineStatus = true;
  bool _showLastSeen = true;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfileImage() async {
    try {
      setState(() => _isUploading = true);
      
      // Show image source selection
      final source = await _showImageSourceDialog();
      if (source == null) {
        setState(() => _isUploading = false);
        return;
      }

      XFile? imageFile;
      if (source == ImageSource.camera) {
        imageFile = await StorageService.instance.pickImageFromCamera();
      } else {
        imageFile = await StorageService.instance.pickImageFromGallery();
      }

      if (imageFile == null) {
        setState(() => _isUploading = false);
        return;
      }

      final imageUrl = await StorageService.instance.uploadProfileImage(
        imageFile: imageFile,
        onProgress: (progress) {
          // You can show progress here if needed
        },
      );

      if (imageUrl != null) {
        await ref.read(authControllerProvider.notifier).updateProfile(
          photoURL: imageUrl,
        );
        
        _showSuccessMessage(AppStrings.profileUpdated);
      } else {
        _showErrorMessage(AppStrings.errorUploadImage);
      }
    } catch (e) {
      _showErrorMessage('Error updating profile: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'Update Profile Photo',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: _ImageSourceTile(
                    icon: Icons.camera_alt,
                    label: AppStrings.camera,
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ImageSourceTile(
                    icon: Icons.photo_library,
                    label: AppStrings.gallery,
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _updateDisplayName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
        displayName: newName,
      );
      
      setState(() => _isEditing = false);
      _showSuccessMessage(AppStrings.profileUpdated);
    } catch (e) {
      _showErrorMessage('Failed to update name: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.online,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryRose.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.logout,
                color: AppColors.primaryDeepRose,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Sign Out'),
          ],
        ),
        content: const Text(AppStrings.confirmSignOut),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDeepRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(AppStrings.signOut),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_forever,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Delete Account'),
          ],
        ),
        content: const Text(AppStrings.confirmDeleteAccount),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authControllerProvider.notifier).signOut();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showErrorMessage('Failed to sign out: $e');
    }
  }

  Future<void> _deleteAccount() async {
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showErrorMessage('Failed to delete account: $e');
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.heartGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('About OnlyUs'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.appDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.version,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.copyright,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(AppStrings.profile),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 20),
              ),
              onPressed: () {
                setState(() => _isEditing = true);
                if (authState is AuthSuccess) {
                  _nameController.text = authState.user.displayName;
                }
              },
            ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: currentUser.when(
                data: (user) => user != null
                    ? _buildProfileContent(user)
                    : const Center(child: Text('User not found')),
                loading: () => const Center(child: LoadingHeart(showText: true, text: 'Loading profile...')),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading profile',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          
          // Profile Avatar Section
          _buildProfileAvatar(user),
          
          const SizedBox(height: 32),
          
          // Name/Edit Section
          _buildNameSection(user),
          
          const SizedBox(height: 32),
          
          // User Info Card
          _buildUserInfoCard(user),
          
          const SizedBox(height: 24),
          
          // Settings Section
          _buildSettingsSection(),
          
          const SizedBox(height: 24),
          
          // Privacy Settings
          _buildPrivacySettings(),
          
          const SizedBox(height: 32),
          
          // Action Buttons
          _buildActionButtons(),
          
          const SizedBox(height: 24),
          
          // App Info
          _buildAppInfo(),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(user) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primaryDeepRose.withOpacity(0.3),
                AppColors.primaryDeepRose.withOpacity(0.0),
              ],
            ),
          ),
        ),
        
        // Avatar container
        GestureDetector(
          onTap: _updateProfileImage,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.heartGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDeepRose.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: _isUploading
                ? const LoadingHeart(size: 50)
                : ClipOval(
                    child: user.photoURL != null
                        ? Image.network(
                            user.photoURL!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultAvatar(user);
                            },
                          )
                        : _buildDefaultAvatar(user),
                  ),
          ),
        ),
        
        // Edit button
        if (!_isUploading)
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDeepRose.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultAvatar(user) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heartGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          user.initials,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildNameSection(user) {
    if (_isEditing) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primaryRose.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeepRose.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppStrings.displayName,
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _isEditing = false);
                      _nameController.clear();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppColors.textLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(AppStrings.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updateDisplayName,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDeepRose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(AppStrings.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return Column(
        children: [
          Text(
            user.displayName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: user.isOnline 
                  ? LinearGradient(colors: [AppColors.online, AppColors.online.withOpacity(0.8)])
                  : LinearGradient(colors: [AppColors.offline, AppColors.offline.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (user.isOnline ? AppColors.online : AppColors.offline).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  user.isOnline ? AppStrings.online : user.lastSeenText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildUserInfoCard(user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryRose.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeepRose.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        children: [
          _ProfileInfoRow(
            icon: Icons.email,
            label: AppStrings.email,
            value: user.email,
          ),
          const Divider(height: 32),
          _ProfileInfoRow(
            icon: Icons.calendar_today,
            label: AppStrings.joinedOn,
            value: _formatDate(user.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryRose.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.notifications,
            title: AppStrings.notificationSettings,
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) => setState(() => _notificationsEnabled = value),
              activeColor: AppColors.primaryDeepRose,
            ),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.volume_up,
            title: AppStrings.soundEnabled,
            trailing: Switch(
              value: _soundEnabled,
              onChanged: (value) => setState(() => _soundEnabled = value),
              activeColor: AppColors.primaryDeepRose,
            ),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.vibration,
            title: AppStrings.vibrationEnabled,
            trailing: Switch(
              value: _vibrationEnabled,
              onChanged: (value) => setState(() => _vibrationEnabled = value),
              activeColor: AppColors.primaryDeepRose,
            ),
            onTap: null,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettings() {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppColors.primaryRose.withOpacity(0.3),
      ),
    ),
    child: Column(
      children: [
        _SettingsTile(
          icon: Icons.visibility,
          title: AppStrings.onlineStatus,
          trailing: Switch(
            value: _showOnlineStatus,
            onChanged: _updateOnlineStatusVisibility, // Updated callback
            activeColor: AppColors.primaryDeepRose,
          ),
          onTap: null,
        ),
        _SettingsTile(
          icon: Icons.access_time,
          title: AppStrings.lastSeenStatus,
          trailing: Switch(
            value: _showLastSeen,
            onChanged: _updateLastSeenVisibility, // Updated callback
            activeColor: AppColors.primaryDeepRose,
          ),
          onTap: null,
        ),
        _SettingsTile(
          icon: Icons.help,
          title: AppStrings.support,
          onTap: () {
            _showSupportDialog();
          },
        ),
        _SettingsTile(
          icon: Icons.info,
          title: AppStrings.about,
          onTap: _showAboutDialog,
          showDivider: false,
        ),
      ],
    ),
  );
}

Future<void> _updateOnlineStatusVisibility(bool showOnlineStatus) async {
  try {
    // Update local preference
    setState(() => _showOnlineStatus = showOnlineStatus);
    
    // Update user's privacy settings in Firestore
    await ref.read(authControllerProvider.notifier).updateUserPrivacySettings(
      showOnlineStatus: showOnlineStatus,
    );
    
    _showSuccessMessage('Online status visibility updated');
  } catch (e) {
    // Revert local change on error
    setState(() => _showOnlineStatus = !showOnlineStatus);
    _showErrorMessage('Failed to update online status: $e');
  }
}

Future<void> _updateLastSeenVisibility(bool showLastSeen) async {
  try {
    // Update local preference
    setState(() => _showLastSeen = showLastSeen);
    
    // Update user's privacy settings in Firestore
    await ref.read(authControllerProvider.notifier).updateUserPrivacySettings(
      showLastSeen: showLastSeen,
    );
    
    _showSuccessMessage('Last seen visibility updated');
  } catch (e) {
    // Revert local change on error
    setState(() => _showLastSeen = !showLastSeen);
    _showErrorMessage('Failed to update last seen: $e');
  }
}

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondaryDeepPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.help,
                color: AppColors.secondaryDeepPurple,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Need help? We\'re here for you!'),
            const SizedBox(height: 16),
            const Text('Contact us:'),
            const SizedBox(height: 8),
            Text(
              '• Email: support@onlyus.app\n• Website: www.onlyus.app\n• Version: ${AppStrings.version}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.ok),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout),
            label: const Text(AppStrings.signOut),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.primaryDeepRose),
              foregroundColor: AppColors.primaryDeepRose,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _confirmDeleteAccount,
            icon: const Icon(Icons.delete_forever),
            label: const Text(AppStrings.deleteAccount),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
              foregroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
        
          Text(
            AppStrings.version,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.copyright,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textLight.withOpacity(0.7),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeepRose.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryRose.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.primaryDeepRose,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textLight,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showDivider;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryRose.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryDeepRose,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.primaryRose.withOpacity(0.2),
          ),
      ],
    );
  }
}