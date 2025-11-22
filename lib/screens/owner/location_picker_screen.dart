import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLatLng;

  const LocationPickerScreen({super.key, this.initialLatLng});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _pickedLatLng;
  bool _isLoadingLocation = true;
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _pickedLatLng = widget.initialLatLng;
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      final currentLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _pickedLatLng = currentLatLng;
          _isLoadingLocation = false;
        });

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: currentLatLng, zoom: 15),
          ),
        );

        // Get address for current location
        await _getReverseGeocodeAddress(currentLatLng);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _showSnackBar('Error getting location: ${e.toString()}', Colors.red);
      }
    }
  }

  Future<void> _getReverseGeocodeAddress(LatLng latLng) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address =
            '${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}';

        if (mounted) {
          setState(() {
            _selectedAddress = address.replaceAll(RegExp(r',\s*,'), ',').trim();
            if (_selectedAddress!.endsWith(',')) {
              _selectedAddress =
                  _selectedAddress!.substring(0, _selectedAddress!.length - 1);
            }
          });
        }
      }
    } catch (e) {
      // Silent error for reverse geocoding
    }
  }

  void _confirmSelection() {
    if (_pickedLatLng != null) {
      Navigator.pop(context, _pickedLatLng);
    } else {
      _showSnackBar('Please select a location', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _pickedLatLng ?? const LatLng(23.8103, 90.4125); // Dhaka

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        elevation: 0,
      ),
      body: _isLoadingLocation
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Stack(
              children: [
                // Google Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initial,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  onTap: (latLng) {
                    setState(() => _pickedLatLng = latLng);
                    _getReverseGeocodeAddress(latLng);
                  },
                  markers: _pickedLatLng != null
                      ? {
                          Marker(
                            markerId: const MarkerId('selected'),
                            position: _pickedLatLng!,
                            infoWindow: InfoWindow(
                              title: 'Selected Location',
                              snippet: _selectedAddress ?? 'Address loading...',
                            ),
                          )
                        }
                      : {},
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                ),

                // Selected Address Display
                if (_selectedAddress != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected Address:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedAddress ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Confirm Button at Bottom
                Positioned(
                  bottom: 40,
                  left: 80,
                  right: 80,
                  child: ElevatedButton.icon(
                    onPressed: _confirmSelection,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm Location'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
