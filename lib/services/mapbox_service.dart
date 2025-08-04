// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class MapboxService {
//   static const String _accessToken =
//       'pk.eyJ1Ijoic2Fyd2FyYWhtZWQiLCJhIjoiY21kcWJuejhtMDRzNDJ3b2g4cWVib3l5biJ9.uknhYfLc_srzpxyXKyra4A'; // Replace with your Mapbox Access Token
//   static const String _baseUrl =
//       'https://api.mapbox.com/geocoding/v5/mapbox.places/';

//   // Function to search for a location based on query
//   Future<List<Map<String, dynamic>>> searchPlace(String query) async {
//     final url = Uri.parse('$_baseUrl$query.json?access_token=$_accessToken');

//     final response = await http.get(url);

//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       List<Map<String, dynamic>> places = [];

//       for (var feature in data['features']) {
//         places.add({
//           'name': feature['place_name'],
//           'latitude': feature['center'][1],
//           'longitude': feature['center'][0],
//         });
//       }

//       return places;
//     } else {
//       throw Exception('Failed to load places');
//     }
//   }
// }
