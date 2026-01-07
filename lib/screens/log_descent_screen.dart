import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogDescentScreen extends ConsumerStatefulWidget {
  const LogDescentScreen({super.key});

  @override
  ConsumerState<LogDescentScreen> createState() => _LogDescentScreenState();
}

class _LogDescentScreenState extends ConsumerState<LogDescentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _flowController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  int? _rating;
  String? _selectedDifficulty;
  bool _isPublic = true;

  @override
  void dispose() {
    _notesController.dispose();
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Descent'),
        actions: [
          TextButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // TODO: Save descent
                Navigator.pop(context);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // River Run Selection
            Card(
              child: ListTile(
                leading: const Icon(Icons.kayaking),
                title: const Text('Select River Run'),
                subtitle: const Text('Tap to choose a run'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Navigate to run selection
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Date Selection
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text(
                  '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Flow
            TextFormField(
              controller: _flowController,
              decoration: const InputDecoration(
                labelText: 'Flow (optional)',
                hintText: 'e.g., 150',
                suffixText: 'cms',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.water),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            
            // Rating
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rating',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < (_rating ?? 0)
                                ? Icons.star
                                : Icons.star_border,
                            size: 32,
                          ),
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () {
                            setState(() {
                              _rating = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Difficulty
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Difficulty Encountered',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.show_chart),
              ),
              value: _selectedDifficulty,
              items: ['I', 'II', 'III', 'IV', 'V', 'VI']
                  .map((diff) => DropdownMenuItem(
                        value: diff,
                        child: Text('Class $diff'),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDifficulty = value;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'How was your run?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            
            // Public/Private Toggle
            SwitchListTile(
              title: const Text('Make this descent public'),
              subtitle: const Text('Share with the community'),
              value: _isPublic,
              onChanged: (value) {
                setState(() {
                  _isPublic = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
