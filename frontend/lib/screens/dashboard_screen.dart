import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/nova_daemon_client.dart';

class NovaMessage {
  const NovaMessage({
    required this.sender,
    required this.text,
    required this.time,
    this.isUser = false,
  });

  final String sender;
  final String text;
  final String time;
  final bool isUser;
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  late final AnimationController _orbController;
  late final Timer _statsTimer;
  final NovaDaemonClient _daemon = NovaDaemonClient();
  StreamSubscription<NovaDaemonEvent>? _daemonSub;

  double _cpu = 0.18;
  double _ram = 0.42;
  double _disk = 0.31;
  double _battery = 0.86;
  bool _listening = true;
  bool _daemonOnline = false;
  bool _ollamaAvailable = true;
  String _ollamaModel = 'llama3.2:1b';

  final List<NovaMessage> _messages = [
    const NovaMessage(
      sender: 'NOVA',
      text:
          'Hello, I am NOVA. Local companion mode is online. Voice, memory, automation, and training systems are ready for desktop integration.',
      time: 'now',
    ),
  ];

  final List<String> _memories = [
    'Prefers concise answers first, then deeper options.',
    'Primary model: llama3.2:1b via Ollama.',
    'Desktop app should replace the browser shell.',
  ];

  final List<String> _workflows = [
    'Local Ollama chat pipeline',
    'Safe desktop app launcher',
    'Document generation engine',
  ];

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_daemonOnline) return;
      final drift = math.Random();
      setState(() {
        _cpu = (0.12 + drift.nextDouble() * 0.22).clamp(0.0, 1.0).toDouble();
        _ram = (0.38 + drift.nextDouble() * 0.12).clamp(0.0, 1.0).toDouble();
        _disk = (0.30 + drift.nextDouble() * 0.03).clamp(0.0, 1.0).toDouble();
        _battery = (0.84 + drift.nextDouble() * 0.05).clamp(0.0, 1.0).toDouble();
      });
    });

    _connectDaemon();
  }

  @override
  void dispose() {
    _statsTimer.cancel();
    _daemonSub?.cancel();
    _daemon.dispose();
    _orbController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _connectDaemon() async {
    _daemonSub = _daemon.events.listen(_handleDaemonEvent);
    await _daemon.connect();
    if (mounted) {
      setState(() => _daemonOnline = _daemon.isConnected);
    }
  }

  void _handleDaemonEvent(NovaDaemonEvent event) {
    if (!mounted) return;

    if (event.type == 'welcome') {
      setState(() {
        _daemonOnline = true;
        _ollamaAvailable = event.data['ollama_available'] == true;
        _ollamaModel = event.data['ollama_model']?.toString() ?? _ollamaModel;
      });
      return;
    }

    if (event.type == 'system_stats') {
      setState(() {
        _daemonOnline = true;
        _cpu = _percent(event.data['cpu_percent']);
        _ram = _percent(event.data['ram_percent']);
        _disk = _percent(event.data['disk_percent']);
        _battery = _percent(event.data['battery_percent']);
      });
      return;
    }

    if (event.type == 'assistant_response') {
      final text = event.data['text']?.toString();
      if (text == null || text.isEmpty) return;
      setState(() {
        _daemonOnline = true;
        _messages.add(NovaMessage(sender: 'NOVA', text: text, time: 'daemon'));
      });
      return;
    }

    if (event.type == 'assistant_stream' && event.data['done'] == true) {
      final text = event.data['text']?.toString();
      if (text == null || text.isEmpty) return;
      setState(() {
        _daemonOnline = true;
        _messages.add(NovaMessage(sender: 'NOVA', text: text, time: 'ollama'));
      });
    }
  }

  double _percent(dynamic value) {
    if (value is num) return (value / 100).clamp(0.0, 1.0).toDouble();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF040A0F), Color(0xFF020409)],
          ),
          border: Border.all(color: const Color(0x3327DFFF)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0xAA000000),
              blurRadius: 36,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: Stack(
          children: [
            const _GridBackdrop(),
            Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    child: Row(
                      children: [
                        SizedBox(width: 300, child: _buildLeftRail()),
                        const SizedBox(width: 16),
                        Expanded(flex: 7, child: _buildCenterStage()),
                        const SizedBox(width: 16),
                        SizedBox(width: 360, child: _buildRightRail()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Row(
            children: [
              const Text(
                'N.O.V.A.',
                style: TextStyle(
                  color: Color(0xFF86F7FF),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(width: 10),
              _statusPill(
                _daemonOnline ? 'DAEMON ONLINE' : 'UI LOCAL',
                _daemonOnline ? const Color(0xFF40FFB0) : const Color(0xFFFFB545),
              ),
            ],
          ),
          const Spacer(),
          _topMetric(LucideIcons.clock3, '21:52:17', 'PM'),
          const SizedBox(width: 12),
          _topMetric(LucideIcons.cloudSun, '25.2 C', 'Kochi'),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Minimize to orb',
            onPressed: () => Navigator.pushReplacementNamed(context, '/orb'),
            icon: const Icon(LucideIcons.minimize2, color: Color(0xFF9DEFFF)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftRail() {
    return ListView(
      children: [
        _panel(
          title: 'System Analytics',
          icon: LucideIcons.activity,
          child: Column(
            children: [
              _meter('CPU Engine', _cpu, 'Ryzen local runtime'),
              _meter('Memory', _ram, 'Adaptive context buffer'),
              _meter('Disk', _disk, 'Workspace vault'),
              _meter('Battery', _battery, 'Power monitor'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Train NOVA',
          icon: LucideIcons.uploadCloud,
          child: Column(
            children: [
              _trainAction(LucideIcons.fileText, 'Upload PDFs / DOCX'),
              _trainAction(LucideIcons.globe2, 'Add website knowledge'),
              _trainAction(LucideIcons.workflow, 'Teach workflow'),
              _trainAction(LucideIcons.shieldCheck, 'Add private rules'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Memory Timeline',
          icon: LucideIcons.brain,
          child: Column(
            children: _memories.map(_memoryTile).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCenterStage() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildOrb(),
                    const SizedBox(height: 28),
                    const Text(
                      'N.O.V.A.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5,
                      ),
                    ),
                    const SizedBox(height: 8),
              _statusPill(
                      _listening
                          ? (_daemonOnline ? 'Daemon listening bridge ready' : 'Listening UI ready')
                          : 'Voice paused',
                      _listening
                          ? const Color(0xFF4AF5FF)
                          : const Color(0xFFFFB545),
                    ),
                    const SizedBox(height: 42),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _orbControl(LucideIcons.camera, 'Vision'),
                        const SizedBox(width: 18),
                        _orbControl(
                          _listening ? LucideIcons.mic : LucideIcons.micOff,
                          'Voice',
                          onPressed: () =>
                              setState(() => _listening = !_listening),
                        ),
                        const SizedBox(width: 18),
                        _orbControl(LucideIcons.keyboard, 'Type'),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: _panel(
                  title: 'Conversation',
                  icon: LucideIcons.messageSquare,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _miniButton('Clear'),
                      const SizedBox(width: 6),
                      _miniButton('Export'),
                    ],
                  ),
                  child: _buildConversation(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildPromptBar(),
      ],
    );
  }

  Widget _buildRightRail() {
    return ListView(
      children: [
        _panel(
          title: 'Internet Widgets',
          icon: LucideIcons.radio,
          child: Column(
            children: [
              _infoRow(LucideIcons.cloudSun, 'Weather', 'Kochi, 25.2 C'),
              _infoRow(LucideIcons.newspaper, 'News', 'Local summaries idle'),
              _infoRow(LucideIcons.search, 'Search', 'Mini browser ready'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Active Workflows',
          icon: LucideIcons.listChecks,
          child: Column(
            children: _workflows.map(_workflowTile).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Permission Engine',
          icon: LucideIcons.shield,
          child: Column(
            children: const [
              _SafetyLevel(label: 'Safe', value: 'Open apps, notes, weather'),
              _SafetyLevel(label: 'Medium', value: 'Downloads, browser drafts'),
              _SafetyLevel(label: 'Dangerous', value: 'Deletes, admin commands'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Local LLM Engine',
          icon: LucideIcons.cpu,
          child: _ollamaStatusCard(),
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Quick Automation',
          icon: LucideIcons.zap,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _quickChip('Open Notepad'),
              _quickChip('Create PDF'),
              _quickChip('Summarize Page'),
              _quickChip('Set Reminder'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrb() {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) {
        final pulse = 0.5 + math.sin(_orbController.value * math.pi * 2) * 0.5;
        return CustomPaint(
          painter: _OrbPainter(progress: _orbController.value, pulse: pulse),
          child: Container(
            width: 250,
            height: 250,
            alignment: Alignment.center,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF50F6FF), Color(0xFF0A3850)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF42F8FF).withOpacity(0.35 + pulse * 0.25),
                    blurRadius: 34,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    5,
                    (index) => Container(
                      width: 4,
                      height: 4.0 + (index.isEven ? 8.0 : 3.0),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversation() {
    return SizedBox(
      height: 485,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: _messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment:
                      message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 270),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message.isUser
                          ? const Color(0x2227DFFF)
                          : const Color(0x33103645),
                      border: Border.all(color: const Color(0x3348E8FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: const TextStyle(
                            color: Color(0xFFEAFBFF),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message.time,
                          style: const TextStyle(
                            color: Color(0xFF6EA7B7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x88050C12),
        border: Border.all(color: const Color(0x3327DFFF)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, color: Color(0xFF80F5FF), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _promptController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Type a message, command, workflow, or training rule...',
                hintStyle: TextStyle(color: Color(0xFF5F8390)),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _sendPrompt(),
            ),
          ),
          IconButton(
            tooltip: 'Send',
            onPressed: _sendPrompt,
            icon: const Icon(LucideIcons.send, color: Color(0xFF84F7FF)),
          ),
        ],
      ),
    );
  }

  void _sendPrompt() {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(NovaMessage(sender: 'You', text: text, time: 'now', isUser: true));
      _promptController.clear();
    });

    if (_daemonOnline) {
      _daemon.sendPrompt(text);
      return;
    }

    setState(() {
      _messages.add(
        const NovaMessage(
          sender: 'NOVA',
          text:
              'The desktop UI is running. Start the NOVA daemon to route this through memory, intent routing, tasks, and Ollama llama3.2:1b.',
          time: 'local',
        ),
      );
    });
  }

  Future<void> _openLaunchNovaBatch() async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '""', 'Launch_NOVA.bat']);
      } else {
        await Process.run('open', ['Launch_NOVA.bat']);
      }
      _showSnack('Attempted to open Launch_NOVA.bat');
    } catch (e) {
      _showSnack('Unable to open Launch_NOVA.bat: $e');
    }
  }

  Future<void> _openOllamaInstallPage() async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '""', 'https://ollama.ai']);
      } else {
        await Process.run('open', ['https://ollama.ai']);
      }
      _showSnack('Opened Ollama installation page.');
    } catch (e) {
      _showSnack('Unable to open install page: $e');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  Widget _ollamaStatusCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(LucideIcons.cpu, 'Model', _ollamaModel),
        const SizedBox(height: 8),
        Text(
          _ollamaAvailable
n              ? 'Local Ollama model ready and privacy-conscious.'
              : 'Ollama model unavailable. Launch NOVA or install the model.',
          style: TextStyle(
            color: _ollamaAvailable ? const Color(0xFF80FFB2) : const Color(0xFFFFB4A3),
            fontSize: 11,
          ),
        ),
        if (!_ollamaAvailable) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _openLaunchNovaBatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A4F82),
                  ),
                  child: const Text('Open Launch_NOVA.bat'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _openOllamaInstallPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6047BA),
                  ),
                  child: const Text('Install Ollama'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x99121D24),
        border: Border.all(color: const Color(0x2E3EE6FF)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x44000000), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF66ECFF), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFDDFBFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _meter(String label, double value, String caption) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFFBCECF5), fontSize: 11)),
              Text('${(value * 100).round()}%',
                  style: const TextStyle(color: Color(0xFF7EF6FF), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: const Color(0xFF0B2028),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF41E9FF)),
            ),
          ),
          const SizedBox(height: 4),
          Text(caption, style: const TextStyle(color: Color(0xFF587984), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _trainAction(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x3316303B),
        border: Border.all(color: const Color(0x1F79EFFF)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF75F3FF), size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFFC7F8FF), fontSize: 12)),
          ),
          const Icon(LucideIcons.plus, color: Color(0xFF5FEAFF), size: 14),
        ],
      ),
    );
  }

  Widget _memoryTile(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF42EDFF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFFAACFD8), fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _workflowTile(String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x2217E8FF),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x224DEBFF)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.loader2, color: Color(0xFF81F6FF), size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFFD9FBFF), fontSize: 12)),
          ),
          const Text('READY', style: TextStyle(color: Color(0xFF54FFB8), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF75F3FF), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFFE6FCFF), fontSize: 12)),
                Text(value, style: const TextStyle(color: Color(0xFF6F98A3), fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String label) {
    return ActionChip(
      label: Text(label),
      labelStyle: const TextStyle(color: Color(0xFFDFFBFF), fontSize: 11),
      backgroundColor: const Color(0x331A3540),
      side: const BorderSide(color: Color(0x334DEBFF)),
      onPressed: () {
        _promptController.text = label;
        _sendPrompt();
      },
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _topMetric(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x66101D24),
        border: Border.all(color: const Color(0x263BEAFF)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF83F6FF), size: 14),
          const SizedBox(width: 7),
          Text(value, style: const TextStyle(color: Color(0xFFDDFBFF), fontSize: 11)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Color(0xFF668C97), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _orbControl(IconData icon, String tooltip, {VoidCallback? onPressed}) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed ?? () {},
      icon: Icon(icon, color: const Color(0xFFD8FAFF), size: 18),
      style: IconButton.styleFrom(
        fixedSize: const Size(42, 42),
        backgroundColor: const Color(0x77111F27),
        side: const BorderSide(color: Color(0x334FEAFF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _miniButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x331A3540),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0x224DEBFF)),
      ),
      child: Text(label, style: const TextStyle(color: Color(0xFFA9F7FF), fontSize: 10)),
    );
  }
}

class _SafetyLevel extends StatelessWidget {
  const _SafetyLevel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF7EF6FF), fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Color(0xFFAAD1DA), fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _GridBackdrop extends StatelessWidget {
  const _GridBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0E48E8FF)
      ..strokeWidth = 1;
    const gap = 42.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter({required this.progress, required this.pulse});

  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x8849EFFF);

    for (int i = 0; i < 4; i++) {
      final radius = 58.0 + i * 24.0 + pulse * 3.0;
      canvas.drawCircle(center, radius, basePaint..color = Color.lerp(const Color(0x3349EFFF), const Color(0xAA49EFFF), i / 5)!);
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF61F2FF);

    for (int i = 0; i < 3; i++) {
      final radius = 72.0 + i * 29.0;
      final start = progress * math.pi * 2 + i * 0.8;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.pi * (0.35 + i * 0.08),
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pulse != pulse;
  }
}
