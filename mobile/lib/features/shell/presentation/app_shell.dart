import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/glass_nav_bar.dart';

/// Bottom navigation scaffold for the patient's five tabs. Wraps a
/// [StatefulNavigationShell] so each branch keeps its own navigation stack and
/// scroll position when switching tabs.
///
/// The bar floats and is frosted, which only works if content passes beneath
/// it — hence `extendBody`. Every screen in these branches already reserves
/// bottom padding for a bar, so nothing ends up trapped underneath.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: GlassNavBar(
        currentIndex: navigationShell.currentIndex,
        onSelected:
            (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
        items: [
          const GlassNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
          ),
          const GlassNavItem(
            icon: Icons.chat_bubble_outline_rounded,
            selectedIcon: Icons.chat_bubble_rounded,
            label: 'Doctor',
          ),
          const GlassNavItem(
            icon: Icons.medication_outlined,
            selectedIcon: Icons.medication_rounded,
            label: 'Medicines',
          ),
          const GlassNavItem(
            icon: Icons.restaurant_menu_outlined,
            selectedIcon: Icons.restaurant_menu_rounded,
            label: 'Dietician',
          ),
          GlassNavItem(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
