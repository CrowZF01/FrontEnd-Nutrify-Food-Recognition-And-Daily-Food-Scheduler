import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../providers/schedule_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/meal_card.dart';
import '../widgets/schedule_tile.dart';

// Helper: format tanggal dalam Bahasa Indonesia tanpa locale plugin
String _formatTanggal(DateTime date) {
  const hariIndo = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  const bulanIndo = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  final hari = hariIndo[date.weekday - 1];
  final bulan = bulanIndo[date.month];
  return '$hari, ${date.day} $bulan ${date.year}';
}

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, prov, _) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Jadwal Makan', style: AppTextStyles.heading2),
                    TextButton.icon(
                      onPressed: () => prov.toggleView(),
                      icon: Icon(
                        prov.isWeeklyView ? Icons.today : Icons.date_range,
                        size: 18,
                      ),
                      label: Text(prov.isWeeklyView ? 'Harian' : 'Mingguan'),
                    ),
                  ],
                ),
              ),

              // Date selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => prov.setDate(
                        prov.selectedDate.subtract(const Duration(days: 1)),
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: prov.selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) prov.setDate(picked);
                      },
                      child: Text(
                        _formatTanggal(prov.selectedDate),
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => prov.setDate(
                        prov.selectedDate.add(const Duration(days: 1)),
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),

              // Meal sessions
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: AppConstants.mealSessions.map((sesi) {
                    final mealsForSession = prov.getMealsBySession(sesi);
                    final totalCal = mealsForSession.fold<double>(
                        0, (s, m) => s + m.totalKalori);
                    return MealCard(
                      title: AppConstants.mealSessionLabels[sesi]!,
                      emoji: AppConstants.mealSessionIcons[sesi]!,
                      itemCount: mealsForSession.length,
                      totalCalories: totalCal,
                      child: mealsForSession.isEmpty
                          ? null
                          : Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(8, 0, 8, 8),
                              child: Column(
                                children: mealsForSession
                                    .map((m) => ScheduleTile(
                                          meal: m,
                                          onDelete: () async {
                                            await prov.deleteMeal(m.id);
                                            if (context.mounted) {
                                              context.read<DashboardProvider>().refresh();
                                            }
                                          },
                                          onStatusChanged: (status) async {
                                            await prov.updateMealStatus(m.id, status);
                                            if (context.mounted) {
                                              context.read<DashboardProvider>().refresh();
                                            }
                                          },
                                        ))
                                    .toList(),
                              ),
                            ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
