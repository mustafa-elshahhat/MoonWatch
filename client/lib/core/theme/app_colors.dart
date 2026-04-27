import 'package:flutter/material.dart';

/// Centralized color tokens for WatchParty.
/// All semantic colors are defined here — never use raw Colors.xxx in widgets.
class AppColors {
  AppColors._();

  // ── Luxury Dark Backgrounds ─────────────────────────────────────
  static const background = Color(0xFF141210); // Deepest void (bgWell)
  static const backgroundSecondary = Color(
    0xFF1C1A17,
  ); // Ambient atmosphere (bg)
  static const surface = Color(0xFF24211E); // Base cards (bgElev)
  static const surfaceElevated = Color(
    0xFF2B2724,
  ); // Hovered cards / Dialogs (bgCard)
  static const surfaceGlass = Color(0x99141210); // Frost / Blur base

  // ── Borders & Illuminations ──────────────────────────────────────
  static const border = Color(0xFF36322E); // Base borders (line)
  static const divider = Color(0xFF36322E); // Row separators
  static const borderSubtle = Color(
    0xFF2E2A26,
  ); // Very faint borders (lineSoft)
  static const edgeHighlight = Color(0x1AFFFFFF); // Top edge light for depth

  // ── Text Hierarchy ──────────────────────────────────────────────
  static const textPrimary = Color(0xFFF7F5F0); // High contrast warm white
  static const textSecondary = Color(0xFFB3B0AA); // Refined secondary (textDim)
  static const textMuted = Color(0xFF807D78); // Tertiary / Meta (textMuted)
  static const textDisabled = Color(0xFF4D4A46);

  // ── Elegant Amber Accent Family ─────────────────────────────────
  static const accentPrimary = Color(0xFFE5A33C); // Cinematic light amber
  static const accentPrimaryHover = Color(0xFFF5C06A); // Soft glow amber
  static const accentPrimaryMuted = Color(0xFF996D28); // Deep amber
  static const accentSecondary = Color(0xFFE5A33C); // Kept same for consistency

  // ── Premium Semantic Colors ─────────────────────────────────────
  static const success = Color(0xFF10B981);
  static const successSurface = Color(0xFF064E3B);
  static const warning = Color(0xFFF59E0B);
  static const warningSurface = Color(0xFF78350F);
  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFF7F1D1D);

  // ── Role badges ─────────────────────────────────────────────────
  static const hostBadge = accentPrimary;
  static const hostBadgeBg = accentPrimaryMuted;
  static const guestBadge = textSecondary;
  static const guestBadgeBg = surfaceElevated;

  // ── Peer status ─────────────────────────────────────────────────
  static const peerConnected = success;
  static const peerBuffering = warning;
  static const peerAway = textMuted;

  // ── Cinematic Player ────────────────────────────────────────────
  static const playerBackground = Color(0xFF000000);
  static const playerControlsBg = Color(
    0xB3000000,
  ); // 70% opacity gradient base
  static const playerOverlay = Color(0x80000000); // 50% opacity

  // ── Home cards ──────────────────────────────────────────────────
  static const soloIcon = accentPrimary;
  static const createRoomIcon = textPrimary;
  static const joinRoomIcon = textSecondary;

  // ── Opacity helpers ─────────────────────────────────────────────
  static Color withOpacity(Color color, double opacity) =>
      color.withValues(alpha: opacity);

  // ── Cinematic Gradients ─────────────────────────────────────────
  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [surface, surfaceElevated, surface],
    stops: [0.1, 0.3, 0.4],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );
}
