import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/glass_nav_bar.dart';

/// Bottom-navigation scaffold for the dietician: Home · Patients · Profile.
///
/// Home says what needs doing today, the patient list is everyone, and Profile
/// is where their own account lives — the same shape the doctor has, and the
/// same house mark and wording the patient's app uses, so somebody who has seen
/// one panel can read the others.
class DieticianShell extends StatelessWidget {
  const DieticianShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: GlassNavBar(
        currentIndex: navigationShell.currentIndex,
        onSelected:
            (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
        items: const [
          GlassNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
          ),
          GlassNavItem(
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups_rounded,
            label: 'Patients',
          ),
          GlassNavItem(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
