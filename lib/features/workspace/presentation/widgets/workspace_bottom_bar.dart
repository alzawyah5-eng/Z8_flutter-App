import 'package:flutter/material.dart';

/// Compact role-aware navigation shared by the workspace and assistant pages.
class WorkspaceBottomBar extends StatelessWidget {
  const WorkspaceBottomBar({
    required this.isAdmin,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final bool isAdmin;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final destinations = isAdmin
        ? const [
            (Icons.grid_view_rounded, 'Home'),
            (Icons.credit_card_rounded, 'Cards'),
            (Icons.groups_2_rounded, 'Clients'),
            (Icons.account_balance_wallet_rounded, 'Funds'),
          ]
        : const [
            (Icons.grid_view_rounded, 'Home'),
            (Icons.credit_card_rounded, 'Cards'),
            (Icons.receipt_long_rounded, 'Activity'),
            (Icons.person_outline_rounded, 'Account'),
          ];
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 5),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE7E2E8))),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A17243B),
              blurRadius: 14,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var index = 0; index < destinations.length; index++)
              Expanded(
                child: _BottomBarItem(
                  icon: destinations[index].$1,
                  label: destinations[index].$2,
                  selected: selectedIndex == index,
                  activeColor: colors.primary,
                  onTap: () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : const Color(0xFF77808E);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 52,
                height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor.withValues(alpha: .10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
