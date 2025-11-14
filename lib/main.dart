import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:dynamic_color/dynamic_color.dart';

void main() {
  runApp(const LensLightApp());
}

class LensLightApp extends StatelessWidget {
  const LensLightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          // Use dynamic colors from the system
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          // Fallback to default colors
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
            dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
          );
        }

        return MaterialApp(
          title: 'LunaBeam',
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
          ),
          themeMode: ThemeMode.system,
          home: const LensLightScreen(),
        );
      },
    );
  }
}

class LensLightScreen extends StatefulWidget {
  const LensLightScreen({super.key});

  @override
  State<LensLightScreen> createState() => _LensLightScreenState();
}

class _LensLightScreenState extends State<LensLightScreen> {
  bool _isLightOn = false;
  double _brightness = 50.0;
  double _originalBrightness = 0.5;
  Color _lightColor = Colors.white;
  
  @override
  void initState() {
    super.initState();
    _loadBrightness();
    _saveOriginalBrightness();
  }

  Future<void> _saveOriginalBrightness() async {
    try {
      _originalBrightness = await ScreenBrightness().current;
    } catch (e) {
      _originalBrightness = 0.5;
    }
  }

  Future<void> _loadBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _brightness = prefs.getDouble('brightness') ?? 50.0;
      final colorValue = prefs.getInt('lightColor') ?? Colors.white.value;
      _lightColor = Color(colorValue);
    });
  }

  Future<void> _saveBrightness(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('brightness', value);
  }

  Future<void> _saveColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lightColor', color.value);
  }

  Future<void> _toggleLight() async {
    setState(() {
      _isLightOn = !_isLightOn;
    });
    
    if (_isLightOn) {
      // Turn on: set brightness, keep screen awake, and hide system UI
      await ScreenBrightness().setScreenBrightness(_brightness / 100);
      await WakelockPlus.enable();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // Turn off: restore original brightness, allow sleep, and show system UI
      await ScreenBrightness().setScreenBrightness(_originalBrightness);
      await WakelockPlus.disable();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _updateBrightness(double value) async {
    setState(() {
      _brightness = value;
    });
    await _saveBrightness(value);
    
    // Update brightness if light is on
    if (_isLightOn) {
      await ScreenBrightness().setScreenBrightness(value / 100);
    }
  }

  @override
  void dispose() {
    if (_isLightOn) {
      ScreenBrightness().setScreenBrightness(_originalBrightness);
      WakelockPlus.disable();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: _isLightOn ? Colors.black : theme.colorScheme.surface,
      body: _isLightOn ? _buildLightOnView(theme) : SafeArea(
        child: _buildControlView(theme),
      ),
    );
  }

  Widget _buildLightOnView(ThemeData theme) {
    return GestureDetector(
      onTapDown: (details) {
        // Calculate center of screen
        final RenderBox box = context.findRenderObject() as RenderBox;
        final size = box.size;
        final center = Offset(size.width / 2, size.height / 2);
        
        // Check if tap is within 75 pixel radius of center
        final distance = (details.localPosition - center).distance;
        if (distance <= 75) {
          _toggleLight();
        }
      },
      child: Container(
        color: Colors.black,
        child: Center(
          child: CustomPaint(
            size: Size.infinite,
            painter: CircleLightPainter(
              brightness: _brightness / 100,
              color: _lightColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlView(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              Text(
                'LunaBeam',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            
            const SizedBox(height: 16),
            
            Text(
              'Soft light for scleral lens insertion',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 48),
            
            // Light Toggle Button
            GestureDetector(
              onTap: _toggleLight,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primaryContainer,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 70,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'OFF',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Brightness Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      'Brightness',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Text(
                      '${_brightness.toInt()}%',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Slider(
                      value: _brightness,
                      min: 5,
                      max: 100,
                      divisions: 19,
                      label: '${_brightness.toInt()}%',
                      onChanged: (value) {
                        _updateBrightness(value);
                      },
                    ),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '5% (Dim)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '100% (Bright)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Color Picker
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      'Light Color',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildColorButton(Colors.white, 'White', theme),
                        _buildColorButton(Colors.red, 'Red', theme),
                        _buildColorButton(Colors.orange, 'Orange', theme),
                        _buildColorButton(Colors.yellow, 'Yellow', theme),
                        _buildColorButton(Colors.green, 'Green', theme),
                        _buildColorButton(Colors.blue, 'Blue', theme),
                        _buildColorButton(Colors.purple, 'Purple', theme),
                        _buildColorButton(Colors.pink, 'Pink', theme),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Info message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap the circle to turn off the light',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildColorButton(Color color, String label, ThemeData theme) {
    final isSelected = _lightColor.value == color.value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _lightColor = color;
        });
        _saveColor(color);
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : Colors.grey,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class CircleLightPainter extends CustomPainter {
  final double brightness;
  final Color color;
  
  CircleLightPainter({required this.brightness, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.lerp(Colors.black, color, brightness)!
      ..style = PaintingStyle.fill;
    
    // Draw a circle with 2cm radius (approximately 75 pixels at typical phone DPI)
    // Using 75 pixels as radius for approximately 2cm on most phones
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 75, paint);
  }
  
  @override
  bool shouldRepaint(CircleLightPainter oldDelegate) {
    return oldDelegate.brightness != brightness || oldDelegate.color != color;
  }
}
