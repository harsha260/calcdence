import 'package:flutter_test/flutter_test.dart';
import 'package:attandance_manager/utils/attendance_calculator.dart';

void main() {
  group('AttendanceCalculator Tests', () {
    const double target = 0.75; // 75% target

    group('calculatePercentage', () {
      test('should return 0.0 when total is 0', () {
        expect(AttendanceCalculator.calculatePercentage(0, 0), 0.0);
      });

      test('should calculate correct percentage', () {
        expect(AttendanceCalculator.calculatePercentage(75, 100), 75.0);
        expect(AttendanceCalculator.calculatePercentage(3, 4), 75.0);
        expect(AttendanceCalculator.calculatePercentage(100, 100), 100.0);
      });
    });

    group('calculateBunkableClasses', () {
      test('should return 0 when total classes is 0', () {
        expect(AttendanceCalculator.calculateBunkableClasses(0, 0, target), 0);
      });

      test('should return 0 when exactly at threshold (75/100 -> 75%)', () {
        expect(
          AttendanceCalculator.calculateBunkableClasses(75, 100, target),
          0,
        );
      });

      test('should return 0 when below threshold (74/100 -> 74%)', () {
        expect(
          AttendanceCalculator.calculateBunkableClasses(74, 100, target),
          0,
        );
      });

      test('should correctly calculate bunkable classes when above target', () {
        // P = 80, T = 100, R = 0.75 => floor((80 - 75) / 0.75) = floor(6.66) = 6
        expect(
          AttendanceCalculator.calculateBunkableClasses(80, 100, target),
          6,
        );
      });

      test('edge case: 100% attended', () {
        // P = 100, T = 100, R = 0.75 => floor((100 - 75) / 0.75) = floor(33.33) = 33
        expect(
          AttendanceCalculator.calculateBunkableClasses(100, 100, target),
          33,
        );
      });
    });

    group('calculateRecoveryClasses', () {
      test('should return 0 when total classes is 0', () {
        expect(AttendanceCalculator.calculateRecoveryClasses(0, 0, target), 0);
      });

      test('should return 0 when exactly at threshold (75/100 -> 75%)', () {
        expect(
          AttendanceCalculator.calculateRecoveryClasses(75, 100, target),
          0,
        );
      });

      test('should return 0 when above threshold (80/100 -> 80%)', () {
        expect(
          AttendanceCalculator.calculateRecoveryClasses(80, 100, target),
          0,
        );
      });

      test('should correctly calculate needed classes when below target', () {
        // P = 70, T = 100, R = 0.75 => ceil((75 - 70) / 0.25) = ceil(20) = 20
        expect(
          AttendanceCalculator.calculateRecoveryClasses(70, 100, target),
          20,
        );
      });

      test('should correctly handle extreme case: 0% attended', () {
        // P = 0, T = 10, R = 0.75 => ceil((7.5 - 0) / 0.25) = 30
        expect(
          AttendanceCalculator.calculateRecoveryClasses(0, 10, target),
          30,
        );
      });
    });

    group('calculateRequiredPercentage', () {
      test('should return 0 when total classes is 0', () {
        expect(
          AttendanceCalculator.calculateRequiredPercentage(0, 0, target),
          0.0,
        );
      });

      test(
        'should correctly compute the required percentage to reach target',
        () {
          // P = 70, T = 100, R = 0.75 => (75 - 70) / 0.25 = 20
          expect(
            AttendanceCalculator.calculateRequiredPercentage(70, 100, target),
            closeTo(20.0, 0.001),
          );
        },
      );
    });
  });
}
