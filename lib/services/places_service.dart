// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class PlacesService {
//   final String apiKey = 'AIzaSyCoQzkmzecrFnHY1vSeJiRdiG4YILWKK2Y';

//   Future<List<Map<String, dynamic>>> searchNearbyRestaurants({
//     required double lat,
//     required double lng,
//     String keyword = '',
//     int radius = 2000,
//     bool openNow = false,
//     String cuisine = '',
//   }) async {
//     final buffer = StringBuffer(
//       'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
//       '?location=$lat,$lng'
//       '&radius=$radius'
//       '&type=restaurant'
//       '&key=$apiKey',
//     );

//     if (keyword.isNotEmpty) buffer.write('&keyword=$keyword');
//     if (cuisine.isNotEmpty) buffer.write('&keyword=$cuisine');
//     if (openNow) buffer.write('&opennow=true');

//     final response = await http.get(Uri.parse(buffer.toString()));
//     final data = json.decode(response.body);

//     if (data['status'] == 'OK') {
//       return List<Map<String, dynamic>>.from(data['results']);
//     } else {
//       throw Exception('Places API error: ${data['status']}');
//     }
//   }

//   Future<Map<String, dynamic>> fetchPlaceDetails(String placeId) async {
//     final url = 'https://maps.googleapis.com/maps/api/place/details/json'
//         '?place_id=$placeId'
//         '&fields=name,photos,formatted_phone_number,website,price_level,reviews,editorial_summary,geometry'
//         '&key=$apiKey';

//     final response = await http.get(Uri.parse(url));
//     final data = json.decode(response.body);

//     if (data['status'] == 'OK') {
//       return data['result'] ?? {};
//     } else {
//       throw Exception('Place details API error: ${data['status']}');
//     }
//   }

//   String getPhotoUrl(String photoRef) {
//     return 'https://maps.googleapis.com/maps/api/place/photo'
//         '?maxwidth=400'
//         '&photoreference=$photoRef'
//         '&key=$apiKey';
//   }
// }

import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacesService {
  final String apiKey = 'AIzaSyCoQzkmzecrFnHY1vSeJiRdiG4YILWKK2Y';

  Future<List<Map<String, dynamic>>> searchNearbyRestaurants({
    required double lat,
    required double lng,
    String keyword = '',
    int radius = 2000,
    bool openNow = false, // Still here but can ignore in UI
    String cuisine = '',
    int? priceLevel, // <-- NEW
  }) async {
    final buffer = StringBuffer(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=$lat,$lng'
      '&radius=$radius'
      '&type=restaurant'
      '&key=$apiKey',
    );

    if (keyword.isNotEmpty) buffer.write('&keyword=$keyword');
    if (cuisine.isNotEmpty) buffer.write('&keyword=$cuisine');
    if (openNow) buffer.write('&opennow=true');
    if (priceLevel != null)
      buffer.write(
          '&minprice=$priceLevel&maxprice=$priceLevel'); // <-- Add to filter

    final response = await http.get(Uri.parse(buffer.toString()));
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Places API error: ${data['status']}');
    }
  }

  Future<Map<String, dynamic>> fetchPlaceDetails(String placeId) async {
    final url = 'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=name,photos,formatted_phone_number,website,price_level,reviews,editorial_summary,geometry'
        '&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      return data['result'] ?? {};
    } else {
      throw Exception('Place details API error: ${data['status']}');
    }
  }

  String getPhotoUrl(String photoRef) {
    return 'https://maps.googleapis.com/maps/api/place/photo'
        '?maxwidth=400'
        '&photoreference=$photoRef'
        '&key=$apiKey';
  }
}
