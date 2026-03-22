import 'package:flutter/material.dart';

class TurnTimerWrapper extends StatefulWidget {
  final Widget child;
  final bool isMyTurn;        // Có phải lượt người này không?
  final int durationSeconds;  // Thời gian đếm ngược (ví dụ 30s)
  final VoidCallback? onTimeOut; // Hàm chạy khi hết giờ

  const TurnTimerWrapper({
    super.key,
    required this.child,
    required this.isMyTurn,
    this.durationSeconds = 30,
    this.onTimeOut,
  });

  @override
  State<TurnTimerWrapper> createState() => _TurnTimerWrapperState();
}

class _TurnTimerWrapperState extends State<TurnTimerWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Controller quản lý thời gian (30s)
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    );

    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onTimeOut?.call();
        }
      });

    if (widget.isMyTurn) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(TurnTimerWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nếu chuyển từ "Không phải lượt" -> "Đến lượt"
    if (widget.isMyTurn && !oldWidget.isMyTurn) {
      _controller.reset();
      _controller.forward();
    }
    // Nếu hết lượt
    else if (!widget.isMyTurn && oldWidget.isMyTurn) {
      _controller.stop();
      _controller.reset(); // Reset về trạng thái ban đầu
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Logic chọn màu: Xanh -> Vàng -> Đỏ
  Color _getColor(double progress) {
    if (progress > 0.5) return Colors.greenAccent;
    if (progress > 0.2) return Colors.amber;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isMyTurn) {
      // Nếu không phải lượt, trả về widget gốc + padding để giữ vị trí
      return Padding(
        padding: const EdgeInsets.all(3.0), // Padding bằng độ dày viền để không bị nhảy layout
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _BorderProgressPainter(
            progress: _animation.value,
            color: _getColor(_animation.value),
            strokeWidth: 3.0,
          ),
          child: Padding(
            padding: const EdgeInsets.all(3.0), // Khoảng cách giữa viền và nội dung
            child: widget.child,
          ),
        );
      },
    );
  }
}

// Painter để vẽ viền chạy
class _BorderProgressPainter extends CustomPainter {
  final double progress; // Từ 1.0 về 0.0
  final Color color;
  final double strokeWidth;

  _BorderProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    // Vẽ hình chữ nhật bo góc (RRect) bao quanh widget
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(10), // Bo góc trùng với border của profile
    );

    // Tạo Path từ RRect
    final Path path = Path()..addRRect(rrect);

    // Tính toán độ dài đường viền để vẽ hiệu ứng chạy
    // Dùng kỹ thuật PathMetric để cắt đường viền theo %
    final  metrics = path.computeMetrics().first;
    final extractPath = metrics.extractPath(0.0, metrics.length * progress);

    // Vẽ viền nền mờ (optional)
    canvas.drawRRect(rrect, Paint()..style = PaintingStyle.stroke..color = Colors.white10..strokeWidth = strokeWidth);

    // Vẽ viền chạy (Tiến trình)
    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(covariant _BorderProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}