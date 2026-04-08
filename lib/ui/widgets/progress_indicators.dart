import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class AccessibleLinearProgressIndicator extends StatelessWidget {
  final double value;
  final double minHeight;
  final double? gap;
  final double? endDotSize;
  final Color? color;
  final Color? trackColor;
  final String? semanticsLabel;
  final String? semanticsValue;

  const AccessibleLinearProgressIndicator({
    super.key,
    required this.value,
    this.minHeight = 6,
    this.gap,
    this.endDotSize,
    this.color,
    this.trackColor,
    this.semanticsLabel,
    this.semanticsValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = color ?? theme.colorScheme.primary;
    final resolvedTrack =
        trackColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    final resolvedGap = gap ?? minHeight * 0.6;
    final resolvedEndDotSize = endDotSize ?? minHeight;
    final percent = (value.clamp(0, 1) * 100).round();

    return Semantics(
      label: semanticsLabel,
      value: semanticsValue ?? '$percent%',
      child: SizedBox(
        height: minHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, minHeight),
              painter: _LinearProgressPainter(
                value: value,
                minHeight: minHeight,
                gap: resolvedGap,
                endDotSize: resolvedEndDotSize,
                color: resolvedColor,
                trackColor: resolvedTrack,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LinearProgressPainter extends CustomPainter {
  final double value;
  final double minHeight;
  final double gap;
  final double endDotSize;
  final Color color;
  final Color trackColor;

  _LinearProgressPainter({
    required this.value,
    required this.minHeight,
    required this.gap,
    required this.endDotSize,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clamped = value.clamp(0.0, 1.0);
    final totalWidth = size.width;
    if (totalWidth <= 0) {
      return;
    }

    final radius = minHeight / 2;
    final endDotRadius = endDotSize / 2;
    final trackEnd = math.max(0.0, totalWidth - endDotRadius);
    final progressX = trackEnd * clamped;
    final gapHalf = gap / 2;

    double indicatorEnd = progressX - gapHalf;
    double trackStart = progressX + gapHalf;

    if (indicatorEnd <= 0) {
      indicatorEnd = 0;
      trackStart = 0;
    }

    if (trackStart >= trackEnd) {
      trackStart = trackEnd;
    }

    final indicatorPaint = Paint()..color = color;
    final trackPaint = Paint()..color = trackColor;

    if (indicatorEnd > 0) {
      final rect = Rect.fromLTWH(0, 0, indicatorEnd, minHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        indicatorPaint,
      );
    }

    if (trackEnd > trackStart) {
      final rect = Rect.fromLTWH(
        trackStart,
        0,
        trackEnd - trackStart,
        minHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        trackPaint,
      );
    }

    if (endDotRadius > 0) {
      final center = Offset(trackEnd, radius);
      canvas.drawCircle(center, endDotRadius, indicatorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinearProgressPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.minHeight != minHeight ||
        oldDelegate.gap != gap ||
        oldDelegate.endDotSize != endDotSize ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

class AccessibleCircularProgressIndicator extends StatelessWidget {
  final double? value;
  final double strokeWidth;
  final double size;
  final double gapAngle;
  final Color? color;
  final Color? trackColor;
  final String? semanticsLabel;
  final String? semanticsValue;

  const AccessibleCircularProgressIndicator({
    super.key,
    this.value,
    this.strokeWidth = 4,
    this.size = 48,
    this.gapAngle = math.pi / 10,
    this.color,
    this.trackColor,
    this.semanticsLabel,
    this.semanticsValue,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return AccessibleLoadingIndicator(
        size: size,
        color: color,
        semanticsLabel: semanticsLabel,
        semanticsValue: semanticsValue,
      );
    }

    final theme = Theme.of(context);
    final resolvedColor = color ?? theme.colorScheme.primary;
    final resolvedTrack =
        trackColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    final percent = (value!.clamp(0, 1) * 100).round();

    return Semantics(
      label: semanticsLabel,
      value: semanticsValue ?? '$percent%',
      child: CustomPaint(
        painter: _CircularProgressPainter(
          value: value!,
          strokeWidth: strokeWidth,
          gapAngle: gapAngle,
          color: resolvedColor,
          trackColor: resolvedTrack,
        ),
        child: SizedBox.square(dimension: size),
      ),
    );
  }
}

class AccessibleLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;
  final Duration duration;
  final String? semanticsLabel;
  final String? semanticsValue;

  const AccessibleLoadingIndicator({
    super.key,
    this.size = 48,
    this.color,
    this.duration = const Duration(milliseconds: 1200),
    this.semanticsLabel,
    this.semanticsValue,
  });

  @override
  State<AccessibleLoadingIndicator> createState() =>
      _AccessibleLoadingIndicatorState();
}

class _AccessibleLoadingIndicatorState extends State<AccessibleLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = widget.color ?? theme.colorScheme.primary;

    return Semantics(
      label: widget.semanticsLabel,
      value: widget.semanticsValue,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _LoadingIndicatorPainter(
              progress: _controller.value,
              color: resolvedColor,
            ),
            child: SizedBox.square(dimension: widget.size),
          );
        },
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double value;
  final double strokeWidth;
  final double gapAngle;
  final Color color;
  final Color trackColor;

  _CircularProgressPainter({
    required this.value,
    required this.strokeWidth,
    required this.gapAngle,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = math.min(size.width, size.height);
    if (shortestSide <= 0) {
      return;
    }

    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = shortestSide / 2 - strokeWidth / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final available = (2 * math.pi) - gapAngle;
    final startAngle = -math.pi / 2 + gapAngle / 2;
    final sweep = available * value.clamp(0, 1);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final indicatorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, startAngle, available, false, trackPaint);

    if (sweep > 0) {
      canvas.drawArc(arcRect, startAngle, sweep, false, indicatorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gapAngle != gapAngle ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

class _LoadingIndicatorPainter extends CustomPainter {
  final double progress;
  final Color color;

  _LoadingIndicatorPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = math.min(size.width, size.height);
    if (shortestSide <= 0) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final t = progress % 1.0;
    final pulse = 0.5 - 0.5 * math.cos(2 * math.pi * t);
    final wobble = 0.5 - 0.5 * math.cos(2 * math.pi * (t + 0.33));
    final roundness = 0.5 - 0.5 * math.cos(2 * math.pi * (t + 0.66));

    final base = shortestSide * 0.58;
    final width = base * lerpDouble(0.6, 1.0, pulse)!;
    final height = base * lerpDouble(0.6, 1.0, wobble)!;
    final radius = lerpDouble(base * 0.1, base * 0.5, roundness)!;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(2 * math.pi * t);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LoadingIndicatorPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
