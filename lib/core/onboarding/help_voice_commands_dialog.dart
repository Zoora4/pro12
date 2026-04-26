// help_voice_commands_dialog.dart

import 'package:flutter/material.dart';
import 'package:pro12/services/voice_command_service.dart';
import '../../services/piper_tts_service.dart';

// ── Command data ──────────────────────────────────────────────
class _CommandGroup {
  final String category;
  final String description;
  final IconData icon;
  final List<_Command> commands;
  const _CommandGroup(this.category, this.description, this.icon, this.commands);
}

class _Command {
  final String keyword;
  final String explanation;
  const _Command(this.keyword, this.explanation);
}

const _groups = [
  _CommandGroup(
    'Open this screen',
    'Say these anytime to see voice commands',
    Icons.help_outline,
    [
      _Command('keywords',      'Opens this voice commands help screen and reads all available commands aloud.'),
      _Command('commands',      'Opens this voice commands help screen and reads all available commands aloud.'),
      _Command('show commands', 'Opens this voice commands help screen and reads all available commands aloud.'),
      _Command('list commands', 'Opens this voice commands help screen and reads all available commands aloud.'),
      _Command('help commands', 'Opens this voice commands help screen and reads all available commands aloud.'),
    ],
  ),
  _CommandGroup(
    'Playback',
    'Control reading',
    Icons.play_circle_outline,
    [
      _Command('play',   'Starts playing the document from where you left off.'),
      _Command('start',  'Starts playing the document from the beginning.'),
      _Command('resume', 'Resumes reading after a pause.'),
      _Command('read',   'Reads the document, or reads your highlighted selection if text is selected.'),

      _Command('stop',   'Stops reading completely and resets the position.'),
    ],
  ),
  _CommandGroup(
    'Navigation',
    'Open screens',
    Icons.navigation_outlined,
    [
      _Command('camera',   'Opens the camera so you can scan a physical document.'),
      _Command('photo',    'Opens the camera so you can take a photo of a document.'),
      _Command('take',     'Opens the camera to capture a document.'),
      _Command('capture',  'Opens the camera to capture a document.'),
      _Command('document', 'Opens the file picker to upload a document from your device.'),
      _Command('file',     'Opens the file picker to choose a file.'),
    ],
  ),
  _CommandGroup(
    'Voice settings',
    'Change voice',
    Icons.record_voice_over_outlined,
    [
      _Command('voice',  'Opens the voice selection menu to change the reading voice.'),
      _Command('switch', 'Opens the voice selection menu to switch voices.'),
      _Command('change', 'Opens the voice selection menu to change voices.'),
    ],
  ),
  _CommandGroup(
    'Dialog control',
    'Close popups by voice',
    Icons.close_outlined,
    [
      _Command('close', 'Closes or dismisses any open dialog or popup.'),
      _Command('back',  'Goes back or dismisses the current dialog.'),
    ],
  ),
];

// ── Sentence list for fast ping-pong loop ─────────────────────
List<String> _buildSentences() {
  return [
    'Here are all the available voice commands for Readify.',
    'To open this screen by voice, say: keywords, commands, or show commands.',
    'Playback commands.',
    'Say play or start, to begin reading.',
    'Say resume, to continue after a pause.',
    'Say read, to read the document or your highlighted selection.',
    'Say pause, to pause reading.',
    'Say stop, to stop reading completely.',
    'Navigation commands.',
    'Say camera, photo, take, or capture, to open the camera.',
    'Say document, upload, or file, to open the file picker.',
    'Voice setting commands.',
    'Say voice, switch, or change, to open the voice selection menu.',
    'Dialog commands.',
    'Say close or back, to dismiss any open dialog.',
    'Tip: tap any keyword on screen to hear what it does.',
  ];
}

// ── Public show function ──────────────────────────────────────
Future<void> showVoiceCommandsHelp(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _VoiceCommandsDialog(),
  );
}

