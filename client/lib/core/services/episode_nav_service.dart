import 'package:flutter/foundation.dart';
import '../protocol/payloads.dart';

// —— Episode reference ————————————————————————————————————————————————————————

/// A lightweight handle to a single series episode used for next/prev
/// navigation. Carries only the fields needed to build an
/// [IptvContentDescriptor] and display a title in the player top bar.
///
/// This model is intentionally NOT part of the room protocol — it is a local,
/// ephemeral UI concern that is never serialised or sent to the server.
class EpisodeRef {
  final String id;
  final String containerExtension;
  final int seriesId;
  final String seriesName;
  final String seasonNum;
  final int episodeNum;
  final String episodeTitle;

  const EpisodeRef({
    required this.id,
    required this.containerExtension,
    required this.seriesId,
    required this.seriesName,
    required this.seasonNum,
    required this.episodeNum,
    required this.episodeTitle,
  });

  /// Human-readable title used in the player top bar and descriptors.
  String get displayTitle => '$seriesName - $episodeTitle';

  /// Builds the [IptvContentDescriptor] for use with [RoomEventSetContent]
  /// or [PlayerEventInitialize]. The descriptor carries no episode-navigation
  /// metadata — that lives only in [EpisodeNavService].
  IptvContentDescriptor toDescriptor() => IptvContentDescriptor(
    contentType: IptvDescriptorType.episode,
    streamId: id,
    containerExtension: containerExtension,
    title: displayTitle,
  );
}

// —— Episode navigation context ———————————————————————————————————————————————

/// Holds the flat, ordered episode list for the currently-playing series and
/// tracks which episode is active. Enables O(n) next/prev lookup.
class EpisodeNavContext {
  /// All episodes across all seasons, ordered by season number then episode
  /// number ascending. Built once when the user selects an episode.
  final List<EpisodeRef> allEpisodes;

  /// The [EpisodeRef.id] of the episode that is currently playing or
  /// about to be played.
  final String currentEpisodeId;

  const EpisodeNavContext({
    required this.allEpisodes,
    required this.currentEpisodeId,
  });

  int get _currentIndex =>
      allEpisodes.indexWhere((e) => e.id == currentEpisodeId);

  /// `true` when a next episode exists after the current one.
  bool get hasNext {
    final idx = _currentIndex;
    return idx >= 0 && idx < allEpisodes.length - 1;
  }

  /// The episode after the current one, or `null` if this is the last episode.
  EpisodeRef? get nextEpisode {
    final idx = _currentIndex;
    if (idx < 0 || idx >= allEpisodes.length - 1) return null;
    return allEpisodes[idx + 1];
  }

  /// Returns a new [EpisodeNavContext] pointing at [episodeId].
  EpisodeNavContext advanceTo(String episodeId) =>
      EpisodeNavContext(allEpisodes: allEpisodes, currentEpisodeId: episodeId);
}

// —— Service ——————————————————————————————————————————————————————————————————

/// Presentation-layer singleton that carries the current episode navigation
/// context so that [SoloPlayerScreen] and [WatchScreen] can show a
/// "Next Episode" button without embedding series metadata in the room
/// protocol or in [IptvContentDescriptor].
///
/// Populated by [IptvSeriesDetailScreen] just before a
/// [IptvSelectEpisode] event is dispatched. Read by the player screens to
/// compute [PlayerUIContext.canShowNextEpisode].
class EpisodeNavService extends ChangeNotifier {
  static final EpisodeNavService _instance = EpisodeNavService._();
  factory EpisodeNavService() => _instance;
  EpisodeNavService._();

  EpisodeNavContext? _current;

  /// The active navigation context, or `null` if no series episode context
  /// has been set (e.g. movie/live playback, or guest mode).
  EpisodeNavContext? get current => _current;

  /// Set a fresh context when the user selects an episode from the browse UI.
  void setContext(EpisodeNavContext context) {
    _current = context;
    notifyListeners();
  }

  /// Advance to [episodeId] after a next-episode action succeeds.
  void advanceTo(String episodeId) {
    if (_current == null) return;
    _current = _current!.advanceTo(episodeId);
    notifyListeners();
  }

  /// Clear the context when leaving episode playback entirely.
  void clear() {
    _current = null;
    notifyListeners();
  }
}
