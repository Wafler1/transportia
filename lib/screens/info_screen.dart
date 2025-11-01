import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'About Entaria',
              onBackButtonPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App logo and name
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.accentOf(context).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              LucideIcons.trainFront,
                              size: 40,
                              color: AppColors.accentOf(context),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Entaria',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Version 1.0.0',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0x66000000),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Purpose section
                    _buildSectionTitle('Our Purpose'),
                    const SizedBox(height: 12),
                    _buildCard(
                      child: const Text(
                        'Entaria is a modern travel companion designed to make public transportation easier and more accessible. We believe that getting around should be simple, efficient, and stress-free. Our app provides real-time transit information, journey planning, and interactive maps to help you navigate your city with confidence.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: AppColors.black,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Creators section
                    _buildSectionTitle('Created By'),
                    const SizedBox(height: 12),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFC970A).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  LucideIcons.sparkles,
                                  size: 24,
                                  color: Color(0xFFFC970A),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Wafler.one',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFFC970A),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Digital Innovation Studio',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0x66000000),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Wafler.one is a creative digital studio focused on building innovative solutions that make everyday life easier. We combine thoughtful design with powerful technology to create apps that people love to use.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Open Source Credits section
                    _buildSectionTitle('Open Source Credits'),
                    const SizedBox(height: 12),
                    const Text(
                      'Entaria is built with the help of amazing open-source projects and APIs:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0x80000000),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCreditItem(
                      context,
                      'Flutter',
                      'UI framework by Google',
                      LucideIcons.smartphone,
                    ),
                    _buildCreditItem(
                      context,
                      'Transitous',
                      'Public transit routing service',
                      LucideIcons.route,
                    ),
                    _buildCreditItem(
                      context,
                      'MapLibre GL',
                      'Open-source mapping platform',
                      LucideIcons.map,
                    ),
                    _buildCreditItem(
                      context,
                      'Lucide Icons',
                      'Beautiful open-source icons',
                      LucideIcons.palette,
                    ),
                    _buildCreditItem(
                      context,
                      'OpenStreetMap',
                      'Collaborative mapping data',
                      LucideIcons.mapPin,
                    ),
                    _buildCreditItem(
                      context,
                      'Timelines Plus',
                      'Timeline UI components',
                      LucideIcons.clock,
                    ),

                    const SizedBox(height: 24),

                    // Thank you section
                    _buildCard(
                      child: Column(
                        children: [
                          Icon(
                            LucideIcons.heart,
                            size: 32,
                            color: AppColors.accentOf(context).withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Thank You',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Special thanks to all the contributors and maintainers of these open-source projects. Without them, Entaria wouldn\'t be possible.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Color(0x80000000),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.black,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x05000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0A000000)),
      ),
      child: child,
    );
  }

  Widget _buildCreditItem(BuildContext context, String name, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x05000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0A000000)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentOf(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppColors.accentOf(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0x66000000),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
