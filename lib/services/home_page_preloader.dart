import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:tamagotchuuu/services/auth_service.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';

class HomePageDataPreloader with ChangeNotifier {
  Map<dynamic, dynamic> _userData = {};
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  LatLng? _destination;
  StreamSubscription? _userLocationSubscription;

  // -------------------------------------------------------------
  // MODIFIED: Fetches latest coordinates based ONLY on deviceId
  // -------------------------------------------------------------
  Future<void> updateDestinationByDeviceId(String deviceId) async {
    // 1. Define the query to get a RECENT set of entries for the device
    final locationHistoryRef = FirebaseDatabase.instance.ref('5/loc_history');

    // Query: Filter by device_id AND fetch the last 100 entries that match.
    Query query = locationHistoryRef
        .orderByChild('device_id')
        .equalTo(deviceId)
        .limitToLast(100); // Fetch a reasonable chunk of recent data

    try {
      final snapshot = await query.get();
      
      Map<dynamic, dynamic>? latestLoc;

      if (snapshot.children.isNotEmpty) {
        // 2. ⭐ CRITICAL FIX: Sort the fetched children by their Firebase Key.
        final sortedChildren = snapshot.children.toList()
            // CompareTo provides a robust string comparison to sort keys correctly.
            ..sort((a, b) => a.key!.compareTo(b.key!)); 

        // 3. Get the last element of the chronologically sorted list
        latestLoc = sortedChildren.last.value as Map<dynamic, dynamic>?;
      }
      
      // Safely extract the last child's value
      if (latestLoc != null) {
        // Data found for the active device
        final dynamic latValue = latestLoc['lat'];
        final dynamic lngValue = latestLoc['lng'];
        final double? lat = double.tryParse(latValue?.toString() ?? '');
        final double? lng = double.tryParse(lngValue?.toString() ?? '');

        if (lat != null && lng != null) {
          _destination = LatLng(lat, lng);
          if (kDebugMode) {
              print("Destination updated from lochistory: $lat, $lng (Device: $deviceId). Key: ${latestLoc.keys.first}");
          }
        } else {
          if (kDebugMode) {
            print("Latest lochistory entry has invalid lat/lng for device $deviceId. Using default coordinates.");
          }
          _destination = const LatLng(14.5203, 121.1546); // APHS coordinates
        }
      } else {
        if (kDebugMode) {
          print("No lochistory found for active device $deviceId. Using default coordinates.");
        }
        // Fallback to default coordinates
        _destination = const LatLng(14.5203, 121.1546); // APHS coordinates
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching lochistory for $deviceId: $e. Falling back to default coordinates.');
      }
      _destination = const LatLng(14.5203, 121.1546); // APHS coordinates
    }
    
    await _updateRoute(); // Recalculate route to the new destination
    notifyListeners();
  }
  
  // -------------------------------------------------------------
  // preloadData: Watches user data and triggers location update for the active device
  // -------------------------------------------------------------
  Future<void> preloadData() async {
    final auth = AuthService();
    final user = auth.currentUser;

    // 1. Request Notification Permissions first
    await _requestNotificationPermissions();

    if (user != null) {
      // 2. Update FCM Token now that permissions are (hopefully) granted
      await _updateFCMTokenInFirebase(user.uid);

      // Set up a listener for real-time user data changes
      final DatabaseReference userRef =
          FirebaseDatabase.instance.ref('5/registered_users/${user.uid}');
      await _userLocationSubscription?.cancel();

      _userLocationSubscription = userRef.onValue.listen((DatabaseEvent event) async {
        if (event.snapshot.exists) {
          _userData = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
          final String? activeDeviceId = _userData['device_id']?.toString();
          
          // Use the activeDeviceId selected from the device config page
          if (activeDeviceId != null && activeDeviceId.isNotEmpty) {
            await updateDestinationByDeviceId(activeDeviceId);
          } else {
            // Fallback if 'device_id' is missing/empty in user data
            if (kDebugMode) {
              print("User has no active device ID. Using default coordinates.");
            }
            _destination = const LatLng(14.5203, 121.1546); 
            await _updateRoute();
          }
        } else {
          if (kDebugMode) {
            print("User data does not exist. Using default coordinates.");
          }
          _destination = const LatLng(14.5203, 121.1546); // APHS coordinates
          await _updateRoute();
        }
        notifyListeners();
      });
    } else {
      _destination = const LatLng(14.5203, 121.1546);
      await _updateRoute();
      notifyListeners();
    }
  }

