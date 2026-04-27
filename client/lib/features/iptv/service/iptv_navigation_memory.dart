import '../models/iptv_category.dart';

class IptvNavigationMemory {
  IptvContentType? activeTab;
  IptvCategory? activeCategory;
  String? activeSeriesId;
  String? activeSeriesName;
  bool isSelectionPop = false;

  void saveTab(IptvContentType tab) {
    activeTab = tab;
  }

  void saveCategory(IptvCategory category) {
    activeCategory = category;
  }

  void saveSeries(String seriesId, String seriesName) {
    activeSeriesId = seriesId;
    activeSeriesName = seriesName;
  }

  void clearSeries() {
    if (isSelectionPop) return;
    activeSeriesId = null;
    activeSeriesName = null;
  }

  void clearCategory() {
    if (isSelectionPop) return;
    activeCategory = null;
    activeSeriesId = null;
    activeSeriesName = null;
  }

  void clear() {
    activeTab = null;
    activeCategory = null;
    activeSeriesId = null;
    activeSeriesName = null;
    isSelectionPop = false;
  }
}
