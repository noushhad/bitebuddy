import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacesService {
  // final String apiKey =
  //     'AlzaSyjPP-Pa7a3eMKKtZzK7WZAMuXa8PrfrsED'; // use your real key
  final String apiKey =
      'AlzaSyepTEHhsQBV6Uq8C8B67-sVj5SOdxmomAx'; // use your real key

  Future<List<Map<String, dynamic>>> searchNearbyRestaurants({
    required double lat,
    required double lng,
    String keyword = '',
    int radius = 2000,
    bool openNow = false,
    String cuisine = '',
  }) async {
    final buffer = StringBuffer(
      'https://maps.gomaps.pro/maps/api/place/nearbysearch/json'
      '?location=$lat,$lng'
      '&radius=$radius'
      '&type=restaurant'
      '&key=$apiKey',
    );

    if (keyword.isNotEmpty) buffer.write('&keyword=$keyword');
    if (cuisine.isNotEmpty) buffer.write('&keyword=$cuisine');
    if (openNow) buffer.write('&opennow=true');

    final response = await http.get(Uri.parse(buffer.toString()));
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Places API error: ${data['status']}');
    }
  }

  String getPhotoUrl(String photoRef) {
    return 'https://maps.gomaps.pro/maps/api/place/photo'
        '?maxwidth=400'
        '&photoreference=$photoRef'
        '&key=$apiKey';
  }
}
