import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:location/location.dart' as gps; // ✅ Alias applied here

class MapSearchScreen extends StatefulWidget {
  const MapSearchScreen({super.key});

  @override
  State<MapSearchScreen> createState() => _MapSearchScreenState();
}

class _MapSearchScreenState extends State<MapSearchScreen> {
  late GoogleMapController _mapController;
  final _googlePlace = GooglePlace("AIzaSyCoQzkmzecrFnHY1vSeJiRdiG4YILWKK2Y");
  final TextEditingController _searchController = TextEditingController();
  List<AutocompletePrediction> _predictions = [];
  LatLng _initialPosition = const LatLng(23.8103, 90.4125); // Dhaka
  final Set<Marker> _markers = {};

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _searchPlaces(String value) async {
    var result = await _googlePlace.autocomplete.get(value);
    if (result != null && result.predictions != null) {
      setState(() {
        _predictions = result.predictions!;
      });
    }
  }

  void _selectPlace(String placeId, String description) async {
    var details = await _googlePlace.details.get(placeId);
    if (details != null &&
        details.result != null &&
        details.result!.geometry != null) {
      final lat = details.result!.geometry!.location!.lat;
      final lng = details.result!.geometry!.location!.lng;

      final selectedLatLng = LatLng(lat!, lng!);
      setState(() {
        _markers.clear();
        _markers.add(Marker(
            markerId: MarkerId(placeId),
            position: selectedLatLng,
            infoWindow: InfoWindow(title: description)));
        _predictions = [];
        _searchController.text = description;
      });
      _mapController
          .animateCamera(CameraUpdate.newLatLngZoom(selectedLatLng, 15));
    }
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  void _initLocation() async {
    gps.Location location = gps.Location(); // ✅ Prefixed with `gps`
    var locData = await location.getLocation();
    setState(() {
      _initialPosition = LatLng(locData.latitude!, locData.longitude!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BiteBuddy Map")),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition:
                CameraPosition(target: _initialPosition, zoom: 14),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "Search restaurant...",
                      contentPadding: EdgeInsets.all(12),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _searchPlaces,
                  ),
                ),
                ..._predictions.map((p) => ListTile(
                      title: Text(p.description ?? ''),
                      onTap: () => _selectPlace(p.placeId!, p.description!),
                    )),
              ],
            ),
          )
        ],
      ),
    );
  }
}
