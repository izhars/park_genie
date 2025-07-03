import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'DatabaseHelper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? user;
  bool isLoading = true;
  bool isEditing = false;
  File? _logoImage;
  String? _savedLogoPath;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController companyController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController footerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUserDetails();
  }

// Add this method to pick images
  Future<void> _pickLogo() async {
    final ImagePicker picker = ImagePicker();

    // Show a dialog to explain acceptable formats
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Logo Image'),
        content: const Text(
            'Please select a PNG, JPEG, or GIF image file.\n\n'
                'For best thermal printing results, use a simple logo with high contrast.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300,
      maxHeight: 300,
    );

    if (image != null) {
      // Validate file extension
      final extension = path.extension(image.path).toLowerCase();
      if (!['.png', '.jpg', '.jpeg', '.gif'].contains(extension)) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid file format. Please select PNG, JPEG, or GIF image.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Process the valid image
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'company_logo_${DateTime.now().millisecondsSinceEpoch}$extension';
      final savedImage = File('${appDir.path}/$fileName');

      await File(image.path).copy(savedImage.path);

      setState(() {
        _logoImage = savedImage;
        _savedLogoPath = savedImage.path;
      });
    }
  }

// Update fetchUserDetails to also get logo path
  Future<void> fetchUserDetails() async {
    try {
      setState(() => isLoading = true);

      final userData = await DatabaseHelper.instance.getUser();

      if (!mounted) return;

      setState(() {
        user = userData;
        isLoading = false;

        if (userData != null) {
          nameController.text = userData['name'] ?? '';
          companyController.text = userData['companyName'] ?? '';
          addressController.text = userData['address'] ?? '';
          footerController.text = userData['footerText'] ?? '';
          _savedLogoPath = userData['logoPath'];

          // Set logo file if path exists
          if (_savedLogoPath != null && _savedLogoPath!.isNotEmpty) {
            _logoImage = File(_savedLogoPath!);
          }
        }
      });
    } catch (e) {
      // Error handling
      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

// Update saveUserData to include logo path
  Future<void> saveUserData() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);

      try {
        await DatabaseHelper.instance.saveUser(
          nameController.text,
          companyController.text,
          addressController.text,
          logoPath: _savedLogoPath,
          footerText: footerController.text,
        );

        // Get updated user data
        final userData = await DatabaseHelper.instance.getUser();

        if (!mounted) return;

        setState(() {
          user = userData;
          isLoading = false;
          isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        debugPrint('❌ Error: $e');

        if (!mounted) return;

        setState(() => isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    companyController.dispose();
    addressController.dispose();
    footerController.dispose();
    super.dispose();
  }

  Future<void> deleteUserData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete your profile data? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                setState(() => isLoading = true);
                await DatabaseHelper.instance.deleteUser();
                await fetchUserDetails();
              } catch (e) {
                if (!mounted) return;
                setState(() => isLoading = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting profile: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Custom footer widget using saved footer text
  Widget _buildCustomFooter() {
    final footerText = user?['footerText'] ?? '';

    // If no footer text is saved, don't show footer
    if (footerText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue.shade600,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            footerText,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'No Profile Data',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your profile to get started',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Profile'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  onPressed: () => setState(() => isEditing = true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileView() {
    // Guard against null values
    final String name = user?['name'] ?? 'Name not available';
    final String company = user?['companyName'] ?? 'Company not available';
    final String address = user?['address'] ?? 'Address not available';

    // Get first letter for avatar or use default
    final String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with avatar
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          firstLetter,
                          style: TextStyle(fontSize: 40, color: Colors.blue.shade700),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        company,
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Profile details card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile Details',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Details list
                        _buildDetailItem(Icons.person, 'Name', name),
                        _buildDetailItem(Icons.business, 'Company', company),
                        _buildDetailItem(Icons.location_on, 'Address', address),

                        // Show footer text if available
                        if (user?['footerText'] != null && user!['footerText'].toString().isNotEmpty)
                          _buildDetailItem(Icons.text_snippet, 'Footer Text', user!['footerText']),
                      ],
                    ),
                  ),
                ),

                // Action buttons
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Profile'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => setState(() => isEditing = true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: deleteUserData,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue.shade700, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      user == null ? 'Create Profile' : 'Edit Profile',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Company Logo
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickLogo,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: _logoImage != null
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _logoImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 40, color: Colors.blue.shade300),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Logo',
                                  style: TextStyle(color: Colors.blue.shade400),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to add your company logo',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name field
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your full name',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Company field
                  TextFormField(
                    controller: companyController,
                    decoration: InputDecoration(
                      labelText: 'Company',
                      hintText: 'Enter your company name',
                      prefixIcon: const Icon(Icons.business),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your company name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Address field
                  TextFormField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      hintText: 'Enter your address',
                      prefixIcon: const Icon(Icons.location_on),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  // Footer Text field
                  TextFormField(
                    controller: footerController,
                    decoration: InputDecoration(
                      labelText: 'Footer Text',
                      hintText: 'Enter footer text (e.g., company details, thank you message)',
                      prefixIcon: const Icon(Icons.text_snippet),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      helperText: 'This text will appear at the bottom of screens throughout the app',
                      helperMaxLines: 2,
                    ),
                    maxLines: 3,
                    maxLength: 200,
                  ),
                  const SizedBox(height: 32),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Save Profile'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            debugPrint('🔘 Save button pressed');
                            saveUserData();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            // If creating new profile, stay on empty state
                            // If editing existing profile, return to view mode
                            setState(() {
                              isEditing = false;
                              if (user != null) {
                                nameController.text = user!['name'] ?? '';
                                companyController.text = user!['companyName'] ?? '';
                                addressController.text = user!['address'] ?? '';
                                footerController.text = user!['footerText'] ?? '';
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(
              top: BorderSide(color: Colors.blue.shade200, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.blue.shade600,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tip: The footer text will be displayed at the bottom of app screens for company branding',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading profile data...'),
            ],
          ),
        )
            : isEditing
            ? _buildEditForm()
            : user == null
            ? _buildEmptyState()
            : _buildProfileView(),
      ),
    );
  }
}