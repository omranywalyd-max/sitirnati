import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_buttons.dart';
import '../widgets/glass_surface.dart';

/// Full-screen map used to pin the driver's base point by tapping.
///
/// Returns the chosen [LatLng] through `Navigator.pop`, or `null` when the user
/// backs out. Tiles come from CARTO's dark basemap (OpenStreetMap data), which
/// keeps the map inside the app's dark palette without an API key.
class MapPickerPage extends StatefulWidget {
  /// Creates the map picker.
  const MapPickerPage({super.key, this.initial});

  /// Where the camera starts: the previously pinned point, or the city centre.
  final LatLng? initial;

  /// Algiers city centre, used the first time the map opens.
  static const algiersCentre = LatLng(36.7538, 3.0588);

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final MapController _mapController = MapController();

  LatLng? _pin;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _pin = widget.initial;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _pinTo(LatLng point) {
    setState(() => _pin = point);
  }

  /// Asks for the device position, moves the camera there and pins it.
  ///
  /// Every failure path ends in a sentence the user can act on: the map stays
  /// usable by tapping even when location is off or denied.
  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _tell('خدمة الموقع مطفية. شغّلها من إعدادات الهاتف، ولا حدد مكانك بصباعك.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _tell('ما عطاناش إذن الموقع. تقدر تحدد مكانك بالضغط على الخريطة.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      _mapController.move(point, 16);
      _pinTo(point);
    } catch (_) {
      _tell('ما قدرناش نلقاو موقعك. حدد مكانك بالضغط على الخريطة.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pin = _pin;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: pin ?? MapPickerPage.algiersCentre,
              initialZoom: pin == null ? 12.5 : 16,
              backgroundColor: AppColors.bgDeep,
              // Rotation is disabled: a rotated basemap makes a pinned point
              // hard to read back to the driver.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, point) => _pinTo(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.sitirnati.driver',
                maxZoom: 19,
              ),
              if (pin != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pin,
                      width: 52,
                      height: 52,
                      child: const _Pin(),
                    ),
                  ],
                ),
            ],
          ),

          // Top bar: back plus what to do.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: GlassSurface(
                  blur: AppGlass.sheetBlur,
                  radius: AppRadius.panel,
                  padding: const EdgeInsets.all(AppSpace.sm),
                  child: Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'رجوع',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('حدد موقعك', style: text.titleMedium),
                            Text(
                              'اضغط على الخريطة فين تكون متواجد عادة',
                              style: text.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom sheet: current pin, my-location shortcut, confirm.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: GlassSurface(
                  blur: AppGlass.sheetBlur,
                  radius: AppRadius.sheet,
                  tint: AppColors.surfaceSheet,
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            pin == null
                                ? Icons.touch_app_outlined
                                : Icons.place_rounded,
                            size: 20,
                            color: pin == null
                                ? AppColors.textFaint
                                : AppColors.accent,
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pin == null
                                      ? 'ما حددتش الموقع بعد'
                                      : 'الموقع المحدد',
                                  style: text.labelLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pin == null
                                      ? 'اضغط على الخريطة باش تحدد النقطة بدقة.'
                                      : formatLatLng(pin.latitude, pin.longitude),
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.md),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: _locating ? 'نقلب على موقعك' : 'موقعي الحالي',
                              icon: Icons.my_location_rounded,
                              onPressed: _locating ? null : _useMyLocation,
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            flex: 2,
                            child: PrimaryButton(
                              label: 'تأكيد الموقع',
                              onPressed:
                                  pin == null ? null : () => Navigator.of(context).pop(pin),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.sm),
                      const Text(
                        'الخريطة: بيانات © مساهمو OpenStreetMap، الصور © CARTO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textFaint,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dropped pin: an accent disc with a white core and a soft halo.
class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.6, end: 1),
        duration: AppMotion.standard,
        curve: Curves.easeOutBack,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: Center(
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF3F3F5), width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), blurRadius: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
