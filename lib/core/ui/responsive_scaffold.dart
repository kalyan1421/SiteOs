import 'package:flutter/material.dart';
import 'responsive.dart';

/// Standard scaffold wrapper that keeps pages scrollable, keyboard-safe,
/// and constrained for all breakpoints.
///
/// ⚠ Nested scroll: this wraps the body in a [SingleChildScrollView].
/// Do NOT place a [ListView] or [GridView] with default scroll physics
/// inside it — use [NeverScrollableScrollPhysics] on any inner scroll
/// view, or don't use this scaffold for screens whose primary content
/// is already a scrollable list.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.builder,
    this.appBar,
    this.fab,
    this.backgroundColor,
    this.bottomNav,
  });

  final PreferredSizeWidget? appBar;
  final Widget? fab;
  final Color? backgroundColor;
  final Widget? bottomNav;
  final Widget Function(BuildContext context, R r) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = R(Size(constraints.maxWidth, constraints.maxHeight));
        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: backgroundColor,
          appBar: appBar,
          floatingActionButton: fab,
          bottomNavigationBar: bottomNav,
          body: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: builder(context, r),
              ),
            ),
          ),
        );
      },
    );
  }
}
