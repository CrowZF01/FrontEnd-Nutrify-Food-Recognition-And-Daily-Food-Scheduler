import 'package:flutter/material.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/models/meal_schedule.dart';

class DashboardProvider extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  Map<String, double> _dailyNutrition = {};
  List<MealSchedule> _todayMeals = [];

  DateTime get selectedDate => _selectedDate;
  Map<String, double> get dailyNutrition => _dailyNutrition;
  List<MealSchedule> get todayMeals => _todayMeals;

  double get kaloriHariIni => _dailyNutrition['kalori'] ?? 0;
  double get proteinHariIni => _dailyNutrition['protein'] ?? 0;
  double get lemakHariIni => _dailyNutrition['lemak'] ?? 0;
  double get karboHariIni => _dailyNutrition['karbo'] ?? 0;

  void loadDashboard() {
    _dailyNutrition = NutritionRepository.getDailyNutrition(_selectedDate);
    _todayMeals = ScheduleRepository.getByDate(_selectedDate);
    
    // Sort today's meals based on session: Sarapan -> Makan Siang -> Makan Malam
    _todayMeals.sort((a, b) {
      int getOrder(String sesi) {
        switch (sesi.toLowerCase().trim()) {
          case 'sarapan':
            return 0;
          case 'makan_siang':
          case 'makan siang':
            return 1;
          case 'makan_malam':
          case 'makan malam':
            return 2;
          default:
            return 3;
        }
      }
      return getOrder(a.sesi).compareTo(getOrder(b.sesi));
    });
    
    notifyListeners();
  }

  void setDate(DateTime date) {
    _selectedDate = date;
    loadDashboard();
  }

  void refresh() {
    loadDashboard();
  }
}
