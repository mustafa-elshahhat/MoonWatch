import '../../../core/protocol/payloads.dart';

/// Describes the current playback context for driving dynamic UI.
///
/// Built from mode (solo/room), role (host/guest), and content type
/// (live/movie/episode). The UI reads capabilities from this model
/// instead of hardcoding per-screen logic.
class PlayerUIContext {
  // —— Identity ————————————————————————————————————————————————————
  final bool isRoomMode;
  final bool isHost;
  final bool isGuest;
  final bool isLive;
  final bool isMovie;
  final bool isEpisode;

  // —— Capabilities ————————————————————————————————————————————————
  /// Can this user control play/pause authoritatively?
  final bool canControlPlayback;

  /// Can this user seek (scrub) through the content?
  final bool canSeek;

  /// Can this user skip Â±10s?
  final bool canSkip;

  /// Can this user change content (browse IPTV)?
  final bool canChangeContent;

  /// Should speed controls be available?
  final bool canUseSpeed;

  /// Should a "Next Episode" button be shown?
  final bool canShowNextEpisode;

  /// Should a "Previous Episode" button be shown?
  final bool canShowPrevEpisode;

  // —— Display flags ———————————————————————————————————————————————
  /// Show the room code in the top bar?
  final bool showRoomCode;

  /// Show the role badge (HOST / GUEST)?
  final bool showRoleBadge;

  /// Show the peer/sync status indicator?
  final bool showPeerStatus;

  /// Show a "View Only" label (guest mode)?
  final bool showViewOnlyLabel;

  /// Show the seek bar (progress slider)?
  final bool showSeekBar;

  /// Show current time / duration text?
  final bool showTimeDisplay;

  /// Show the LIVE badge instead of seek bar?
  final bool showLiveBadge;

  /// Content title for top bar.
  final String title;

  /// Optional metadata subtitle (e.g. "S2 E5 Â· Episode Title").
  final String? subtitle;

  const PlayerUIContext._({
    required this.isRoomMode,
    required this.isHost,
    required this.isGuest,
    required this.isLive,
    required this.isMovie,
    required this.isEpisode,
    required this.canControlPlayback,
    required this.canSeek,
    required this.canSkip,
    required this.canChangeContent,
    required this.canUseSpeed,
    required this.canShowNextEpisode,
    required this.canShowPrevEpisode,
    required this.showRoomCode,
    required this.showRoleBadge,
    required this.showPeerStatus,
    required this.showViewOnlyLabel,
    required this.showSeekBar,
    required this.showTimeDisplay,
    required this.showLiveBadge,
    required this.title,
    this.subtitle,
  });

  /// Build context for **solo** playback (no room).
  factory PlayerUIContext.solo({
    required IptvDescriptorType contentType,
    required String title,
    String? subtitle,
    bool hasNextEpisode = false,
    bool hasPrevEpisode = false,
  }) {
    final isLive = contentType == IptvDescriptorType.live;
    final isVod = contentType == IptvDescriptorType.movie ||
        contentType == IptvDescriptorType.episode;
    final isEpisode = contentType == IptvDescriptorType.episode;

    return PlayerUIContext._(
      isRoomMode: false,
      isHost: false,
      isGuest: false,
      isLive: isLive,
      isMovie: contentType == IptvDescriptorType.movie,
      isEpisode: isEpisode,
      canControlPlayback: true,
      canSeek: isVod,
      canSkip: isVod,
      canChangeContent: false,
      canUseSpeed: isVod,
      canShowNextEpisode: isEpisode && hasNextEpisode,
      canShowPrevEpisode: isEpisode && hasPrevEpisode,
      showRoomCode: false,
      showRoleBadge: false,
      showPeerStatus: false,
      showViewOnlyLabel: false,
      showSeekBar: isVod,
      showTimeDisplay: true,
      showLiveBadge: isLive,
      title: title,
      subtitle: subtitle,
    );
  }

  /// Build context for **room host** playback.
  factory PlayerUIContext.roomHost({
    required IptvDescriptorType contentType,
    required String title,
    String? subtitle,
    bool hasNextEpisode = false,
  }) {
    final isLive = contentType == IptvDescriptorType.live;
    final isVod = contentType == IptvDescriptorType.movie ||
        contentType == IptvDescriptorType.episode;

    return PlayerUIContext._(
      isRoomMode: true,
      isHost: true,
      isGuest: false,
      isLive: isLive,
      isMovie: contentType == IptvDescriptorType.movie,
      isEpisode: contentType == IptvDescriptorType.episode,
      canControlPlayback: true,
      canSeek: isVod,
      canSkip: isVod,
      canChangeContent: true,
      canUseSpeed: false, // speed control not safe in sync mode
      canShowNextEpisode:
          contentType == IptvDescriptorType.episode && hasNextEpisode,
      canShowPrevEpisode: false,
      showRoomCode: true,
      showRoleBadge: true,
      showPeerStatus: true,
      showViewOnlyLabel: false,
      showSeekBar: isVod,
      showTimeDisplay: true,
      showLiveBadge: isLive,
      title: title,
      subtitle: subtitle,
    );
  }

  /// Build context for **room guest** playback.
  factory PlayerUIContext.roomGuest({
    required IptvDescriptorType contentType,
    required String title,
    String? subtitle,
  }) {
    final isLive = contentType == IptvDescriptorType.live;

    return PlayerUIContext._(
      isRoomMode: true,
      isHost: false,
      isGuest: true,
      isLive: isLive,
      isMovie: contentType == IptvDescriptorType.movie,
      isEpisode: contentType == IptvDescriptorType.episode,
      canControlPlayback: false,
      canSeek: false,
      canSkip: false,
      canChangeContent: false,
      canUseSpeed: false,
      canShowNextEpisode: false,
      canShowPrevEpisode: false,
      showRoomCode: true,
      showRoleBadge: true,
      showPeerStatus: true,
      showViewOnlyLabel: true,
      showSeekBar: false,
      showTimeDisplay: true,
      showLiveBadge: isLive,
      title: title,
      subtitle: subtitle,
    );
  }

  /// Build from a room state + content descriptor.
  factory PlayerUIContext.fromRoom({
    required String role,
    required IptvContentDescriptor descriptor,
    bool hasNextEpisode = false,
  }) {
    if (role == 'host') {
      return PlayerUIContext.roomHost(
        contentType: descriptor.contentType,
        title: descriptor.title,
        hasNextEpisode: hasNextEpisode,
      );
    }
    return PlayerUIContext.roomGuest(
      contentType: descriptor.contentType,
      title: descriptor.title,
    );
  }
}
