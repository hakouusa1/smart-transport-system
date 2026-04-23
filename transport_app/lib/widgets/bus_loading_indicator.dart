import 'package:flutter/material.dart';

class BusLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const BusLoadingIndicator({
    super.key,
    this.size = 40.0,
    this.color,
    this.strokeWidth = 4.0,
  });

  @override
  State<BusLoadingIndicator> createState() => _BusLoadingIndicatorState();
}

class _BusLoadingIndicatorState extends State<BusLoadingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnim;
  late Animation<double> _shadowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    
    _bounceAnim = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    
    _shadowAnim = Tween<double>(begin: 1.0, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.size < 30) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(
          strokeWidth: widget.strokeWidth,
          color: widget.color ?? Theme.of(context).primaryColor,
        ),
      );
    }

    final themeColor = widget.color ?? Theme.of(context).primaryColor;

    return SizedBox(
      width: widget.size,
      height: widget.size + 15,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Shadow underneath
              Positioned(
                bottom: 0,
                child: Transform.scale(
                  scale: _shadowAnim.value,
                  child: Container(
                    width: widget.size * 0.7,
                    height: widget.size * 0.15,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
              // Bouncing Bus Icon
              Positioned(
                bottom: 4,
                child: Transform.translate(
                  offset: Offset(0, _bounceAnim.value),
                  child: Icon(
                    Icons.directions_bus,
                    size: widget.size,
                    color: themeColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
