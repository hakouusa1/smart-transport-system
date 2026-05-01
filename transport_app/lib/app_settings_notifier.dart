import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final double fuelPricePerLiter;
  final int vidangeIntervalKm;
  final double fuelConsumptionL100;

  const AppSettings({
    this.fuelPricePerLiter = 36.0,
    this.vidangeIntervalKm = 10000,
    this.fuelConsumptionL100 = 35.0,
  });

  AppSettings copyWith({
    double? fuelPricePerLiter,
    int? vidangeIntervalKm,
    double? fuelConsumptionL100,
  }) =>
      AppSettings(
        fuelPricePerLiter: fuelPricePerLiter ?? this.fuelPricePerLiter,
        vidangeIntervalKm: vidangeIntervalKm ?? this.vidangeIntervalKm,
        fuelConsumptionL100: fuelConsumptionL100 ?? this.fuelConsumptionL100,
      );
}

class AppSettingsNotifier extends ValueNotifier<AppSettings> {
  static const _keyFuelPrice = 'settings_fuel_price';
  static const _keyVidange = 'settings_vidange_km';
  static const _keyConsumption = 'settings_fuel_consumption';

  AppSettingsNotifier() : super(const AppSettings());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = AppSettings(
      fuelPricePerLiter: prefs.getDouble(_keyFuelPrice) ?? 36.0,
      vidangeIntervalKm: prefs.getInt(_keyVidange) ?? 10000,
      fuelConsumptionL100: prefs.getDouble(_keyConsumption) ?? 35.0,
    );
  }

  Future<void> setFuelPrice(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFuelPrice, v);
    value = value.copyWith(fuelPricePerLiter: v);
  }

  Future<void> setVidangeInterval(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyVidange, v);
    value = value.copyWith(vidangeIntervalKm: v);
  }

  Future<void> setFuelConsumption(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyConsumption, v);
    value = value.copyWith(fuelConsumptionL100: v);
  }
}

final appSettingsNotifier = AppSettingsNotifier();
