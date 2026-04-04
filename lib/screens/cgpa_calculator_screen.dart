import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../models/subject.dart';

class CgpaCalculatorScreen extends StatefulWidget {
  const CgpaCalculatorScreen({super.key});

  @override
  State<CgpaCalculatorScreen> createState() => _CgpaCalculatorScreenState();
}

class _CgpaCalculatorScreenState extends State<CgpaCalculatorScreen> {
  final List<_SubjectInput> _subjects = [];
  double _cgpa = 0.0;
  bool _isInit = false;

  final Map<String, int> _gradePoints = {
    'O': 10,
    'A+': 9,
    'A': 8,
    'B+': 7,
    'B': 6,
    'C': 5,
    'F': 0,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _loadSubjectsFromApi();
      _isInit = true;
    }
  }

  void _loadSubjectsFromApi() {
    final attendanceProvider = context.read<AttendanceProvider>();
    final apiSubjects = attendanceProvider.attendance?.subjects ?? [];

    setState(() {
      _subjects.clear();
      for (var sub in apiSubjects) {
        // Skip purely non-credit subjects if any? usually we include all
        _subjects.add(
          _SubjectInput(
            id: sub.subjectCode.toString(),
            nameController: TextEditingController(text: sub.subjectName),
            creditsController:
                TextEditingController(text: sub.credits.toString()),
            selectedGrade: 'O',
          ),
        );
      }

      if (_subjects.isEmpty) {
        // Fallback to one empty row if no API subjects
        _addSubject();
      } else {
        _calculateCgpa();
      }
    });
  }

  void _addSubject() {
    setState(() {
      _subjects.add(
        _SubjectInput(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nameController: TextEditingController(),
          creditsController: TextEditingController(text: '3.0'),
          selectedGrade: 'O',
        ),
      );
    });
    _calculateCgpa();
  }

  void _removeSubject(int index) {
    setState(() {
      final sub = _subjects.removeAt(index);
      sub.nameController.dispose();
      sub.creditsController.dispose();
    });
    _calculateCgpa();
  }

  void _calculateCgpa() {
    double totalCredits = 0;
    double weightedPoints = 0;

    for (var sub in _subjects) {
      final credits = double.tryParse(sub.creditsController.text) ?? 0.0;
      final gradePoint = _gradePoints[sub.selectedGrade] ?? 0;

      if (credits > 0) {
        weightedPoints += (gradePoint * credits);
        totalCredits += credits;
      }
    }

    setState(() {
      _cgpa = totalCredits > 0 ? (weightedPoints / totalCredits) : 0.0;
    });
  }

  @override
  void dispose() {
    for (var sub in _subjects) {
      sub.nameController.dispose();
      sub.creditsController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CGPA / SGPA Calculator'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.deepPurple.shade200),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Your Estimated SGPA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _cgpa.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final sub = _subjects[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: sub.nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Subject Name',
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 20),
                              onPressed: () => _removeSubject(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: sub.creditsController,
                                decoration: const InputDecoration(
                                  labelText: 'Credits',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (_) => _calculateCgpa(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                value: sub.selectedGrade,
                                decoration: const InputDecoration(
                                  labelText: 'Grade',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: _gradePoints.keys.map((grade) {
                                  return DropdownMenuItem(
                                    value: grade,
                                    child: Text(grade),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      sub.selectedGrade = val;
                                    });
                                    _calculateCgpa();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSubject,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _SubjectInput {
  final String id;
  final TextEditingController nameController;
  final TextEditingController creditsController;
  String selectedGrade;

  _SubjectInput({
    required this.id,
    required this.nameController,
    required this.creditsController,
    required this.selectedGrade,
  });
}
