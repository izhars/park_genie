import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Us'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header section with gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo, Color(0xFF3949AB)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 30, 16, 50),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/icons/park_car2.png',
                      width: 80,
                      height: 80,
                      color: Colors.white, // Optional: applies a white tint to the image
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Park Genie',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Smart Parking Solutions',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Content sections
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    icon: Icons.rocket_launch,
                    title: 'Our Mission',
                    content: 'At Park Genie, our mission is to simplify parking through technology. '
                        'We provide a smart, efficient, and secure parking management system that helps both employees and management streamline their daily operations.',
                  ),

                  _buildFeaturesList(),

                  _buildSection(
                    icon: Icons.thumb_up,
                    title: 'Why Choose Us?',
                    content: 'Park Genie is designed with simplicity and power in mind. Whether you manage a small lot or a large parking facility, our system adapts to your needs with robust features, reliability, and user-friendly design.',
                  ),

                  _buildContactInfo(),

                  const SizedBox(height: 40),

                  Center(
                    child: Column(
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            // Implement action to contact
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.indigo,
                            side: const BorderSide(color: Colors.indigo),
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text('Contact Us Now', style: TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          '© 2025 Park Genie. All rights reserved.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.indigo, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      {'icon': Icons.access_time, 'title': 'Real-time Tracking', 'desc': 'Vehicle entry & exit tracking in real-time'},
      {'icon': Icons.security, 'title': 'Smart Gate Control', 'desc': 'Automated gate control and space allocation'},
      {'icon': Icons.analytics, 'title': 'Analytics', 'desc': 'Comprehensive revenue and vehicle analytics'},
      {'icon': Icons.login, 'title': 'Secure Login', 'desc': 'Role-based authentication for employees'},
      {'icon': Icons.print, 'title': 'Printer Integration', 'desc': 'Works with Bluetooth, USB, and Wi-Fi printers'},
      {'icon': Icons.camera_alt, 'title': 'Number Plate Recognition', 'desc': 'Camera-based recognition'},
    ];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Colors.indigo, size: 24),
                SizedBox(width: 12),
                Text(
                  'What We Offer',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: features.length,
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(features[index]['icon'] as IconData, color: Colors.indigo, size: 30),
                      const SizedBox(height: 12),
                      Text(
                        features[index]['title'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        features[index]['desc'] as String,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfo() {
    final contacts = [
      {'icon': Icons.email, 'title': 'Email', 'value': 'support@parkgenie.com'},
      {'icon': Icons.phone, 'title': 'Phone', 'value': '+91-8010080256'},
      {'icon': Icons.language, 'title': 'Website', 'value': 'www.parkgenie.com'},
    ];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.contact_phone, color: Colors.indigo, size: 24),
                SizedBox(width: 12),
                Text(
                  'Contact Us',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: contacts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(contacts[index]['icon'] as IconData, color: Colors.indigo),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contacts[index]['title'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black45,
                            ),
                          ),
                          Text(
                            contacts[index]['value'] as String,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}