import '../../map/models/venue_map_models.dart';
import '../../map/models/venue_mock_data.dart';
import '../models/safety_models.dart';
import 'safety_mock_data.dart';

/// Abstract contract for venue safety, emergency resources and official assistance.
abstract class SafetyRepository {
  Future<List<SafetyResource>> getSafetyResources();
  Future<List<SafetyResource>> getEmergencyActions();
  Future<List<SafetyResource>> getVenueHelpResources();
  Future<List<EmergencyContact>> getEmergencyContacts();
  Future<MapPoi?> getPoiForResource(SafetyResource resource);
}

/// In-memory/repository-backed implementation utilizing authoritative venue fixtures.
class SafetyRepositoryImpl implements SafetyRepository {
  static final SafetyRepositoryImpl _instance = SafetyRepositoryImpl._internal();
  factory SafetyRepositoryImpl() => _instance;
  SafetyRepositoryImpl._internal();

  @override
  Future<List<SafetyResource>> getSafetyResources() async {
    return List.unmodifiable(SafetyMockData.venueSafetyResources);
  }

  @override
  Future<List<SafetyResource>> getEmergencyActions() async {
    return SafetyMockData.venueSafetyResources.where((r) =>
        r.category == SafetyCategory.medical ||
        r.category == SafetyCategory.security ||
        r.category == SafetyCategory.emergencyExit).toList();
  }

  @override
  Future<List<SafetyResource>> getVenueHelpResources() async {
    return SafetyMockData.venueSafetyResources.where((r) =>
        r.category == SafetyCategory.helpDesk ||
        r.category == SafetyCategory.accessibility ||
        r.category == SafetyCategory.generalInfo).toList();
  }

  @override
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    return List.unmodifiable(SafetyMockData.demoEmergencyContacts);
  }

  @override
  Future<MapPoi?> getPoiForResource(SafetyResource resource) async {
    final venueData = VenueMockData.getVenueData();
    return venueData.findPoiById(resource.poiId);
  }
}
