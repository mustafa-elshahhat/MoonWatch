import 'package:flutter/material.dart';



class AppColors {
  AppColors._();

  
  static const background = Color(0xFF141210); 
  static const backgroundSecondary = Color(
    0xFF1C1A17,
  ); 
  static const surface = Color(0xFF24211E); 
  static const surfaceElevated = Color(
    0xFF2B2724,
  ); 
  static const surfaceGlass = Color(0x99141210); 

  
  static const border = Color(0xFF36322E); 
  static const divider = Color(0xFF36322E); 
  static const borderSubtle = Color(
    0xFF2E2A26,
  ); 
  static const edgeHighlight = Color(0x1AFFFFFF); 

  
  static const textPrimary = Color(0xFFF7F5F0); 
  static const textSecondary = Color(0xFFB3B0AA); 
  static const textMuted = Color(0xFF807D78); 
  static const textDisabled = Color(0xFF4D4A46);

  
  static const accentPrimary = Color(0xFFE5A33C); 
  static const accentPrimaryHover = Color(0xFFF5C06A); 
  static const accentPrimaryMuted = Color(0xFF996D28); 
  static const accentSecondary = Color(0xFFE5A33C); 

  
  static const success = Color(0xFF10B981);
  static const successSurface = Color(0xFF064E3B);
  static const warning = Color(0xFFF59E0B);
  static const warningSurface = Color(0xFF78350F);
  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFF7F1D1D);

  
  static const hostBadge = accentPrimary;
  static const hostBadgeBg = accentPrimaryMuted;
  static const guestBadge = textSecondary;
  static const guestBadgeBg = surfaceElevated;

  
  static const peerConnected = success;
  static const peerBuffering = warning;
  static const peerAway = textMuted;

  
  static const playerBackground = Color(0xFF000000);
  static const playerControlsBg = Color(
    0xB3000000,
  ); 
  static const playerOverlay = Color(0x80000000); 

  
  static const soloIcon = accentPrimary;
  static const createRoomIcon = textPrimary;
  static const joinRoomIcon = textSecondary;

  
  static Color withOpacity(Color color, double opacity) =>
      color.withValues(alpha: opacity);

  
  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [surface, surfaceElevated, surface],
    stops: [0.1, 0.3, 0.4],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );
}
