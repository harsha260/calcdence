import 'package:flutter_test/flutter_test.dart';
import 'package:attandance_manager/providers/attendance_provider.dart';

void main() {
  group('AttendanceCalculator Tests', () {
    const double target = 0.75;

    group('calculateBunkableClasses', () {
      test('should return 0 when total classes is 0', () {
        expect(AttendanceCalculator.calculateBunkableClasses(0, 0, target), 0);
      });

      test('should return 0 when current percentage is below or equal to target', () {
        expect(AttendanceCalculator.calculateBunkableClasses(75, 100, target), 0);
        expect(AttendanceCalculator.calculateBunkableClasses(74, 100, target), 0);
      });

      test('should correctly calculate bunkable classes when above target', () {
        // P = 80, T = 100, R = 0.75
        // floor((80 - 0.75*100) / 0.75) = floor((80 - 75)/0.75) = floor(6.66) = 6
        expect(AttendanceCalculator.calculateBunkableClasses(80, 100, target), 6);
        
        // P = 100, T = 100, R = 0.75
        // floor((100 - 75)/0.75) = floor(33.33) = 33
        expect(AttendanceCalculator.calculateBunkableClasses(100, 100, target), 33);
      });
    });

    group('calculateRecoveryClasses', () {
      test('should return 0 when total classes is 0', () {
        expect(AttendanceCalculator.calculateRecoveryClasses(0, 0, target), 0);
      });

      test('should return 0 when current percentage is above or equal to target', () {
        expect(AttendanceCalculator.calculateRecoveryClasses(75, 100, target), 0);
        expect(AttendanceCalculator.calculateRecoveryClasses(80, 100, target), 0);
      });

      test('should correctly calculate needed classes when below target', () {
        // P = 70, T = 100, R = 0.75
        // ceil((0.75*100 - 70)/(1 - 0.75)) = ceil((75 - 70)/0.25) = ceil(20) = 20
        expect(AttendanceCalculator.calculateRecoveryClasses(70, 100, target), 20);

        // P = 60, T = 100, R = 0.75
        // ceil((75 - 60)/0.25) = ceil(60) = 60
        expect(AttendanceCalculator.calculateRecoveryClasses(60, 100, target), 60);
      });
    });

    group('calculateRequiredPercentage', () {
      test('should return 0 when total classes is 0', () {
        expect(AttendanceCalculator.calculateRequiredPercentage(0, 0, target), 0.0);
      });

      test('should correctly compute the required percentage to reach target', () {
        // P = 70, T = 100, R = 0.75
        // x = (0.75 * 100 - 70) / (1 - 0.75) = (75 - 70) / 0.25 = 20
        expect(AttendanceCalculator.calculateRequiredPercentage(70, 100, target), closeTo(20.0, 0.001));
      });
    });
  });
}