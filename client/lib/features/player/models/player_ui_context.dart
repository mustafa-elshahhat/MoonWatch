import '../../../core/protocol/payloads.dart';






class PlayerUIContext {
  
  final bool isRoomMode;
  final bool isHost;
  final bool isGuest;
  final bool isLive;
  final bool isMovie;
  final bool isEpisode;

  
  
  final bool canControlPlayback;

  
  final bool canSeek;

  
  final bool canSkip;

  
  final bool canChangeContent;

  
  final bool canUseSpeed;

  
  final bool canShowNextEpisode;

  
  final bool canShowPrevEpisode;

  
  
  final bool showRoomCode;

  
  final bool showRoleBadge;

  
  final bool showPeerStatus;

  
  final bool showViewOnlyLabel;

  
  final bool showSeekBar;

  
  final bool showTimeDisplay;

  
  final bool showLiveBadge;

  
  final String title;

  
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
      canUseSpeed: false, 
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