// ── Register voice triggers ───────────────────────────────────
void registerVoiceCommandsKeywords(BuildContext context) {
  const triggers = [
    'KEYWORDS',
    'KEYWORD',
    'COMMANDS',
    'COMMAND',
    'KEY',
    'SHOW COMMANDS',
    'SHOW KEYWORDS',
    'HELP COMMANDS',
    'LIST COMMANDS',
    'LIST KEYWORDS',
  ];

  for (final trigger in triggers) {
    VoiceCommandService.instance.registerCommand(trigger, () {
      if (context.mounted) showVoiceCommandsHelp(context);
    });
  }
}

// ── Dialog ────────────────────────────────────────────────────
class _VoiceCommandsDialog extends StatefulWidget {
  const _VoiceCommandsDialog();

  @override
  State<_VoiceCommandsDialog> createState() => _VoiceCommandsDialogState();
}

class _VoiceCommandsDialogState extends State<_VoiceCommandsDialog> {
  String? _activeKeyword;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakAll());
  }

  Future<void> _speakAll() async {
    await PiperTtsService().stopLoop();
    if (!mounted) return;
    setState(() => _activeKeyword = null);

    await PiperTtsService().startLoop(
      sentences: _buildSentences(),
      startIndex: 0,
      speedGetter: () => 1.0,
      onSentenceChanged: (_) {},
      onFinished: (_) {},
    );
  }

  Future<void> _speakKeyword(_Command command) async {
    await PiperTtsService().stopLoop();
    if (!mounted) return;
    setState(() => _activeKeyword = command.keyword);

    await PiperTtsService().startLoop(
      sentences: [
        'Say ${command.keyword}.',
        command.explanation,
      ],
      startIndex: 0,
      speedGetter: () => 1.0,
      onSentenceChanged: (_) {},
      onFinished: (_) {
        if (mounted) setState(() => _activeKeyword = null);
      },
    );
  }

  @override
  void dispose() {
    PiperTtsService().resetLoopState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      title: Row(
        children: [
          const Icon(Icons.record_voice_over_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Voice commands', style: theme.textTheme.titleMedium),
                Text(
                  'Tap any keyword to hear what it does',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),

              // ── Replay all button ───────────────────────────
              OutlinedButton.icon(
                onPressed: _speakAll,
                icon: const Icon(Icons.volume_up_outlined, size: 18),
                label: const Text('Replay all commands'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),

              const SizedBox(height: 20),

              // ── Groups ──────────────────────────────────────
              ..._groups.map((g) => _GroupSection(
                    group: g,
                    activeKeyword: _activeKeyword,
                    onTap: _speakKeyword,
                  )),

              const SizedBox(height: 12),

              // ── Tip ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                        color: colorScheme.secondary, width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 15, color: colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Say "read" while text is highlighted to read only your selection.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// ── Group section ─────────────────────────────────────────────
class _GroupSection extends StatelessWidget {
  final _CommandGroup group;
  final String? activeKeyword;
  final void Function(_Command) onTap;

  const _GroupSection({
    required this.group,
    required this.activeKeyword,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon,
                  size: 15,
                  color: colorScheme.onSurface.withOpacity(0.6)),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: group.category,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: '  ·  ${group.description}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: group.commands
                .map((cmd) => _KeywordChip(
                      command: cmd,
                      isActive: activeKeyword == cmd.keyword,
                      onTap: () => onTap(cmd),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Tappable keyword chip ─────────────────────────────────────
class _KeywordChip extends StatelessWidget {
  final _Command command;
  final bool isActive;
  final VoidCallback onTap;

  const _KeywordChip({
    required this.command,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primary
              : colorScheme.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) ...[
              Icon(Icons.volume_up, size: 13, color: colorScheme.onPrimary),
              const SizedBox(width: 5),
            ],
            Text(
              command.keyword,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isActive
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}