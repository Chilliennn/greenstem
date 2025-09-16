import 'package:flutter/material.dart';

class SlidingTabSwitcher extends StatefulWidget {
  final List<String> tabs;
  final int initialIndex;
  final ValueChanged<int>? onTabSelected;

  const SlidingTabSwitcher({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.onTabSelected,
  });

  @override
  State<SlidingTabSwitcher> createState() => _SlidingTabSwitcherState();
}

class _SlidingTabSwitcherState extends State<SlidingTabSwitcher> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(10),
      ),
      height: 50,
      child: Stack(
        children: [
          // sliding white box
          AnimatedAlign(
            alignment: _selectedIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              width: (MediaQuery.of(context).size.width - 40) /
                  widget.tabs.length, // split evenly
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // tabs text
          Row(
            children: List.generate(widget.tabs.length, (index) {
              final isSelected = _selectedIndex == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _selectedIndex = index);
                    if (widget.onTabSelected != null) {
                      widget.onTabSelected!(index);
                    }
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      widget.tabs[index],
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF1D1D1D) // dark when active
                            : const Color(0xFFFEFEFE), // light when inactive
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
