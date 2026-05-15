import 'package:flutter/foundation.dart';
import '../models/location_model.dart';
import '../global/app_settings.dart';

class LocationProvider extends ChangeNotifier {
  AppLocation? _location;

  AppLocation? get location => _location;
  bool get hasLocation => _location != null;

  LocationProvider() {
    _loadSaved();
  }

  void _loadSaved() {
    final json = AppSettings.savedLocationJson;
    if (json != null) {
      _location = AppLocation.fromJson(json);
      notifyListeners();
    }
  }

  Future<void> setLocation(AppLocation loc) async {
    _location = loc;
    await AppSettings.saveLocationJson(loc.toJson());
    notifyListeners();
  }

  void clearLocation() {
    _location = null;
    notifyListeners();
  }
}
