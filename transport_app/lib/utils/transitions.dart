import 'package:flutter/material.dart';

/// Custom page transitions for the app.
///
/// Usage:
///   Navigator.push(context, AppTransitions.slideRight(page: const SubscriptionScreen()));
abstract class AppTransitions {
  /// Slide in from the right + fade + subtle scale-up.
  /// Used for forward navigation (e.g. pending → subscription).
  /// The pop (back) is the automatic reverse.
  static PageRouteBuilder<T> slideRight<T>({required Widget page}) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        // — Incoming screen —
        final slideIn = Tween<Offset>(
          begin: const Offset(0.18, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
          ),
        );

        final scaleIn = Tween<double>(begin: 0.96, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        // — Outgoing screen (parallax + dim) —
        final slideOut = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.06, 0),
        ).animate(CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeInCubic,
        ));

        final dimOut = Tween<double>(begin: 1.0, end: 0.82).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
        );

        return SlideTransition(
          position: slideOut,
          child: FadeTransition(
            opacity: dimOut,
            child: SlideTransition(
              position: slideIn,
              child: FadeTransition(
                opacity: fadeIn,
                child: ScaleTransition(scale: scaleIn, child: child),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Slide up from the bottom + fade in.
  /// Use this for modal-style screens that overlay the current one.
  static PageRouteBuilder<T> slideUp<T>({required Widget page}) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 360),
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final slideIn = Tween<Offset>(
          begin: const Offset(0, 0.10),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          ),
        );

        final scaleIn = Tween<double>(begin: 0.97, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        final dimOut = Tween<double>(begin: 1.0, end: 0.85).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
        );

        return FadeTransition(
          opacity: dimOut,
          child: SlideTransition(
            position: slideIn,
            child: FadeTransition(
              opacity: fadeIn,
              child: ScaleTransition(scale: scaleIn, child: child),
            ),
          ),
        );
      },
    );
  }
}

/// A global page transition builder that applies the smooth slide+fade 
/// animation to all standard MaterialPageRoutes.
class SmoothSlidePageTransitionBuilder extends PageTransitionsBuilder {
  const SmoothSlidePageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (animation.status == AnimationStatus.reverse) {
      // Simplier transition for popping back
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-0.1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );
    }
    
    final slideIn = Tween<Offset>(
      begin: const Offset(0.18, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    final scaleIn = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );

    final slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.06, 0),
    ).animate(CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeInCubic,
    ));

    final dimOut = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
    );

    return SlideTransition(
      position: slideOut,
      child: FadeTransition(
        opacity: dimOut,
        child: SlideTransition(
          position: slideIn,
          child: FadeTransition(
            opacity: fadeIn,
            child: ScaleTransition(scale: scaleIn, child: child),
          ),
        ),
      ),
    );
  }
}
