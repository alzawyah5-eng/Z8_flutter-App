import 'package:flutter/material.dart';

/// Branded, scrollable loading surface shared by workspace entry and sections.
class WorkspaceLoadingState extends StatelessWidget {
  const WorkspaceLoadingState({
    this.message = 'Preparing your workspace',
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF14263D), Color(0xFF52203F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: Color(0xFFE8C985),
              size: 25,
            ),
            const SizedBox(height: 18),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Loading your latest account information…',
              style: TextStyle(color: Color(0xFFE5D7E0), fontSize: 12),
            ),
            const SizedBox(height: 17),
            const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Color(0x668A6C7E),
              color: Color(0xFFE8C985),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      for (var index = 0; index < 3; index++)
        Container(
          height: index == 0 ? 96 : 72,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFE7E2E8)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EFF3),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: index == 0 ? .48 : .62,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EDF1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      FractionallySizedBox(
                        widthFactor: index == 1 ? .38 : .78,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F2F5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
