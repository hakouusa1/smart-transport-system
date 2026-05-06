/// Shared profit calculation logic used by both dashboard and statistics screens.
/// Kept as pure functions so it can be unit-tested without Flutter dependencies.
class TripProfitResult {
  final double chauffeurDay;
  final double receveurDay;
  final bool hasReceveur;
  final double fuelCostDA;
  final double fuelLiters;
  final double avgSpeedKmh;
  final double profit;

  const TripProfitResult({
    required this.chauffeurDay,
    required this.receveurDay,
    required this.hasReceveur,
    required this.fuelCostDA,
    required this.fuelLiters,
    required this.avgSpeedKmh,
    required this.profit,
  });
}

abstract class ProfitCalculator {
  /// Estimates fuel cost in DZD for a trip.
  /// Uses speed and vehicle mass to adjust base consumption.
  static double fuelCostDA({
    required double distKm,
    required double durationH,
    double? poidsKg,
    double fuelPriceDA = 36.0,
    double baseConsumptionL100 = 35.0,
  }) {
    if (distKm <= 0) return 0;
    final avgSpeed = durationH > 0 ? distKm / durationH : 70.0;
    final speedFactor = avgSpeed < 30
        ? 1.30
        : avgSpeed < 50
            ? 1.10
            : avgSpeed < 80
                ? 1.00
                : avgSpeed < 100
                    ? 1.05
                    : 1.20;
    const refMass = 12000.0;
    final massFactor = (poidsKg != null && poidsKg > 0)
        ? (poidsKg / refMass).clamp(0.6, 2.5)
        : 1.0;
    return distKm * baseConsumptionL100 * massFactor * speedFactor / 100.0 * fuelPriceDA;
  }

  /// Computes per-trip profit given all salary and fuel inputs.
  ///
  /// [fuelCostDAOverride] is used when the trip document already stores the
  /// actual fuel cost (recorded by the driver). Falls back to [fuelCostDA]
  /// estimation when null.
  static TripProfitResult calcTrip({
    required double recette,
    required double distKm,
    required double durationH,
    required double chauffeurSalary,
    required String chauffeurSalaryType,
    required int chauffeurTripCount,
    required double receveurSalary,
    required String receveurSalaryType,
    required int receveurTripCount,
    double? fuelCostDAOverride,
    double? poidsKg,
    double fuelPriceDA = 36.0,
    double baseConsumptionL100 = 35.0,
  }) {
    final chauffeurDay = chauffeurSalaryType == 'monthly'
        ? (chauffeurTripCount > 0 ? (chauffeurSalary / 30.0) / chauffeurTripCount : 0.0)
        : chauffeurSalary;

    final receveurDay = receveurSalaryType == 'monthly' && receveurSalary > 0
        ? (receveurTripCount > 0 ? (receveurSalary / 30.0) / receveurTripCount : 0.0)
        : receveurSalary;

    final fuel = fuelCostDAOverride ??
        fuelCostDA(
          distKm: distKm,
          durationH: durationH,
          poidsKg: poidsKg,
          fuelPriceDA: fuelPriceDA,
          baseConsumptionL100: baseConsumptionL100,
        );

    final fuelL = (distKm > 0 && fuelPriceDA > 0) ? fuel / fuelPriceDA : 0.0;
    final avgSpeed = (distKm > 0 && durationH > 0) ? distKm / durationH : 0.0;

    return TripProfitResult(
      chauffeurDay: chauffeurDay,
      receveurDay: receveurDay,
      hasReceveur: receveurSalary > 0,
      fuelCostDA: fuel,
      fuelLiters: fuelL,
      avgSpeedKmh: avgSpeed,
      profit: recette - chauffeurDay - receveurDay - fuel,
    );
  }
}
