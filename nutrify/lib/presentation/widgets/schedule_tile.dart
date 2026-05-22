import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/meal_schedule.dart';

class ScheduleTile extends StatelessWidget {
  final MealSchedule meal;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final ValueChanged<String>? onStatusChanged;

  const ScheduleTile({
    super.key,
    required this.meal,
    this.onDelete,
    this.onTap,
    this.onStatusChanged,
  });

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.surface,
          content: Text(
            'Makanan ini dihapus?',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'Tidak',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onDelete?.call();
                    },
                    child: Text(
                      'Ya',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final emoji = AppConstants.mealSessionIcons[meal.sesi] ?? '🍽️';
    final isCanceled = meal.status == 'canceled';
    final isEaten = meal.status == 'eaten';

    return Dismissible(
      key: Key(meal.id),
      direction: isEaten ? DismissDirection.none : DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onStatusChanged?.call('eaten');
          return false;
        } else if (direction == DismissDirection.endToStart) {
          onDelete?.call();
          return true;
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: () {
          if (isEaten) {
            _showDeleteConfirmationDialog(context);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isEaten
                ? AppColors.success.withValues(alpha: 0.1)
                : (isCanceled ? AppColors.surfaceVariant.withValues(alpha: 0.3) : AppColors.surface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isEaten ? AppColors.success.withValues(alpha: 0.3) : AppColors.divider,
            ),
          ),
          child: Row(
            children: [
              // Emoji
              Opacity(
                opacity: isCanceled ? 0.5 : 1.0,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.namaMenu,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: isCanceled ? AppColors.textLight.withValues(alpha: 0.6) : AppColors.textPrimary,
                        decoration: isCanceled ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meal.items.map((i) => '${i.ingredientNama} ${i.beratGram.toStringAsFixed(0)}g').join(', '),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isCanceled ? AppColors.textLight.withValues(alpha: 0.4) : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Calories
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    meal.totalKalori.toStringAsFixed(0),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isCanceled ? AppColors.textLight.withValues(alpha: 0.5) : AppColors.calories,
                      decoration: isCanceled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    'kkal',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isCanceled ? AppColors.textLight.withValues(alpha: 0.5) : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
