import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../providers/user_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/schedule_provider.dart';
import '../widgets/nutrition_card.dart';
import '../widgets/macro_bar.dart';
import '../widgets/schedule_tile.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, DashboardProvider>(
      builder: (context, userProv, dashProv, _) {
        final name = userProv.profile?.nama ?? 'Pengguna';
        final greeting = _getGreeting();

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => dashProv.refresh(),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  Text(greeting, style: AppTextStyles.bodySmall),
                  Text(name, style: AppTextStyles.heading2),
                  const SizedBox(height: 20),

                  // Nutrition card
                  NutritionCard(
                    currentCalories: dashProv.kaloriHariIni,
                    targetCalories: userProv.targetKalori,
                    protein: dashProv.proteinHariIni,
                    fat: dashProv.lemakHariIni,
                    carbs: dashProv.karboHariIni,
                  ),
                  const SizedBox(height: 20),

                  // Macro bars
                  Text('Detail Makro', style: AppTextStyles.heading3),
                  const SizedBox(height: 10),
                  MacroBar(
                    label: 'Protein',
                    current: dashProv.proteinHariIni,
                    target: userProv.targetProtein,
                    color: AppColors.protein,
                  ),
                  const SizedBox(height: 8),
                  MacroBar(
                    label: 'Lemak',
                    current: dashProv.lemakHariIni,
                    target: userProv.targetLemak,
                    color: AppColors.fat,
                  ),
                  const SizedBox(height: 8),
                  MacroBar(
                    label: 'Karbohidrat',
                    current: dashProv.karboHariIni,
                    target: userProv.targetKarbo,
                    color: AppColors.carbs,
                  ),
                  const SizedBox(height: 24),

                  // Today's meals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Makanan Hari Ini', style: AppTextStyles.heading3),
                      Text(
                        '${dashProv.todayMeals.length} menu',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (dashProv.todayMeals.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.restaurant_outlined,
                              size: 48, color: AppColors.textLight),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada makanan hari ini',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tambahkan lewat Jadwal atau Chat AI',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ...dashProv.todayMeals.map((meal) => ScheduleTile(
                        meal: meal,
                        onStatusChanged: (status) async {
                          await context.read<ScheduleProvider>().updateMealStatus(meal.id, status);
                          dashProv.refresh();
                        },
                        onDelete: () async {
                          await context.read<ScheduleProvider>().deleteMeal(meal.id);
                          dashProv.refresh();
                        },
                      )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi 🌅';
    if (hour < 15) return 'Selamat Siang ☀️';
    if (hour < 18) return 'Selamat Sore 🌇';
    return 'Selamat Malam 🌙';
  }
}
