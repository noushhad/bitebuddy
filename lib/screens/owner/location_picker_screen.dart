import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLatLng;

  const LocationPickerScreen({super.key, this.initialLatLng});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _pickedLatLng;

  @override
  void initState() {
    super.initState();
    _pickedLatLng = widget.initialLatLng;
  }

  void _confirmSelection() {
    if (_pickedLatLng != null) {
      Navigator.pop(context, _pickedLatLng);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a location")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _pickedLatLng ?? const LatLng(23.8103, 90.4125); // Dhaka

    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initial, zoom: 14),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (latLng) => setState(() => _pickedLatLng = latLng),
            markers: _pickedLatLng != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _pickedLatLng!,
                    )
                  }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Confirm Location'),
              onPressed: _confirmSelection,
            ),
          )
        ],
      ),
    );
  }
}
