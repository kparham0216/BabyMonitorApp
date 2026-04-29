import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';

// Default Pi's static IP address (can be changed in settings)
const piAddress = 'http://10.85.160.236:5000';

// Entry point: launches the Baby Monitor app
void main() => runApp(BabyMonitorApp());

/// The root widget for the Baby Monitor app.
/// Sets up the theme and home navigation.
class BabyMonitorApp extends StatelessWidget {
  const BabyMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baby Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF378ADD)),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const MainNavigation(),
    );
  }
}

// ── Main Navigation ─────────────────────────────────────────────────────────

/// Main navigation widget with bottom navigation bar for Live and History screens.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // Tracks selected tab (Live or History)
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const BabyMonitorScreen(),
    const HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart_outlined),
            label: 'Live',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

// ── History Screen ──────────────────────────────────────────────────────────

/// Screen for displaying historical vitals data (1, 6, 12, 24 hours).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // State for selected time window, loading, error, and vitals data
  int _selectedHours = 1;
  bool _loading = false;
  String? _error;
  List<double> _bpm = [];
  List<double> _spo2 = [];
  List<double> _temp = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Starts periodic polling for history data
  void _startTimer() {
    _timer?.cancel();
    Duration interval;
    // switch (_selectedHours) {
    //   case 1:
    //     interval = const Duration(seconds: 15);
    //     break;
    //   case 6:
    //     interval = const Duration(seconds: 75);
    //     break;
    //   case 12:
    //     interval = const Duration(seconds: 150);
    //     break;
    //   case 24:
    //     interval = const Duration(seconds: 300);
    //     break;
    //   default:
    //     interval = const Duration(seconds: 15);
    // }
    interval = const Duration(seconds: 15);
    _timer = Timer.periodic(interval, (_) => _fetchHistory());
  }

  /// Fetches historical data from the Pi for the selected time window
  Future<void> _fetchHistory() async {
    String endpoint;
    switch (_selectedHours) {
      case 1:
        endpoint = '/one_hr_data';
        break;
      case 6:
        endpoint = '/six_hr_data';
        break;
      case 12:
        endpoint = '/twelve_hr_data';
        break;
      case 24:
        endpoint = '/twenty_four_hr_data';
        break;
      default:
        endpoint = '/one_hr_data';
    }
    try {
      final response = await http.get(Uri.parse('$piAddress$endpoint'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _bpm = (data['bpm'] as List).map((e) => (e as num).toDouble()).toList();
          _spo2 = (data['spo2'] as List).map((e) => (e as num).toDouble()).toList();
          _temp = (data['temp'] as List).map((e) => (e as num).toDouble()).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load data (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load data';
        _loading = false;
      });
    }
  }

  /// Builds the hour selector chips
  Widget _buildSelector() {
    final options = [1, 6, 12, 24];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: options.map((h) {
        final selected = _selectedHours == h;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text('$h hr', style: TextStyle(fontWeight: FontWeight.w500)),
            selected: selected,
            onSelected: (v) {
              if (!selected) {
                setState(() {
                  _selectedHours = h;
                  _loading = true;
                });
                _fetchHistory();
                _startTimer();
              }
            },
            selectedColor: const Color(0xFF378ADD),
            labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
            backgroundColor: Colors.grey[200],
          ),
        );
      }).toList(),
    );
  }

  /// Builds a chart for a single vital sign
  Widget _buildChart(String label, List<double> data, Color color, String unit) {
    if (data.isEmpty) return Container();
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.08), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: CustomPaint(
              painter: WavePainter(
                history: data,
                minVal: min,
                maxVal: max,
                color: color.withOpacity(0.7),
              ),
              size: Size(double.infinity, 80),
            ),
          ),
          SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Min: ${min.toStringAsFixed(1)}  Max: ${max.toStringAsFixed(1)} $unit', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F3),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text('History', style: TextStyle(color: Color(0xFF378ADD), fontWeight: FontWeight.w600)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            const SizedBox(height: 10),
            _buildSelector(),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (!_loading && _error == null)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildChart('Pulse (bpm)', _bpm, const Color(0xFFE24B4A), 'bpm'),
                    _buildChart('SpO₂ (%)', _spo2, const Color(0xFF378ADD), '%'),
                    _buildChart('Temp (°F)', _temp, const Color(0xFFEF9F27), '°F'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Data model ──────────────────────────────────────────────────────────────

/// Simple data model for a set of vitals
class VitalsData {
  double spo2;
  double pulse;
  double temp;

  VitalsData({required this.spo2, required this.pulse, required this.temp});
}

// ── Waveform painter ─────────────────────────────────────────────────────────

/// Custom painter for drawing a mini waveform for a vital sign
class WavePainter extends CustomPainter {
  final List<double> history;
  final double minVal;
  final double maxVal;
  final Color color;

  WavePainter({
    required this.history,
    required this.minVal,
    required this.maxVal,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final step = size.width / (history.length - 1);

    for (int i = 0; i < history.length; i++) {
      final x = i * step;
      final normalized = (history[i] - minVal) / (maxVal - minVal);
      final y = size.height - (normalized * size.height).clamp(0, size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => true;
}

// ── Trend chart painter ──────────────────────────────────────────────────────

/// Custom painter for the trend chart (last 60s) showing all three vitals
class TrendPainter extends CustomPainter {
  final List<double> spo2History;
  final List<double> pulseHistory;
  final List<double> tempHistory;

  TrendPainter({
    required this.spo2History,
    required this.pulseHistory,
    required this.tempHistory,
  });

    /// Draws a single line for a vital
    void _drawLine(Canvas canvas, Size size, List<double> history,
      double minVal, double maxVal, Color color) {
    if (history.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final step = size.width / (history.length - 1);
    final chartH = size.height - 12;

    for (int i = 0; i < history.length; i++) {
      final x = i * step;
      final norm = ((history[i] - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
      final y = 4 + chartH - norm * chartH;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draws a faint baseline
    // Baseline
    final linePaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 0.5;
    canvas.drawLine(
        Offset(0, size.height - 8), Offset(size.width, size.height - 8), linePaint);

    double spo2Min = spo2History.isNotEmpty ? spo2History.reduce((a, b) => a < b ? a : b) : 90;
    double spo2Max = spo2History.isNotEmpty ? spo2History.reduce((a, b) => a > b ? a : b) : 100;
    if (spo2Min == spo2Max) {
      spo2Min -= 1;
      spo2Max += 1;
    }
    double pulseMin = pulseHistory.isNotEmpty ? pulseHistory.reduce((a, b) => a < b ? a : b) : 80;
    double pulseMax = pulseHistory.isNotEmpty ? pulseHistory.reduce((a, b) => a > b ? a : b) : 180;
    if (pulseMin == pulseMax) {
      pulseMin -= 1;
      pulseMax += 1;
    }
    double tempMin = tempHistory.isNotEmpty ? tempHistory.reduce((a, b) => a < b ? a : b) : 96;
    double tempMax = tempHistory.isNotEmpty ? tempHistory.reduce((a, b) => a > b ? a : b) : 102;
    if (tempMin == tempMax) {
      tempMin -= 1;
      tempMax += 1;
    }
    _drawLine(canvas, size, spo2History, spo2Min, spo2Max, const Color(0xFF378ADD));
    _drawLine(canvas, size, pulseHistory, pulseMin, pulseMax, const Color(0xFFE24B4A));
    _drawLine(canvas, size, tempHistory, tempMin, tempMax, const Color(0xFFEF9F27));
  }

  @override
  bool shouldRepaint(TrendPainter oldDelegate) => true;
}

// ── Main screen ──────────────────────────────────────────────────────────────

/// Main screen for live monitoring of vitals
class BabyMonitorScreen extends StatefulWidget {
  const BabyMonitorScreen({super.key});

  @override
  State<BabyMonitorScreen> createState() => _BabyMonitorScreenState();
}

    with SingleTickerProviderStateMixin {
  // Timer for polling, animation controller for live indicator
  Timer? _timer;
  late AnimationController _dotController;

  double _spo2 = 98.0;
  double _pulse = 128.0;
  double _temp = 98.6;

  final List<double> _spo2History = [];
  final List<double> _pulseHistory = [];
  final List<double> _tempHistory = [];

  int _alertCount = 0;
  String _alertText = '';
  bool _hasAlert = false;
  late DateTime _startTime;
  String _timestamp = '';
  String _sinceDuration = '';

  // Editable fields (user can change in settings)
  String _age = '3 months';
  String _weight = '12.4 lbs';
  String _piAddress = piAddress;
  /// Opens the settings dialog for Pi IP, age, and weight
  void _openSettingsDialog() async {
    final ipController = TextEditingController(text: _piAddress);
    final ageController = TextEditingController(text: _age);
    final weightController = TextEditingController(text: _weight);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipController,
                decoration: const InputDecoration(labelText: 'Pi IP Address'),
              ),
              TextField(
                controller: ageController,
                decoration: const InputDecoration(labelText: 'Age'),
              ),
              TextField(
                controller: weightController,
                decoration: const InputDecoration(labelText: 'Weight'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'ip': ipController.text.trim(),
                  'age': ageController.text.trim(),
                  'weight': weightController.text.trim(),
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      setState(() {
        _piAddress = result['ip'] ?? _piAddress;
        _age = result['age'] ?? _age;
        _weight = result['weight'] ?? _weight;
      });
    }
  }

  // Track previous alert state for transition detection
  bool _wasSpo2Alert = false;
  bool _wasPulseAlert = false;
  bool _wasTempAlert = false;

  @override
  void initState() {
    // Initialize timers and animation
    super.initState();
    _startTime = DateTime.now();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fetchAndUpdate();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _fetchAndUpdate());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dotController.dispose();
    super.dispose();
  }

  /// Fetches latest data from the Pi and updates state
  Future<void> _fetchAndUpdate() async {
    final now = DateTime.now();
    final elapsed = now.difference(_startTime);
    final h = elapsed.inHours;
    final m = elapsed.inMinutes % 60;

    try {
      final response = await http.get(Uri.parse('$_piAddress/latest_data'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Expecting: {"bpm": 123, "spo2": 98, "temp": 98.6}
        final double spo2 = (data['spo2'] as num?)?.toDouble() ?? _spo2;
        final double pulse = (data['bpm'] as num?)?.toDouble() ?? _pulse;
        final double temp = (data['temp'] as num?)?.toDouble() ?? _temp;

        _spo2 = spo2;
        _pulse = pulse;
        _temp = temp;
      }
    } catch (e) {
      // If fetch fails, keep previous values
    }

    _spo2History.add(_spo2);
    _pulseHistory.add(_pulse);
    _tempHistory.add(_temp);
    if (_spo2History.length > 20) _spo2History.removeAt(0);
    if (_pulseHistory.length > 20) _pulseHistory.removeAt(0);
    if (_tempHistory.length > 20) _tempHistory.removeAt(0);

    // Track alert transitions
    bool spo2Alert = _spo2 < 94;
    bool pulseAlert = _pulse < 60 || _pulse > 100;
    bool tempAlert = _temp > 85;

    if (spo2Alert && !_wasSpo2Alert) _alertCount++;
    if (pulseAlert && !_wasPulseAlert) _alertCount++;
    if (tempAlert && !_wasTempAlert) _alertCount++;

    _wasSpo2Alert = spo2Alert;
    _wasPulseAlert = pulseAlert;
    _wasTempAlert = tempAlert;

    final alerts = <String>[];
    if (_spo2 < 94) alerts.add('Low SpO₂: ${_spo2.toStringAsFixed(0)}%');
    if (_pulse < 60 || _pulse > 100) alerts.add('Pulse out of range: ${_pulse.toStringAsFixed(0)} bpm');
    if (_temp > 85) alerts.add('Elevated temp: ${_temp.toStringAsFixed(1)}°F');

    setState(() {
      _timestamp =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      _sinceDuration = h > 0 ? '${h}h ${m}m ago' : '${m}m ago';
      _hasAlert = alerts.isNotEmpty;
      _alertText = alerts.join(' · ');
    });
  }

  /// Returns true if value is in the normal range
  bool _isNormal(double val, double min, double max) => val >= min && val <= max;

  @override
  Widget build(BuildContext context) {
    final spo2Normal = _isNormal(_spo2, 94, 100);
    final pulseNormal = _isNormal(_pulse, 60, 100);
    final tempNormal = _isNormal(_temp, 77, 85);

    // Calculate dynamic min/max for each vital (for waveform only)
    double _getMin(List<double> history, double fallback) {
      if (history.isEmpty) return fallback;
      final min = history.reduce((a, b) => a < b ? a : b);
      final max = history.reduce((a, b) => a > b ? a : b);
      return min == max ? min - 1 : min - ((max - min) * 0.1);
    }
    double _getMax(List<double> history, double fallback) {
      if (history.isEmpty) return fallback;
      final min = history.reduce((a, b) => a < b ? a : b);
      final max = history.reduce((a, b) => a > b ? a : b);
      return min == max ? max + 1 : max + ((max - min) * 0.1);
    }

    final spo2Min = _getMin(_spo2History, 90);
    final spo2Max = _getMax(_spo2History, 100);
    final pulseMin = _getMin(_pulseHistory, 80);
    final pulseMax = _getMax(_pulseHistory, 180);
    final tempMin = _getMin(_tempHistory, 96);
    final tempMax = _getMax(_tempHistory, 102);

    // Fixed bar fill ranges
    double spo2BarFill = ((_spo2 - 94) / 6).clamp(0.0, 1.0);    // 94-100 %
    double pulseBarFill = ((_pulse - 60) / 40).clamp(0.0, 1.0); // 60-100 bpm
    double tempBarFill = ((_temp - 77) / 8).clamp(0.0, 1.0);    // 77-85 °F

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Baby Monitor', style: TextStyle(color: Color(0xFF378ADD), fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF378ADD)),
            onPressed: _openSettingsDialog,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              if (_hasAlert) ...[
                _buildAlertBanner(),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: _VitalCard(
                      label: 'SpO₂',
                      value: _spo2.toStringAsFixed(0),
                      unit: '%',
                      accentColor: const Color(0xFF378ADD),
                      isNormal: spo2Normal,
                      rangeText: 'Normal: 94–100%',
                      barFill: spo2BarFill,
                      history: _spo2History,
                      minVal: spo2Min,
                      maxVal: spo2Max,
                      icon: Icons.water_drop_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _VitalCard(
                      label: 'Pulse',
                      value: _pulse.toStringAsFixed(0),
                      unit: 'bpm',
                      accentColor: const Color(0xFFE24B4A),
                      isNormal: pulseNormal,
                      rangeText: 'Normal: 60–100',
                      barFill: pulseBarFill,
                      history: _pulseHistory,
                      minVal: pulseMin,
                      maxVal: pulseMax,
                      icon: Icons.favorite_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _VitalCard(
                      label: 'Temp',
                      value: _temp.toStringAsFixed(1),
                      unit: '°F',
                      accentColor: const Color(0xFFEF9F27),
                      isNormal: tempNormal,
                      rangeText: 'Normal: 77–85°F',
                      barFill: tempBarFill,
                      history: _tempHistory,
                      minVal: tempMin,
                      maxVal: tempMax,
                      icon: Icons.thermostat_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildInfoCard()),
                ],
              ),
              const SizedBox(height: 12),
              _buildTrendCard(),
              const SizedBox(height: 12),
              Text(
                'Last updated $_timestamp',
                style: const TextStyle(fontSize: 11, color: Color(0xFF999990)),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFFE6F1FB),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.child_care, color: Color(0xFF378ADD), size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Baby Monitor',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              Text('Infant vitals — Nursery',
                  style: TextStyle(fontSize: 12, color: Color(0xFF888780))),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _dotController,
          builder: (context, _) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3DE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(const Color(0xFF639922),
                          const Color(0xFF639922).withOpacity(0.2), _dotController.value),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text('Live',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3B6D11))),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAEEDA),
        border: Border.all(color: const Color(0xFFFAC775), width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFBA7517)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _alertText,
              style: const TextStyle(fontSize: 12, color: Color(0xFFBA7517)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.08), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SESSION INFO',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: Color(0xFF888780),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          _infoRow('Age', _age),
          Divider(height: 1, thickness: 0.5, color: Colors.black.withOpacity(0.07)),
          _infoRow('Weight', _weight),
          Divider(height: 1, thickness: 0.5, color: Colors.black.withOpacity(0.07)),
          _infoRow('Monitoring since', _sinceDuration),
          Divider(height: 1, thickness: 0.5, color: Colors.black.withOpacity(0.07)),
          _infoRow('Alerts today', _alertCount.toString()),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {VoidCallback? onTap}) {
    final isEditable = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
          GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isEditable ? const Color(0xFF378ADD) : null)),
                if (isEditable)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.edit, size: 14, color: Color(0xFF378ADD)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editField(String label, String initialValue, ValueChanged<String> onSaved) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $label'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: label),
            onSubmitted: (val) => Navigator.of(context).pop(val),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (result != null && result.trim().isNotEmpty) {
      onSaved(result.trim());
    }
  }

  Widget _buildTrendCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.08), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LAST 60S TREND',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: Color(0xFF888780),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: CustomPaint(
              painter: TrendPainter(
                spo2History: _spo2History,
                pulseHistory: _pulseHistory,
                tempHistory: _tempHistory,
              ),
              size: const Size(double.infinity, 72),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(const Color(0xFF378ADD), 'SpO₂'),
              const SizedBox(width: 10),
              _legendDot(const Color(0xFFE24B4A), 'Pulse'),
              const SizedBox(width: 10),
              _legendDot(const Color(0xFFEF9F27), 'Temp'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 2, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }
}

// ── Vital card widget ────────────────────────────────────────────────────────

/// Card widget for displaying a single vital (SpO₂, Pulse, Temp)
class _VitalCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accentColor;
  final bool isNormal;
  final String rangeText;
  final double barFill;
  final List<double> history;
  final double minVal;
  final double maxVal;
  final IconData icon;

  const _VitalCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.accentColor,
    required this.isNormal,
    required this.rangeText,
    required this.barFill,
    required this.history,
    required this.minVal,
    required this.maxVal,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isNormal ? const Color(0xFF3B6D11) : const Color(0xFFBA7517);
    final statusBg = isNormal ? const Color(0xFFEAF3DE) : const Color(0xFFFAEEDA);
    final waveColor = accentColor.withOpacity(0.45);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.08), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent bar
          Container(
            height: 3,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Icon + status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: accentColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isNormal ? 'Normal' : 'Check',
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w500, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Label
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.5,
                  color: Color(0xFF888780),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          // Value
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2C2C2A),
                      height: 1.1),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF888780),
                      fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Range bar
          Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEDE8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: barFill,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(rangeText,
              style: const TextStyle(fontSize: 9, color: Color(0xFFB4B2A9))),
          const SizedBox(height: 6),
          // Mini waveform
          SizedBox(
            height: 22,
            child: CustomPaint(
              painter: WavePainter(
                history: history,
                minVal: minVal,
                maxVal: maxVal,
                color: waveColor,
              ),
              size: const Size(double.infinity, 22),
            ),
          ),
        ],
      ),
    );
  }
}
