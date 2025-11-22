import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as gps;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';

enum TravelType { walking, bicycling, driving }

class MapScreen extends StatefulWidget {
  final LatLng? destination;
  final LatLng? origin;
  final String? title;
  final bool showRoute;

  const MapScreen({
    super.key,
    this.destination,
    this.origin,
    this.title,
    this.showRoute = false,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng _initialPosition = const LatLng(23.8103, 90.4125); // Dhaka fallback
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final _routeId = const PolylineId('route');

  TravelType _travelMode = TravelType.walking;

  @override
  void initState() {
    super.initState();
    _initLocationAndSetup();
  }

  Future<void> _initLocationAndSetup() async {
    LatLng? origin = widget.origin;

    if (origin == null) {
      final location = gps.Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          // Service remains disabled; proceed without origin
        }
      }

      var permission = await location.hasPermission();
      if (permission == gps.PermissionStatus.denied) {
        permission = await location.requestPermission();
      }

      if (permission == gps.PermissionStatus.granted ||
          permission.toString().endsWith('grantedLimited')) {
        final locData = await location.getLocation();
        if (locData.latitude != null && locData.longitude != null) {
          origin = LatLng(locData.latitude!, locData.longitude!);
        }
      }
    }

    setState(() {
      _initialPosition = origin ?? widget.destination ?? _initialPosition;
    });

    _markers.clear();
    if (widget.destination != null) {
      _markers.add(Marker(
        markerId: const MarkerId('dest'),
        position: widget.destination!,
        infoWindow: InfoWindow(title: widget.title ?? 'Destination'),
      ));
    }
    if (origin != null) {
      _markers.add(Marker(
        markerId: const MarkerId('origin'),
        position: origin,
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }

    if (widget.showRoute && origin != null && widget.destination != null) {
      await _buildRoute(origin, widget.destination!);
      _fitBounds(origin, widget.destination!);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> _buildRoute(LatLng from, LatLng to) async {
    const directionsKey =
        "AIzaSyCoQzkmzecrFnHY1vSeJiRdiG4YILWKK2Y"; // Your Directions API Key

    final points = PolylinePoints();

    TravelMode travelMode;
    switch (_travelMode) {
      case TravelType.walking:
        travelMode = TravelMode.walking;
        break;
      case TravelType.bicycling:
        travelMode = TravelMode.bicycling;
        break;
      case TravelType.driving:
        travelMode = TravelMode.driving;
        break;
    }

    final result = await points.getRouteBetweenCoordinates(
      directionsKey,
      PointLatLng(from.latitude, from.longitude),
      PointLatLng(to.latitude, to.longitude),
      travelMode: travelMode,
    );

    if (!mounted || result.points.isEmpty) return;

    final routePts =
        result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    setState(() {
      _polylines
        ..removeWhere((p) => p.polylineId == _routeId)
        ..add(Polyline(polylineId: _routeId, width: 6, points: routePts));
    });
  }

  void _fitBounds(LatLng a, LatLng b) {
    final sw = LatLng(
      a.latitude < b.latitude ? a.latitude : b.latitude,
      a.longitude < b.longitude ? a.longitude : b.longitude,
    );
    final ne = LatLng(
      a.latitude > b.latitude ? a.latitude : b.latitude,
      a.longitude > b.longitude ? a.longitude : b.longitude,
    );
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        60,
      ),
    );
  }

  // When travel mode changes, rebuild route if possible
  void _onTravelModeChanged(TravelType mode) async {
    if (!mounted) return;
    setState(() {
      _travelMode = mode;
    });

    if (widget.showRoute &&
        widget.origin != null &&
        widget.destination != null) {
      await _buildRoute(widget.origin!, widget.destination!);
      _fitBounds(widget.origin!, widget.destination!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDest = widget.destination != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? "BiteBuddy Map"),
        // actions: [
        //   if (hasDest)
        //     IconButton(
        //       tooltip: 'Open in Google Maps',
        //       icon: const Icon(Icons.turn_right),
        //       onPressed: () async {
        //         final d = widget.destination!;
        //         final uri = Uri.parse(
        //           'https://www.google.com/maps/dir/?api=1'
        //           '&destination=${d.latitude},${d.longitude}'
        //           '&travelmode=${_travelMode.name}',
        //         );
        //         await launchUrl(uri, mode: LaunchMode.externalApplication);
        //       },
        //     ),
        // ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),

          // Travel Mode Selector
          // Positioned(
          //   top: 10,
          //   left: 10,
          //   right: 10,
          //   child: Card(
          //     elevation: 4,
          //     shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(8)),
          //     child: Padding(
          //       padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          //       child: Row(
          //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          //         children: [
          //           _TravelModeButton(
          //             label: "Walk",
          //             icon: Icons.directions_walk,
          //             selected: _travelMode == TravelType.walking,
          //             onTap: () => _onTravelModeChanged(TravelType.walking),
          //           ),
          //           _TravelModeButton(
          //             label: "Bike",
          //             icon: Icons.directions_bike,
          //             selected: _travelMode == TravelType.bicycling,
          //             onTap: () => _onTravelModeChanged(TravelType.bicycling),
          //           ),
          //           _TravelModeButton(
          //             label: "Car",
          //             icon: Icons.directions_car,
          //             selected: _travelMode == TravelType.driving,
          //             onTap: () => _onTravelModeChanged(TravelType.driving),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
      floatingActionButton: (hasDest && _polylines.isNotEmpty)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.navigation),
              label: const Text('Start'),
              onPressed: () async {
                final d = widget.destination!;
                final uri = Uri.parse(
                  'https://www.google.com/maps/dir/?api=1'
                  '&destination=${d.latitude},${d.longitude}'
                  '&travelmode=${_travelMode.name}',
                );
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            )
          : null,
    );
  }
}

class _TravelModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TravelModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? Theme.of(context).colorScheme.primary : Colors.grey;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
