import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/meal_schedule.dart';
import '../providers/chat_provider.dart';
import '../providers/user_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/ingredient_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/ai_button_group.dart';
import '../widgets/recommendation_card.dart';

class ChatDetailScreen extends StatefulWidget {
  final String sessionId;
  const ChatDetailScreen({super.key, required this.sessionId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().selectSession(widget.sessionId);
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    final chatProv = context.read<ChatProvider>();
    if (chatProv.isLoading) return; // ← Guard UI: jangan kirim saat masih loading

    final userProv = context.read<UserProvider>();
    final ingredientProv = context.read<IngredientProvider>();
    final avoidedIngs = ingredientProv.avoidedIngredients;

    String userContext = userProv.profile?.toAiContext() ?? '';
    if (avoidedIngs.isNotEmpty) {
      final names = avoidedIngs.map((i) => i.nama).join(', ');
      userContext += '\nBahan makanan yang dihindari (pantangan tambahan): $names. Tolong jangan rekomendasikan menu yang mengandung bahan-bahan ini.';
    }

    chatProv.sendMessage(
      text.trim(),
      userContext: userContext,
    );
    _msgController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat NutriFy AI', style: AppTextStyles.heading3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProv, _) {
          _scrollToBottom();
          return Column(
            children: [
              // Messages
              Expanded(
                child: chatProv.messages.isEmpty
                    ? _buildEmptyChat()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: chatProv.messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = chatProv.messages[i];
                          final isUser = msg.role == 'user';
                          final time = DateFormat('HH:mm').format(msg.timestamp);

                          if (isUser) {
                            return ChatBubble(
                              message: msg.content,
                              isUser: true,
                              time: time,
                            );
                          }

                          // AI message - parse for special content
                          final cleanText = chatProv.getCleanText(msg.content);
                          final buttons = chatProv.getButtons(msg.content);
                          final rekomendasi = chatProv.getRekomendasi(msg.content);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (cleanText.isNotEmpty)
                                ChatBubble(
                                  message: cleanText,
                                  isUser: false,
                                  time: time,
                                ),
                              if (buttons.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: AiButtonGroup(
                                    buttons: buttons,
                                    onPressed: (btn) => _sendMessage(btn),
                                  ),
                                ),
                              ...rekomendasi.map((r) => Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: RecommendationCard(
                                      recommendation: r,
                                      onAddToSchedule: () async {
                                        final success = await context
                                            .read<ScheduleProvider>()
                                            .addMealFromRecommendation(
                                              namaMenu: r.namaMenu,
                                              ingredients: r.ingredients,
                                              sesiMakan: r.sesiMakan,
                                            );
                                        if (!success) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                    '⚠️ Batas kalori atau makro harian terlampaui. Makanan tidak dapat ditambahkan!'),
                                                backgroundColor: AppColors.error,
                                                behavior: SnackBarBehavior.floating,
                                                margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            );
                                          }
                                          return;
                                        }
                                        if (context.mounted) {
                                          await context.read<IngredientProvider>().loadIngredients();
                                        }
                                        if (context.mounted) {
                                          context.read<DashboardProvider>().refresh();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '✅ ${r.namaMenu} ditambahkan ke ${r.sesiMakan}!'),
                                              backgroundColor: AppColors.success,
                                              behavior: SnackBarBehavior.floating,
                                              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      onReplaceSchedule: () async {
                                        final scheduleProv = context.read<ScheduleProvider>();
                                        final existingMeals = scheduleProv.getTodayMealsForSession(r.sesiMakan);

                                        bool success = false;
                                        if (existingMeals.isEmpty) {
                                          success = await scheduleProv.addMealFromRecommendation(
                                            namaMenu: r.namaMenu,
                                            ingredients: r.ingredients,
                                            sesiMakan: r.sesiMakan,
                                          );
                                        } else if (existingMeals.length == 1) {
                                          success = await scheduleProv.replaceSpecificMealFromRecommendation(
                                            targetMealId: existingMeals.first.id,
                                            newNamaMenu: r.namaMenu,
                                            ingredients: r.ingredients,
                                            sesiMakan: r.sesiMakan,
                                          );
                                        } else {
                                          final selectedMeal = await _showChoiceDialog(context, existingMeals, r.sesiMakan);
                                          if (selectedMeal == null) {
                                            return false;
                                          }
                                          success = await scheduleProv.replaceSpecificMealFromRecommendation(
                                            targetMealId: selectedMeal.id,
                                            newNamaMenu: r.namaMenu,
                                            ingredients: r.ingredients,
                                            sesiMakan: r.sesiMakan,
                                          );
                                        }

                                        if (!success) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                    '⚠️ Batas kalori atau makro harian terlampaui. Makanan tidak dapat ditambahkan!'),
                                                backgroundColor: AppColors.error,
                                                behavior: SnackBarBehavior.floating,
                                                margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            );
                                          }
                                          return false;
                                        }

                                        if (context.mounted) {
                                          await context.read<IngredientProvider>().loadIngredients();
                                        }
                                        if (context.mounted) {
                                          context.read<DashboardProvider>().refresh();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '🔄 Menu ${r.sesiMakan} diganti dengan ${r.namaMenu}!'),
                                              backgroundColor: AppColors.primary,
                                              behavior: SnackBarBehavior.floating,
                                              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          );
                                        }
                                        return true;
                                      },
                                    ),
                                  )),
                            ],
                          );
                        },
                      ),
              ),

              // Loading indicator
              if (chatProv.isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.aiBubble,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('AI sedang mengetik...',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),

              // Input bar
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          enabled: !chatProv.isLoading,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _sendMessage,
                          decoration: InputDecoration(
                            hintText: chatProv.isLoading
                                ? 'AI sedang memproses...'
                                : 'Tulis pesan...',
                            filled: true,
                            fillColor: AppColors.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          gradient: chatProv.isLoading
                              ? null
                              : AppColors.primaryGradient,
                          color: chatProv.isLoading
                              ? AppColors.surfaceVariant
                              : null,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: chatProv.isLoading
                              ? null
                              : () => _sendMessage(_msgController.text),
                          icon: Icon(
                            Icons.send_rounded,
                            color: chatProv.isLoading
                                ? AppColors.textLight
                                : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('NutriFy AI', style: AppTextStyles.heading3),
          const SizedBox(height: 4),
          Text('Asisten nutrisi pribadimu',
              style: AppTextStyles.bodySmall),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _quickBtn('Buatkan jadwal makan hari ini'),
              _quickBtn('Hitung kebutuhan kalori saya'),
              _quickBtn('Rekomendasi menu sehat'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickBtn(String text) {
    return ActionChip(
      label: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
      backgroundColor: AppColors.primarySurface,
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
      onPressed: () => _sendMessage(text),
    );
  }

  Future<MealSchedule?> _showChoiceDialog(
    BuildContext context,
    List<MealSchedule> meals,
    String sesiMakan,
  ) {
    return showDialog<MealSchedule>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.surface,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Menu Untuk Diganti',
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Terdapat lebih dari satu menu pada sesi $sesiMakan hari ini.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: meals.length,
              itemBuilder: (BuildContext context, int index) {
                final meal = meals[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).pop(meal);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.restaurant,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                meal.namaMenu,
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Batal',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