  // ⭐ NEW METHOD: Requests notification permissions from the user
  Future<void> _requestNotificationPermissions() async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      // Request permission for push notifications
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          print('User granted permission for notifications.');
        } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
          print('User granted provisional permission.');
        } else {
          print('User declined or has not yet granted permission.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting notification permissions: $e');
      }
    }
  }

  // Retrieve FCM token and save it to Firebase Realtime Database
  Future<void> _updateFCMTokenInFirebase(String uid) async {
    try {
      // 1. Get the current FCM token for this device
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        // 2. Define the exact path in Firebase
        final DatabaseReference tokenRef = FirebaseDatabase.instance.ref(
            '5/registered_users/$uid'); // Reference to the user's main node

        // 3. Update the node with a new key: 'token'
        await tokenRef.update({
          'token': fcmToken,
        });

        if (kDebugMode) {
          print('FCM Token successfully updated in Firebase: $fcmToken');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating FCM token in Firebase: $e');
      }
    }
  }
  
  // New method to handle getting location and fetching the route
  Future<void> _updateRoute() async {
    // 2. Get current location
    final location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final initialLocation = await location.getLocation();
    
    // Ensure both current location and destination are valid before requesting route
    if (initialLocation.latitude != null && initialLocation.longitude != null && _destination != null) {
      _currentLocation =
          LatLng(initialLocation.latitude!, initialLocation.longitude!);

      // 3. Get route from current location to the fetched destination
      final url =
          'http://router.project-osrm.org/route/v1/driving/${_currentLocation!.longitude},${_currentLocation!.latitude};${_destination!.longitude},${_destination!.latitude}?overview=full&geometries=geojson';
      
      // 

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final geometry = data['routes'][0]['geometry']['coordinates'] as List;
          _routePoints = geometry
              .map((coord) => LatLng(coord[1] as double, coord[0] as double))
              .toList();
        } else {
          if (kDebugMode) {
            print("OSRM route request failed with status code: ${response.statusCode}");
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error fetching route: $e");
        }
      }
    }
    notifyListeners();
  }

  Future<void> fetchUserData() async { 
    final auth = AuthService();
    final user = auth.currentUser;

    if (user != null) {
        final DatabaseReference userRef =
            FirebaseDatabase.instance.ref('5/registered_users/${user.uid}');

        try {
            final snapshot = await userRef.get();
            if (snapshot.exists) {
                // 1. Update the internal _userData map with the new data (including the updated device_id)
                _userData = snapshot.value as Map<dynamic, dynamic>? ?? {};
                final String? activeDeviceId = _userData['device_id']?.toString();
                
                if (kDebugMode) {
                    print("Preloader manually fetched user data. Active ID: $activeDeviceId");
                }

                if (activeDeviceId != null && activeDeviceId.isNotEmpty) {
                    // 2. Use the newly fetched active device ID to update the destination
                    await updateDestinationByDeviceId(activeDeviceId);
                } else {
                    // Fallback logic
                    _destination = const LatLng(14.5203, 121.1546); 
                    await _updateRoute();
                }
            }
        } catch (e) {
             if (kDebugMode) {
                 print("Error fetching user data manually: $e");
             }
        }
    }
    notifyListeners();
}

  // 4. Getters
  Map<dynamic, dynamic> get userData => _userData;
  LatLng? get currentLocation => _currentLocation;
  List<LatLng> get routePoints => _routePoints;
  // Ensure destination is never null when accessed publicly
  LatLng get destination => _destination ?? const LatLng(14.5203, 121.1546);

  // A method to cancel the subscription when it's no longer needed (e.g., on logout)
  @override
  void dispose() {
    _userLocationSubscription?.cancel();
    _userLocationSubscription = null;
    super.dispose();
  }
}