import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/meal_schedule.dart';
import '../../data/models/ingredient.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/repositories/ingredient_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../../core/utils/nutrisi_calculator.dart';

class ScheduleProvider extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  List<MealSchedule> _meals = [];
  bool _isWeeklyView = false;
  final _uuid = const Uuid();

  DateTime get selectedDate => _selectedDate;
  List<MealSchedule> get meals => _meals;
  bool get isWeeklyView => _isWeeklyView;

  List<MealSchedule> getMealsBySession(String sesi) {
    return _meals.where((m) => m.sesi == sesi).toList();
  }

  void loadSchedule() {
    if (_isWeeklyView) {
      final startOfWeek =
          _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      _meals = ScheduleRepository.getByDateRange(startOfWeek, endOfWeek);
    } else {
      _meals = ScheduleRepository.getByDate(_selectedDate);
    }
    notifyListeners();
  }

  void setDate(DateTime date) {
    _selectedDate = date;
    loadSchedule();
  }

  void toggleView() {
    _isWeeklyView = !_isWeeklyView;
    loadSchedule();
  }

  Future<void> addMeal(MealSchedule meal) async {
    await ScheduleRepository.save(meal);
    loadSchedule();
  }

  /// Konversi label sesi ke key internal
  String _sesiToKey(String sesiMakan) {
    switch (sesiMakan.toLowerCase().trim()) {
      case 'sarapan':
        return 'sarapan';
      case 'makan siang':
        return 'makan_siang';
      case 'makan malam':
        return 'makan_malam';
      default:
        // Fallback: coba cocokkan sebagian
        if (sesiMakan.toLowerCase().contains('siang')) return 'makan_siang';
        if (sesiMakan.toLowerCase().contains('malam')) return 'makan_malam';
        return 'sarapan';
    }
  }

  /// Bangun daftar MealItem dari ingredients map
  Future<List<MealItem>> _buildItems(Map<String, String> ingredients) async {
    final items = <MealItem>[];
    for (final entry in ingredients.entries) {
      var ingredient = IngredientRepository.getByName(entry.key);
      final weightStr = entry.value.replaceAll(RegExp(r'[^0-9.]'), '');
      final weight = double.tryParse(weightStr) ?? 100;

      if (ingredient == null) {
        // Buat bahan baru dan simpan secara permanen ke database
        final String newId = _uuid.v4();
        ingredient = Ingredient(
          id: newId,
          nama: entry.key,
          kaloriPer100g: 0,
          proteinPer100g: 0,
          lemakPer100g: 0,
          karboPer100g: 0,
          isCustom: true,
        );
        await IngredientRepository.save(ingredient);
      }

      items.add(MealItem(
        ingredientId: ingredient.id,
        ingredientNama: ingredient.nama,
        beratGram: weight,
        kalori: ingredient.kaloriForWeight(weight),
        protein: ingredient.proteinForWeight(weight),
        lemak: ingredient.lemakForWeight(weight),
        karbo: ingredient.karboForWeight(weight),
      ));
    }
    return items;
  }

  /// Validasi apakah total nutrisi melebihi target harian
  Future<bool> _isLimitExceeded(
    List<MealItem> newItems, {
    double subtractKalori = 0,
    double subtractProtein = 0,
    double subtractLemak = 0,
    double subtractKarbo = 0,
  }) async {
    final profile = UserRepository.getProfile();
    if (profile == null) return false;

    final targets = NutrisiCalculator.hitungSemuaNutrisi(
      beratKg: profile.beratBadan,
      tinggiCm: profile.tinggiBadan,
      umur: profile.umur,
      gender: profile.gender,
      aktivitas: profile.aktivitas,
      targetDiet: profile.targetDiet,
    );
    final targetKalori = targets['targetKalori'] ?? 2000;
    final targetProtein = targets['protein'] ?? 150;
    final targetLemak = targets['lemak'] ?? 65;
    final targetKarbo = targets['karbo'] ?? 250;

    final dailyNutr = NutritionRepository.getDailyNutrition(DateTime.now());
    final currentKalori = dailyNutr['kalori'] ?? 0;
    final currentProtein = dailyNutr['protein'] ?? 0;
    final currentLemak = dailyNutr['lemak'] ?? 0;
    final currentKarbo = dailyNutr['karbo'] ?? 0;

    final newKalori = newItems.fold(0.0, (sum, item) => sum + item.effectiveKalori);
    final newProtein = newItems.fold(0.0, (sum, item) => sum + item.effectiveProtein);
    final newLemak = newItems.fold(0.0, (sum, item) => sum + item.effectiveLemak);
    final newKarbo = newItems.fold(0.0, (sum, item) => sum + item.effectiveKarbo);

    final finalKalori = currentKalori - subtractKalori + newKalori;
    final finalProtein = currentProtein - subtractProtein + newProtein;
    final finalLemak = currentLemak - subtractLemak + newLemak;
    final finalKarbo = currentKarbo - subtractKarbo + newKarbo;

    if (finalKalori > targetKalori ||
        finalProtein > targetProtein ||
        finalLemak > targetLemak ||
        finalKarbo > targetKarbo) {
      return true;
    }
    return false;
  }

  /// Cek apakah penambahan/penggantian menu akan melebihi batas nutrisi harian
  Future<bool> willExceedLimit({
    required Map<String, String> ingredients,
    required String sesiMakan,
    required bool isReplace,
  }) async {
    final sesiKey = _sesiToKey(sesiMakan);
    final newItems = await _buildItems(ingredients);

    double replacedKalori = 0;
    double replacedProtein = 0;
    double replacedLemak = 0;
    double replacedKarbo = 0;

    if (isReplace) {
      final today = DateTime.now();
      final existing = ScheduleRepository.getByDateAndSession(today, sesiKey);
      if (existing.isNotEmpty) {
        final targetMeal = existing.first;
        replacedKalori = targetMeal.totalKalori;
        replacedProtein = targetMeal.totalProtein;
        replacedLemak = targetMeal.totalLemak;
        replacedKarbo = targetMeal.totalKarbo;
      }
    }

    return _isLimitExceeded(
      newItems,
      subtractKalori: replacedKalori,
      subtractProtein: replacedProtein,
      subtractLemak: replacedLemak,
      subtractKarbo: replacedKarbo,
    );
  }

  /// TAMBAH: menambahkan menu rekomendasi ke jadwal tanpa menghapus yang ada
  Future<bool> addMealFromRecommendation({
    required String namaMenu,
    required Map<String, String> ingredients,
    required String sesiMakan,
  }) async {
    final sesiKey = _sesiToKey(sesiMakan);
    final newItems = await _buildItems(ingredients);

    if (await _isLimitExceeded(newItems)) {
      return false;
    }

    final schedule = MealSchedule(
      id: _uuid.v4(),
      tanggal: DateTime.now(),
      sesi: sesiKey,
      namaMenu: namaMenu,
      items: newItems,
    );
    await addMeal(schedule);
    return true;
  }

  /// GANTI: hapus semua menu di sesi yang sama hari ini, lalu tambah yang baru
  Future<bool> replaceMealFromRecommendation({
    required String namaMenu,
    required Map<String, String> ingredients,
    required String sesiMakan,
  }) async {
    final sesiKey = _sesiToKey(sesiMakan);
    final today = DateTime.now();

    final existing = ScheduleRepository.getByDateAndSession(today, sesiKey);
    double replacedKalori = 0;
    double replacedProtein = 0;
    double replacedLemak = 0;
    double replacedKarbo = 0;
    for (final meal in existing) {
      if (meal.status == 'canceled') continue;
      replacedKalori += meal.totalKalori;
      replacedProtein += meal.totalProtein;
      replacedLemak += meal.totalLemak;
      replacedKarbo += meal.totalKarbo;
    }

    final newItems = await _buildItems(ingredients);
    if (await _isLimitExceeded(
      newItems,
      subtractKalori: replacedKalori,
      subtractProtein: replacedProtein,
      subtractLemak: replacedLemak,
      subtractKarbo: replacedKarbo,
    )) {
      return false;
    }

    // Hapus semua jadwal yang ada di sesi + tanggal yang sama
    for (final meal in existing) {
      await ScheduleRepository.delete(meal.id);
    }

    final schedule = MealSchedule(
      id: _uuid.v4(),
      tanggal: today,
      sesi: sesiKey,
      namaMenu: namaMenu,
      items: newItems,
    );
    await addMeal(schedule);
    return true;
  }

  /// AMBIL: daftar menu hari ini untuk sesi tertentu
  List<MealSchedule> getTodayMealsForSession(String sesiMakan) {
    final sesiKey = _sesiToKey(sesiMakan);
    return ScheduleRepository.getByDateAndSession(DateTime.now(), sesiKey);
  }

  /// GANTI SPESIFIK: hapus satu menu lama berdasarkan ID-nya, lalu tambahkan menu baru
  Future<bool> replaceSpecificMealFromRecommendation({
    required String targetMealId,
    required String newNamaMenu,
    required Map<String, String> ingredients,
    required String sesiMakan,
  }) async {
    final sesiKey = _sesiToKey(sesiMakan);
    final today = DateTime.now();

    final all = ScheduleRepository.getAll();
    MealSchedule? targetMeal;
    try {
      targetMeal = all.firstWhere((m) => m.id == targetMealId);
    } catch (_) {}

    double replacedKalori = 0;
    double replacedProtein = 0;
    double replacedLemak = 0;
    double replacedKarbo = 0;
    if (targetMeal != null && targetMeal.status != 'canceled') {
      replacedKalori = targetMeal.totalKalori;
      replacedProtein = targetMeal.totalProtein;
      replacedLemak = targetMeal.totalLemak;
      replacedKarbo = targetMeal.totalKarbo;
    }

    final newItems = await _buildItems(ingredients);
    if (await _isLimitExceeded(
      newItems,
      subtractKalori: replacedKalori,
      subtractProtein: replacedProtein,
      subtractLemak: replacedLemak,
      subtractKarbo: replacedKarbo,
    )) {
      return false;
    }

    // Hapus menu target
    await ScheduleRepository.delete(targetMealId);

    // Tambah menu baru
    final schedule = MealSchedule(
      id: _uuid.v4(),
      tanggal: today,
      sesi: sesiKey,
      namaMenu: newNamaMenu,
      items: newItems,
    );
    await addMeal(schedule);
    return true;
  }

  Future<void> updateMealStatus(String id, String status) async {
    final all = ScheduleRepository.getAll();
    try {
      final meal = all.firstWhere((m) => m.id == id);
      final updated = meal.copyWith(status: status);
      await ScheduleRepository.save(updated);
      loadSchedule();
    } catch (_) {}
  }

  Future<void> deleteMeal(String id) async {
    await ScheduleRepository.delete(id);
    loadSchedule();
  }
}
