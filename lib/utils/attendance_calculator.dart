import 'dart:math' as math;

/// Calculator for attendance calculations
class AttendanceCalculator {
  /// Calculate overall percentage. Returns a double between 0.0 and 100.0.
  static double calculatePercentage(int attended, int total) {
    if (total == 0) return 0.0;
    return (attended / total) * 100.0;
  }

  /// Calculate how many classes can be skipped while maintaining target percentage
  /// Formula: x = floor((P - (R * T)) / R)
  /// Where:
  /// - P = classes attended
  /// - T = total classes conducted
  /// - R = target percentage (as decimal, e.g., 0.75 for 75%)
  static int calculateBunkableClasses(
    int attended,
    int total,
    double targetPercent,
  ) {
    if (total == 0 || targetPercent <= 0 || targetPercent > 1) return 0;

    final currentPercent = total > 0 ? attended / total : 0.0;

    // Can only skip if current percentage > target
    if (currentPercent <= targetPercent) return 0;

    // Calculate using formula: floor((P - R*T) / R)
    final bunkable =
        ((attended - (targetPercent * total)) / targetPercent).floor();

    return math.max(0, bunkable);
  }

  /// Calculate how many consecutive classes need to be attended to reach target
  /// Formula: x = ceil((R * T - P) / (1 - R))
  /// Where:
  /// - P = classes attended
  /// - T = total classes conducted
  /// - R = target percentage (as decimal, e.g., 0.75 for 75%)
  static int calculateRecoveryClasses(
    int attended,
    int total,
    double targetPercent,
  ) {
    if (total == 0 || targetPercent <= 0 || targetPercent > 1) return 0;

    final currentPercent = total > 0 ? attended / total : 0.0;

    // No need to recover if already at or above target
    if (currentPercent >= targetPercent) return 0;

    // Calculate using formula: ceil((R*T - P) / (1 - R))
    final needed =
        ((targetPercent * total - attended) / (1 - targetPercent)).ceil();

    return math.max(0, needed);
  }

  /// Calculate required attendance percentage for remaining classes to reach target
  static double calculateRequiredPercentage(
    int attended,
    int total,
    double targetPercent,
  ) {
    if (total == 0 || targetPercent <= 0 || targetPercent > 1) return 0;

    final remaining = 100 - (attended / total * 100);
    if (remaining <= 0) return 0;

    final required = (targetPercent * total - attended) / (1 - targetPercent);
    return math.max(0, required);
  }
}
