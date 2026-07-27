import 'package:flutter/material.dart';

/// DawaaCheck motion budget.
///
/// **Rule:** one-shot entrance per screen. Zero ambient loops. Exit animations
/// are ~70% of enter duration. Two kinds of stagger — don't confuse them:
///
/// - `sectionStaggerStep` (100ms) between top-level hierarchy blocks on a screen
///   (header → search → categories → banner → list). Validated by Ibrahim on the
///   home dashboard.
/// - `listStaggerStep` (40ms) between siblings inside a list or grid (3 scan
///   cards cascading in). Matches Material Design's 30–50ms rule.
///
/// Forbidden outside of loading skeletons: `AnimationController.repeat()`,
/// infinite Lottie, continuous gradient shimmers. See
/// `.claude/skills/dawaacheck-ui/references/motion.md`.
class AppMotion {
  AppMotion._();

  /// Entrance animation duration.
  static const Duration entranceDuration = Duration(milliseconds: 400);

  /// No delay before the first element enters.
  static const Duration entranceDelay = Duration(milliseconds: 0);

  /// Stagger between top-level screen sections.
  static const Duration sectionStaggerStep = Duration(milliseconds: 100);

  /// Stagger between siblings inside a list or grid.
  static const Duration listStaggerStep = Duration(milliseconds: 40);

  /// Enter easing — standard.
  static const Curve entranceCurve = Curves.easeOutCubic;

  /// Exit easing — snappier than enter so dismissals feel responsive.
  static const Curve exitCurve = Curves.easeInCubic;

  /// Exit animation duration (~70% of enter per Material Design motion rule).
  static const Duration exitDuration = Duration(milliseconds: 280);

  /// Vertical offset for slide-in entrances (8% of container height from below).
  static const double slideYOffset = 0.08;

  /// Computes the delay for an item at [index] in a list/grid stagger.
  static Duration listDelay(int index) => listStaggerStep * index;

  /// Computes the delay for a section at [index] in a screen cascade.
  static Duration sectionDelay(int index) => sectionStaggerStep * index;
}
