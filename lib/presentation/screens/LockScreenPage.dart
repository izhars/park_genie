import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../DatabaseHelper.dart';
import '../../ParkingApp.dart';

class LockScreenPage extends StatefulWidget {
  const LockScreenPage({Key? key}) : super(key: key);

  @override
  _LockScreenPageState createState() => _LockScreenPageState();
}

class _LockScreenPageState extends State<LockScreenPage>
    with TickerProviderStateMixin {
  String enteredPin = "";
  String errorText = "";
  bool isLoading = false;

  late AnimationController _slideController;
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late AnimationController _dotController;

  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _shakeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _dotScaleAnimation;

  // Animation controllers for each button
  final Map<String, AnimationController> _buttonControllers = {};
  final Map<String, Animation<double>> _buttonAnimations = {};

  @override
  void initState() {
    super.initState();

    // Initialize main animation controllers
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _dotController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialize button animations
    for (int i = 0; i <= 9; i++) {
      String key = i.toString();
      _buttonControllers[key] = AnimationController(
        duration: const Duration(milliseconds: 150),
        vsync: this,
      );
      _buttonAnimations[key] = Tween<double>(
        begin: 1.0,
        end: 0.9,
      ).animate(CurvedAnimation(
        parent: _buttonControllers[key]!,
        curve: Curves.easeInOut,
      ));
    }

    // Add clear button animation
    _buttonControllers['clear'] = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _buttonAnimations['clear'] = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _buttonControllers['clear']!,
      curve: Curves.easeInOut,
    ));

    // Initialize main animations
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _shakeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.05, 0),
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _dotScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dotController,
      curve: Curves.elasticOut,
    ));

    // Start initial animations
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  void _onNumberPressed(String number) async {
    if (enteredPin.length < 4 && !isLoading) {
      // Button press animation
      await _buttonControllers[number]?.forward();
      _buttonControllers[number]?.reverse();

      // Haptic feedback
      HapticFeedback.lightImpact();

      setState(() {
        enteredPin += number;
        errorText = "";
      });

      // Animate dot appearance
      _dotController.forward();

      // Auto-verify when 4 digits are entered
      if (enteredPin.length == 4) {
        await Future.delayed(const Duration(milliseconds: 300));
        _verifyPin();
      }
    }
  }

  void _onClearPressed() async {
    if (!isLoading) {
      // Button press animation
      await _buttonControllers['clear']?.forward();
      _buttonControllers['clear']?.reverse();

      // Haptic feedback
      HapticFeedback.mediumImpact();

      setState(() {
        enteredPin = "";
        errorText = "";
      });

      _dotController.reset();
    }
  }

  void _verifyPin() async {
    setState(() {
      isLoading = true;
    });

    try {
      bool isValid = await DatabaseHelper.instance.verifyPin(enteredPin);

      if (isValid) {
        // Success animation
        setState(() {
          errorText = "";
        });

        // Success haptic feedback
        HapticFeedback.heavyImpact();

        // Navigate with a slight delay for visual feedback
        await Future.delayed(const Duration(milliseconds: 500));

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => ParkingApp()),
              (route) => false,
        );
      } else {
        // Error animation
        _shakeController.reset();
        _shakeController.forward();

        // Error haptic feedback
        HapticFeedback.heavyImpact();

        setState(() {
          errorText = "Incorrect PIN. Try again.";
          enteredPin = "";
        });

        _dotController.reset();

        // Auto-clear error after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              errorText = "";
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        errorText = "Error verifying PIN. Please try again.";
        enteredPin = "";
      });
      _dotController.reset();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildNumberButton(String number) {
    return AnimatedBuilder(
      animation: _buttonAnimations[number]!,
      builder: (context, child) {
        return Transform.scale(
          scale: _buttonAnimations[number]!.value,
          child: Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(16), // Adjust the radius as needed
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey[100]!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.red.shade300, // Stroke color
                width: 1.5,                  // Stroke width
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isLoading ? null : () => _onNumberPressed(number),
                child: Center(
                  child: Text(
                    number,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isLoading ? Colors.grey : const Color(0xFF2D3748),
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

  Widget _buildClearButton() {
    return AnimatedBuilder(
      animation: _buttonAnimations['clear']!,
      builder: (context, child) {
        return Transform.scale(
          scale: _buttonAnimations['clear']!.value,
          child: Container(
            width: 70,
            height: 70,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isLoading ? Colors.grey[400]! : Colors.red[400]!,
                  isLoading ? Colors.grey[600]! : Colors.red[600]!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isLoading ? Colors.grey : Colors.red).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(35),
                onTap: isLoading ? null : _onClearPressed,
                child: const Center(
                  child: Icon(
                    Icons.backspace_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPinDots() {
    const double dotSize = 18.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool isFilled = index < enteredPin.length;

        return AnimatedBuilder(
          animation: _dotScaleAnimation,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 250),
                scale: isFilled ? _dotScaleAnimation.value : 1.0,
                curve: Curves.easeOutBack,
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? Colors.blue : Colors.transparent,
                    border: Border.all(
                      color: isFilled ? Colors.transparent : Colors.grey.shade400,
                      width: 1.5,
                    ),
                    boxShadow: isFilled
                        ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                        : null,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }


  @override
  void dispose() {
    _slideController.dispose();
    _shakeController.dispose();
    _pulseController.dispose();
    _dotController.dispose();

    // Dispose button controllers
    for (var controller in _buttonControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.grey[100],
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated lock icon
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withOpacity(0.1),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            )
                                : const Icon(
                              Icons.lock_rounded,
                              size: 50,
                              color: Colors.blue,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // Title
                    const Text(
                      "Enter PIN",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "Please enter your 4-digit PIN",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // PIN dots display
                    SlideTransition(
                      position: _shakeAnimation,
                      child: _buildPinDots(),
                    ),

                    const SizedBox(height: 20),

                    // Error message
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: errorText.isNotEmpty ? 40 : 0,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: errorText.isNotEmpty ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                errorText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Custom keypad
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Row 1: 1, 2, 3
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildNumberButton('1'),
                              _buildNumberButton('2'),
                              _buildNumberButton('3'),
                            ],
                          ),

                          // Row 2: 4, 5, 6
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildNumberButton('4'),
                              _buildNumberButton('5'),
                              _buildNumberButton('6'),
                            ],
                          ),

                          // Row 3: 7, 8, 9
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildNumberButton('7'),
                              _buildNumberButton('8'),
                              _buildNumberButton('9'),
                            ],
                          ),

                          // Row 4: Clear, 0, (empty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildClearButton(),
                              _buildNumberButton('0'),
                              const SizedBox(width: 86), // Empty space for symmetry
                            ],
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
      ),
    );
  }
}