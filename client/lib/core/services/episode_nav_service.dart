import 'package:flutter/foundation.dart';
import '../protocol/payloads.dart';









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

  
  String get displayTitle => '$seriesName - $episodeTitle';

  
  
  
  IptvContentDescriptor toDescriptor() => IptvContentDescriptor(
        contentType: IptvDescriptorType.episode,
        streamId: id,
        containerExtension: containerExtension,
        title: displayTitle,
      );
}





class EpisodeNavContext {
  
  
  final List<EpisodeRef> allEpisodes;

  
  
  final String currentEpisodeId;

  const EpisodeNavContext({
    required this.allEpisodes,
    required this.currentEpisodeId,
  });

  int get _currentIndex =>
      allEpisodes.indexWhere((e) => e.id == currentEpisodeId);

  
  bool get hasNext {
    final idx = _currentIndex;
    return idx >= 0 && idx < allEpisodes.length - 1;
  }

  
  EpisodeRef? get nextEpisode {
    final idx = _currentIndex;
    if (idx < 0 || idx >= allEpisodes.length - 1) return null;
    return allEpisodes[idx + 1];
  }

  
  EpisodeNavContext advanceTo(String episodeId) =>
      EpisodeNavContext(allEpisodes: allEpisodes, currentEpisodeId: episodeId);
}











class EpisodeNavService extends ChangeNotifier {
  static final EpisodeNavService _instance = EpisodeNavService._();
  factory EpisodeNavService() => _instance;
  EpisodeNavService._();

  EpisodeNavContext? _current;

  
  
  EpisodeNavContext? get current => _current;

  
  void setContext(EpisodeNavContext context) {
    _current = context;
    notifyListeners();
  }

  
  void advanceTo(String episodeId) {
    if (_current == null) return;
    _current = _current!.advanceTo(episodeId);
    notifyListeners();
  }

  
  void clear() {
    _current = null;
    notifyListeners();
  }
}
