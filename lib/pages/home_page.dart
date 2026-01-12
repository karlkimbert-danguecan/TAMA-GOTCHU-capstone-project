import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tamagotchuuu/pages/deviceconfig_page.dart';
import 'package:tamagotchuuu/services/auth_service.dart';
import 'package:tamagotchuuu/pages/login_screen.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:tamagotchuuu/services/home_page_preloader.dart';

// 1. Pass the preloader instance to the HomePage
class HomePage extends StatefulWidget {
  final HomePageDataPreloader preloader;

  const HomePage({super.key, required this.preloader});

  @override
  State<HomePage> createState() => _HomePageState();
}

// 2. The State class now listens to the preloader
class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final auth = AuthService();
  final MapController _mapController = MapController();
  
  
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  // New State Variable for Distance
  double _distanceInKm = 0.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.easeInOut,
      ),
    );

    // 3. Add a listener to the preloader to call setState() on data change
    widget.preloader.addListener(() {
      if (mounted) {
        _calculateDistance(); // Calculate distance whenever preloader data updates
        setState(() {});
      }
    });

    // Initial distance calculation
    _calculateDistance();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    // 4. Remove the listener to prevent memory leaks
    super.dispose();
  }

  // New function to calculate the distance
  void _calculateDistance() {
    final currentLocation = widget.preloader.currentLocation;
    final destination = widget.preloader.destination;

    if (currentLocation != null) {
      const distance = Distance();
      // Calculate distance in meters, then convert to kilometers
      final double meters = distance(currentLocation, destination);
      _distanceInKm = meters / 1000.0;
    } else {
      _distanceInKm = 0.0;
    }
  }

  // Helper function to animate map movement
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    // Create Animation Controllers and Tween
    final latTween = Tween<double>(begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    // Create an AnimationController for the smooth transition
    final controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Create an animation that drives the map camera update
    final animation = CurvedAnimation(parent: controller, curve: Curves.easeInOut);

    controller.addListener(() {
      _mapController.move(
        LatLng(
          latTween.evaluate(animation),
          lngTween.evaluate(animation),
        ),
        zoomTween.evaluate(animation),
      );
    });

    // Start the animation and dispose of the controller when done
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout Confirmation'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // 5. Call dispose on the preloader to cancel its subscription
      widget.preloader.dispose();
      await auth.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  // FIX: This method is now updated to pass the map interaction callback
  void _showDeviceSettings() {
    _rotationController.forward();

    
    
    // 1. Define the callback function that the modal will use
    void handleLocationSelected(double lat, double lng) {
      final newLocation = LatLng(lat, lng);

      // 2. Animate the map to the selected history location
      _animatedMapMove(newLocation, 16.0);
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 1000),
      builder: (context) {
        // 3. Pass the callback function to the modal sheet
        return BottomModalSheet(
          preloader: widget.preloader,
          onLocationSelected: handleLocationSelected, // Pass the function here
        );
      },
    ).whenComplete(() {
      _rotationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 6. Access the data directly from the preloader instance
    final userData = widget.preloader.userData;
    final currentLocation = widget.preloader.currentLocation;
    final routePoints = widget.preloader.routePoints;
    final destination = widget.preloader.destination;
    
    // Format the distance for display
    final distanceText = _distanceInKm > 0
        ? "${_distanceInKm.toStringAsFixed(1)} km"
        : "N/A";

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 50,
 
        title: Image.asset(
          'assets/images/tamagotchu_brandname.png',
          // Must reduce the image height to fit within the 50px toolbarHeight
          height: 70, 
        ),
        
        // 3. Add the margin BELOW the AppBar title area
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10.0), // The size of the margin/gap (e.g., 10px)
          child: Container(), // An empty container to create the space
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: currentLocation == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Fetching location data..."),
                ],
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: currentLocation,
                    initialZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'dev.fleaflet.flutter_map.example',
                    ),
                    if (routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            color: Colors.red,
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                    CurrentLocationLayer(
                      style: const LocationMarkerStyle(
                        marker: DefaultLocationMarker(child: Icon(Icons.my_location, color: Colors.blue)),
                        markerSize: Size(30, 30),
                        markerDirection: MarkerDirection.heading,
                      ),
                    ),
                    // Only show destination marker if it's set
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: destination,
                          width: 35,
                          height: 35,
                          child: const Icon(
                            Icons.location_on, // Changed icon for a better destination representation
                            color: Colors.red,
                            size: 35,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Display the Distance on the Map
                Positioned(
                  top: 10,
                  left: 10,
                  child: Card(
                    color: Colors.white.withOpacity(0.9),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.route, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Distance: $distanceText',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDeviceSettings,
        backgroundColor: Colors.lightBlueAccent,
        shape: const CircleBorder(),
        child: AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value * 2.0 * pi,
              child: const Icon(Icons.settings, size: 32, color: Colors.white),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}