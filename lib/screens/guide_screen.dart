import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('river_runs')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.explore,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No runs found',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later for new runs',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        final runs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: runs.length,
          itemBuilder: (context, index) {
            final run = runs[index].data() as Map<String, dynamic>;
            final runId = runs[index].id;

            final difficultyClass = run['difficultyClass'];
            final river = run['river'] ?? '';
            final subtitle = difficultyClass != null
                ? '$river • Class $difficultyClass'
                : river;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Icon(
                  Icons.water,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(run['name'] ?? 'Unnamed Run'),
                subtitle: Text(subtitle),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Navigate to run details
                },
              ),
            );
          },
        );
      },
    );
  }
}
