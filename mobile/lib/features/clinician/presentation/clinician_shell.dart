import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/glass_nav_bar.dart';
import '../../../shared/widgets/glass_surface.dart';

/// Bottom-navigation scaffold for the clinician (doctor + staff) app:
/// Home · Care · Nutrition · Profile.
///
/// Home is the dashboard — the clinic's pulse at a glance. Care lists the
/// doctor↔patient conversations, each row leading into that thread. Nutrition
/// lists the dietician↔patient conversations so the doctor can watch and step
/// in to guide. Clinical tools live in the Profile hub.
///
/// The bar is the same floating frosted one the patient and dietician apps
/// use. Three panels that navigate differently read as three products; this is
/// one.
class ClinicianShell extends StatelessWidget {
  const ClinicianShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    // The ground wraps the Scaffold rather than sitting inside the body, so
    // it runs behind the navigation bar as well. The bar's surround is only
    // padding — it was always transparent; what was covering the ground was
    // the Scaffold's own background underneath it.
    return GlassGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: navigationShell,
        bottomNavigationBar: GlassNavBar(
          currentIndex: navigationShell.currentIndex,
          onSelected:
              (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
          // Labels kept to single short words so none wrap on a narrow phone.
          items: const [
            GlassNavItem(
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard_rounded,
              label: 'Home',
            ),
            GlassNavItem(
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups_rounded,
              // 'Care' rather than 'Patients': it pairs with the Nutrition tab
              // as the clinic's two conversation streams (care vs nutrition),
              // which is also how the threads are modelled server-side.
              label: 'Care',
            ),
            GlassNavItem(
              icon: Icons.restaurant_menu_outlined,
              selectedIcon: Icons.restaurant_menu_rounded,
              label: 'Nutrition',
            ),
            GlassNavItem(
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
