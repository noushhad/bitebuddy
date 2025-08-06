import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class DirectionsHelper {
  static const String _apiKey = 'AlzaSyjPP-Pa7a3eMKKtZzK7WZAMuXa8PrfrsED';

  static Future<void> openGoogleMapsDirections(
      double destLat, double destLng) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'Location services disabled';

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw 'Permission denied';
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Permission permanently denied';
    }

    final position = await Geolocator.getCurrentPosition();
    final originLat = position.latitude;
    final originLng = position.longitude;

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=$originLat,$originLng'
      '&destination=$destLat,$destLng'
      '&travelmode=driving',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not open Google Maps';
    }
  }

  static Future<Map<String, double>?> fetchLatLngFromPlaceId(
      String placeId) async {
    final url = Uri.parse(
      'https://maps.gomaps.pro/maps/api/place/details/json'
      '?place_id=$placeId&fields=geometry&key=$_apiKey',
    );

    final response = await http.get(url);
    final data = jsonDecode(response.body);

    if (data['status'] == 'OK') {
      final location = data['result']['geometry']['location'];
      return {
        'lat': location['lat'],
        'lng': location['lng'],
      };
    }

    return null;
  }
}
