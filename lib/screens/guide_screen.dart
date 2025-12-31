import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/river_run.dart';
import 'run_details_screen.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('river_runs')
          .orderBy('river')
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

        final runs = snapshot.data!.docs
            .map((doc) => RiverRun.fromFirestore(doc))
            .toList();

        return ListView.builder(
          itemCount: runs.length,
          itemBuilder: (context, index) {
            final run = runs[index];

            final title = run.region.isNotEmpty
                ? '${run.river} - ${run.region}'
                : run.river;

            final subtitle = '${run.name} (${run.difficultyText})';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Icon(
                  Icons.water,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          RunDetailsScreen(runId: run.riverId),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
