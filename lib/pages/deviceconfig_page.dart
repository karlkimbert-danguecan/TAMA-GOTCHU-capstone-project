import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tamagotchuuu/services/auth_service.dart';
import 'package:tamagotchuuu/services/home_page_preloader.dart';
import 'package:geocoding/geocoding.dart';

// --- NEW ADDITION: Data Structure for History Item ---
class LocationHistoryItem {
  final String key; // e.g., location_h1
  final double latitude;
  final double longitude;
  
  // Constructor parses lat/lng from string to double, handling nulls/errors
  LocationHistoryItem.fromMap(this.key, Map map)
      : latitude = double.tryParse(map['lat']?.toString() ?? '0.0') ?? 0.0,
        longitude = double.tryParse(map['lng']?.toString() ?? '0.0') ?? 0.0;
}
typedef LocationSelectCallback = void Function(double latitude, double longitude);

class BottomModalSheet extends StatefulWidget {
  final HomePageDataPreloader preloader;
  final LocationSelectCallback onLocationSelected; 

  const BottomModalSheet({
    super.key, 
    required this.preloader,
    required this.onLocationSelected,
  });

  @override
  State<BottomModalSheet> createState() => _BottomModalSheetState();
}

class _BottomModalSheetState extends State<BottomModalSheet>
    with SingleTickerProviderStateMixin {
  final _deviceIdController = TextEditingController();
  final _passkeyController = TextEditingController();
  final auth = AuthService();

  late TabController _tabController;
  String? _activeDeviceId;
  List<String> _availableDevices = [];
  String? _selectedDevice;

  List<LocationHistoryItem> _userLocationHistory = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.preloader.addListener(_updateUiFromPreloader);
    _initializeDeviceList();
    _fetchUserLocationHistory();
  }

  Future<void> _getAvailableDevices() async {
    final user = auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final currentActiveId = widget.preloader.userData['device_id']?.toString();
    _activeDeviceId = currentActiveId;

    final allDevicesRef = FirebaseDatabase.instance.ref('5/registered_devices');
    
    try {
      final allDevicesSnapshot = await allDevicesRef.get();
      final devicesMap = allDevicesSnapshot.value as Map<dynamic, dynamic>?;

      if (devicesMap != null) {
        final userDevices = <String>[];
        devicesMap.forEach((deviceId, data) {
          if (data is Map && data['user_id'] == uid) {
            userDevices.add(deviceId.toString());
          }
        });

        setState(() {
          _availableDevices = userDevices;
          if (_activeDeviceId != null && 
              _activeDeviceId!.isNotEmpty && 
              userDevices.contains(_activeDeviceId)) 
          {
            _selectedDevice = _activeDeviceId;
          } else if (userDevices.isNotEmpty) {
            _selectedDevice = userDevices.first; 
          } else {
            _selectedDevice = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching devices: $e');
    }
  }

  void _initializeDeviceList() => _getAvailableDevices();

  void _updateUiFromPreloader() {
    if (mounted && widget.preloader.userData.isNotEmpty) {
        _getAvailableDevices();
    }
  }

  Future<void> _fetchUserLocationHistory() async {
    final user = auth.currentUser;
    if (user == null) {
      setState(() => _userLocationHistory = []);
      return;
    }
    final uid = user.uid;
    final historyRef = FirebaseDatabase.instance.ref('5/loc_history');
    
    try {
      final snapshot = await historyRef.get();
      final historyMap = snapshot.value as Map<dynamic, dynamic>?;

      final List<LocationHistoryItem> historyList = [];

      if (historyMap != null) {
        historyMap.forEach((key, value) {
          if (value is Map && value['user_id'] == uid) {
            historyList.add(LocationHistoryItem.fromMap(key.toString(), value));
          }
        });
        historyList.sort((a, b) => a.key.compareTo(b.key));
      }

      if (mounted) {
        setState(() {
          _userLocationHistory = historyList.reversed.toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching user location history: $e');
      if (mounted) {
         setState(() => _userLocationHistory = []);
      }
    }
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _passkeyController.dispose();
    widget.preloader.removeListener(_updateUiFromPreloader);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addDevice() async {
    final user = auth.currentUser;
    final deviceId = _deviceIdController.text.trim();
    final passkey = _passkeyController.text.trim();

    if (_availableDevices.length >= 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have reached the maximum limit of 2 connected devices.'),
          ),
        );
      }
      return;
    }

    if (user == null || deviceId.isEmpty || passkey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter both Device ID and Passkey.'),
          ),
        );
      }
      return;
    }

    final deviceRef = FirebaseDatabase.instance
        .ref('5/registered_devices/$deviceId');
    final userDetailsRef = FirebaseDatabase.instance
        .ref('5/registered_users/${user.uid}');

    try {
      final deviceSnapshot = await deviceRef.get();
      final deviceData = deviceSnapshot.value as Map<dynamic, dynamic>?;

      if (deviceSnapshot.exists &&
          deviceData != null &&
          deviceData['passkey'] == passkey &&
          (deviceData['user_id'] == null || deviceData['user_id'] == '')) {
        final userDetailsSnapshot = await userDetailsRef.get();
        final userDetails =
            userDetailsSnapshot.value as Map<dynamic, dynamic>?;

        if (userDetails != null) {
          final fullName = userDetails['fname'] ?? 'N/A';
          await deviceRef.update({'user_id': user.uid, 'full_name': fullName});

          String deviceKey = 'device_id';
          if (_availableDevices.isNotEmpty) {
            deviceKey = 'device_id2';
          }
          await userDetailsRef.update({deviceKey: deviceId});

          if (deviceKey == 'device_id2') {
              await userDetailsRef.update({'device_id': deviceId});
              await widget.preloader.updateDestinationByDeviceId(deviceId);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Device $deviceId connected successfully! Saved as $deviceKey.'),
              ),
            );

            await _getAvailableDevices();
            await _fetchUserLocationHistory();
            _tabController.index = 1;
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User details not found.')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid Device ID, Passkey, or device is already in use.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _switchDevice(String? newDeviceId) async {
    if (newDeviceId == null) return;

    final user = auth.currentUser;
    if (user == null) return;

    final userDetailsRef = FirebaseDatabase.instance
        .ref('5/registered_users/${user.uid}');

    setState(() {
      _activeDeviceId = newDeviceId;
      _selectedDevice = newDeviceId;
    });

    try {
      await userDetailsRef.update({'device_id': newDeviceId});
      await widget.preloader.fetchUserData(); 
      await widget.preloader.updateDestinationByDeviceId(newDeviceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched active device to: $newDeviceId')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to switch device: $e')),
        );
      }
    }
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return [
          place.name,
          place.street,
          place.subLocality,
          place.locality,
          place.postalCode,
          place.country
        ].where((s) => s != null && s.isNotEmpty).join(', ');
      }
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
    }
    return 'Unknown location';
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        widget.preloader.userData.isEmpty && _availableDevices.isEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Text(
                    'Device Configuration',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'User Settings'),
                          Tab(text: 'Device & History'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 350,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildUserSettingsView(),
                            _buildDeviceAndHistoryView(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUserSettingsView() {
    String getDeviceLabel(String deviceId) {
      final index = _availableDevices.indexOf(deviceId);
      return index != -1 ? 'Device ${index + 1} ($deviceId)' : deviceId;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'User Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text('User ID: ${auth.currentUser?.uid ?? 'N/A'}'),
        Text(
          'Full Name: ${widget.preloader.userData['fname']?.toString() ?? 'N/A'}',
        ),
        const SizedBox(height: 30),
        const Text(
          'Active Device Selection',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _availableDevices.isEmpty
            ? const Text('No devices available. Please connect one using the Device & History tab.')
            : DropdownButtonFormField<String>(
                initialValue: _selectedDevice,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Switch Active Device',
                ),
                items: _availableDevices
                    .map((deviceId) => DropdownMenuItem(
                          value: deviceId,
                          child: Text(getDeviceLabel(deviceId)),
                        ))
                    .toList(),
                onChanged: _switchDevice,
              ),
      ],
    );
  }

  Widget _buildDeviceAndHistoryView() {
    final canConnectNewDevice = _availableDevices.length < 2;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Connected Devices',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_availableDevices.isNotEmpty)
            ..._availableDevices.map((deviceId) => _buildConnectedDeviceTile(deviceId)),
          if (_availableDevices.isEmpty)
            const Text('No devices are currently registered to your account.'),
          const SizedBox(height: 30),
          if (canConnectNewDevice) _buildInputForm(),
          if (!canConnectNewDevice)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Connect new device?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text('Max devices connected (2). Disconnect an existing one to add a new device.'),
              ],
            ),
          const SizedBox(height: 30),
          _buildUserLocationHistory(),
        ],
      ),
    );
  }

  Widget _buildConnectedDeviceTile(String deviceId) {
    final isCurrentlyActive = deviceId == _activeDeviceId;
    final index = _availableDevices.indexOf(deviceId);
    final label = index != -1 ? 'Device ID # ${index + 1}' : 'Device ID';
    final statusText = isCurrentlyActive ? 'Active' : 'Connected';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $deviceId', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(
            'Status: $statusText',
            style: TextStyle(
              fontSize: 14,
              color: isCurrentlyActive ? Colors.green : Colors.grey[700],
              fontWeight: isCurrentlyActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (index < _availableDevices.length - 1) Divider(height: 15, color: Colors.grey[300]),
        ],
      ),
    );
  }

  Widget _buildInputForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Connect new device?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _deviceIdController,
          decoration: const InputDecoration(
            labelText: 'Device ID',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passkeyController,
          decoration: const InputDecoration(
            labelText: 'Passkey',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _addDevice,
          child: const Text('Connect Device'),
        ),
      ],
    );
  }

  Widget _buildUserLocationHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('User Location History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_userLocationHistory.isEmpty)
          const Text('No location history found for your account.')
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _userLocationHistory.length,
              itemBuilder: (context, index) {
                final item = _userLocationHistory[index];
                return FutureBuilder<String>(
                  future: _getAddressFromCoordinates(item.latitude, item.longitude),
                  builder: (context, snapshot) {
                    final address = snapshot.data ?? 'Fetching nearby establishments...';

                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_pin, size: 20),
                      title: Text(
                        'Coords: ${item.latitude.toStringAsFixed(4)}, ${item.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(address),
                      onTap: () {
                        widget.onLocationSelected(item.latitude, item.longitude);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Map updated to history location.')),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}