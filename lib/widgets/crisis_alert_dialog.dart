import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CrisisAlertDialog extends StatelessWidget {
  final String message;
  final List<String> hotlines;

  const CrisisAlertDialog({
    super.key,
    required this.message,
    required this.hotlines,
  });

  static Future<void> show(BuildContext context, String message, List<String> hotlines) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CrisisAlertDialog(
        message: message,
        hotlines: hotlines,
      ),
    );
  }

  Future<void> _callHotline(String hotline) async {
    // Extract phone number from hotline string
    final phoneMatch = RegExp(r'(\d{3}-\d{3}-\d{4}|\d{10}|\d{3})').firstMatch(hotline);
    if (phoneMatch == null) return;
    
    final phone = phoneMatch.group(0)!.replaceAll('-', '');
    final uri = Uri.parse('tel:$phone');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _textCrisisLine() async {
    final uri = Uri.parse('sms:741741?body=HELLO');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1E293B).withOpacity(0.95),
                    const Color(0xFF0F172A).withOpacity(0.95),
                  ]
                : [
                    const Color(0xFFFEFEFE).withOpacity(0.98),
                    const Color(0xFFF8FAFC).withOpacity(0.98),
                  ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.red.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.red,
                size: 48,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Title
            Text(
              'We\'re Here for You',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // Message
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.onSurface.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Hotlines
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Immediate Help Available:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...hotlines.map((hotline) {
                    final isTextLine = hotline.toLowerCase().contains('text');
                    final is988 = hotline.contains('988');
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          if (isTextLine) {
                            _textCrisisLine();
                          } else {
                            _callHotline(hotline);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: is988 
                                ? Colors.red.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: is988
                                  ? Colors.red.withOpacity(0.3)
                                  : cs.outline.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isTextLine ? Icons.message_rounded : Icons.phone_rounded,
                                size: 20,
                                color: is988 ? Colors.red : cs.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  hotline,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: is988 ? FontWeight.w700 : FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: cs.onSurface.withOpacity(0.3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Reassurance
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_rounded, size: 16, color: cs.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are not alone. Help is available 24/7.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}