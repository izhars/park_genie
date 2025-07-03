import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../DatabaseHelper.dart';

class PinSettingsPage extends StatefulWidget {
  const PinSettingsPage({Key? key}) : super(key: key);

  @override
  _PinSettingsPageState createState() => _PinSettingsPageState();
}

class _PinSettingsPageState extends State<PinSettingsPage>
    with TickerProviderStateMixin {
  String currentPin = "";
  String newPin = "";
  String confirmPin = "";
  String errorText = "";
  String successText = "";
  int step = 1; // 1: current PIN, 2: new PIN, 3: confirm PIN
  bool isLoading = false;
  bool showForgotPinOption = false;
  int failedAttempts = 0;
  static const int maxFailedAttempts = 3;

  late AnimationController _slideController;
  late AnimationController _shakeController;
  late AnimationController _dotController;

  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _shakeAnimation;
  late Animation<double> _dotScaleAnimation;

  // Animation controllers for each button
  final Map<String, AnimationController> _buttonControllers = {};
  final Map<String, Animation<double>> _buttonAnimations = {};

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkIfFirstTime();
  }

  void _initAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 600),
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
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

    _dotScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dotController,
      curve: Curves.elasticOut,
    ));

    _slideController.forward();
  }

  void _checkIfFirstTime() async {
    try {
      String pin = await DatabaseHelper.instance.getPin();
      if (pin == '0000') {
        // First time setup, skip current PIN verification
        setState(() {
          step = 2;
        });
      }
    } catch (e) {
      print("Error checking PIN: $e");
    }
  }

  void _onNumberPressed(String number) async {
    String currentInput = _getCurrentInput();

    if (currentInput.length < 4 && !isLoading) {
      await _buttonControllers[number]?.forward();
      _buttonControllers[number]?.reverse();

      HapticFeedback.lightImpact();

      setState(() {
        _setCurrentInput(currentInput + number);
        errorText = "";
        successText = "";
      });

      _dotController.forward();

      if (_getCurrentInput().length == 4) {
        await Future.delayed(const Duration(milliseconds: 300));
        _handleStepCompletion();
      }
    }
  }

  void _onClearPressed() async {
    if (!isLoading) {
      await _buttonControllers['clear']?.forward();
      _buttonControllers['clear']?.reverse();

      HapticFeedback.mediumImpact();

      setState(() {
        _setCurrentInput("");
        errorText = "";
        successText = "";
      });

      _dotController.reset();
    }
  }

  String _getCurrentInput() {
    switch (step) {
      case 1:
        return currentPin;
      case 2:
        return newPin;
      case 3:
        return confirmPin;
      default:
        return "";
    }
  }

  void _setCurrentInput(String value) {
    switch (step) {
      case 1:
        currentPin = value;
        break;
      case 2:
        newPin = value;
        break;
      case 3:
        confirmPin = value;
        break;
    }
  }

  void _handleStepCompletion() async {
    setState(() {
      isLoading = true;
    });

    try {
      switch (step) {
        case 1:
        // Check for master reset code first
          if (currentPin == "0000") {
            _showMasterResetConfirmation();
            return;
          }

          // Verify current PIN
          bool isValid = await DatabaseHelper.instance.verifyPin(currentPin);
          if (isValid) {
            setState(() {
              step = 2;
              currentPin = "";
              failedAttempts = 0;
              showForgotPinOption = false;
            });
            _dotController.reset();
          } else {
            setState(() {
              failedAttempts++;
              if (failedAttempts >= maxFailedAttempts) {
                showForgotPinOption = true;
              }
            });
            _showError("Incorrect current PIN (${maxFailedAttempts - failedAttempts} attempts remaining)");
            setState(() {
              currentPin = "";
            });
            _dotController.reset();
          }
          break;

        case 2:
        // Set new PIN
          if (newPin.length == 4) {
            // Validate new PIN strength
            if (_isWeakPin(newPin)) {
              _showError("Please choose a stronger PIN (avoid 1234, 0000, etc.)");
              setState(() {
                newPin = "";
              });
              _dotController.reset();
            } else {
              setState(() {
                step = 3;
              });
              _dotController.reset();
            }
          }
          break;

        case 3:
        // Confirm new PIN
          if (newPin == confirmPin) {
            bool success = await DatabaseHelper.instance.updatePin(newPin);
            if (success) {
              // Log the PIN change for security
              await _logPinChange();

              setState(() {
                successText = "PIN updated successfully!";
              });
              HapticFeedback.heavyImpact();

              // Navigate back after 2 seconds
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  Navigator.pop(context, true);
                }
              });
            } else {
              _showError("Failed to update PIN. Please try again.");
              _resetToStep2();
            }
          } else {
            _showError("PINs don't match. Please try again.");
            _resetToStep2();
          }
          break;
      }
    } catch (e) {
      _showError("An error occurred. Please try again.");
      print("Error in step completion: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showMasterResetConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Reset PIN"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                "You are about to reset your PIN using the master code. This action will be logged for security purposes.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                "Continue with PIN reset?",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  isLoading = false;
                  currentPin = "";
                });
                _dotController.reset();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _proceedWithMasterReset();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text("Continue Reset"),
            ),
          ],
        );
      },
    );
  }

  void _proceedWithMasterReset() async {
    // Log the master reset for security
    await _logMasterReset();

    setState(() {
      step = 2;
      currentPin = "";
      failedAttempts = 0;
      showForgotPinOption = false;
      isLoading = false;
    });
    _dotController.reset();

    _showError("PIN reset initiated. Please set a new PIN.");
  }

  bool _isWeakPin(String pin) {
    // Check for common weak PINs
    List<String> weakPins = [
      "0000", "1111", "2222", "3333", "4444",
      "5555", "6666", "7777", "8888", "9999",
      "1234", "4321", "1122", "2211"
    ];

    return weakPins.contains(pin);
  }

  Future<void> _logPinChange() async {
    // Log PIN change with timestamp
    try {
      await DatabaseHelper.instance.logSecurityEvent(
          "PIN_CHANGED",
          DateTime.now().toIso8601String()
      );
    } catch (e) {
      print("Error logging PIN change: $e");
    }
  }

  Future<void> _logMasterReset() async {
    // Log master reset with timestamp
    try {
      await DatabaseHelper.instance.logSecurityEvent(
          "MASTER_PIN_RESET",
          DateTime.now().toIso8601String()
      );
    } catch (e) {
      print("Error logging master reset: $e");
    }
  }

  void _showError(String message) {
    _shakeController.reset();
    _shakeController.forward();
    HapticFeedback.heavyImpact();

    setState(() {
      errorText = message;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          errorText = "";
        });
      }
    });
  }

  void _resetToStep2() {
    setState(() {
      step = 2;
      newPin = "";
      confirmPin = "";
    });
    _dotController.reset();
  }

  String _getStepTitle() {
    switch (step) {
      case 1:
        return "Enter Current PIN";
      case 2:
        return "Enter New PIN";
      case 3:
        return "Confirm New PIN";
      default:
        return "";
    }
  }

  String _getStepSubtitle() {
    switch (step) {
      case 1:
        return showForgotPinOption
            ? "Enter current PIN or use 0000 to reset"
            : "Please enter your current 4-digit PIN";
      case 2:
        return "Enter your new 4-digit PIN";
      case 3:
        return "Re-enter your new PIN to confirm";
      default:
        return "";
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
            width: 60,
            height: 60,
            margin: const EdgeInsets.all(6),
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
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: isLoading ? null : _onClearPressed,
                child: const Center(
                  child: Icon(
                    Icons.backspace_outlined,
                    color: Colors.white,
                    size: 18,
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
    String currentInput = _getCurrentInput();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool isFilled = index < currentInput.length;
        return AnimatedBuilder(
          animation: _dotScaleAnimation,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? Colors.blue : Colors.grey[400],
                  boxShadow: isFilled ? [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                transform: Matrix4.identity()
                  ..scale(isFilled ? _dotScaleAnimation.value : 1.0),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildForgotPinHelper() {
    if (!showForgotPinOption || step != 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.help_outline,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            "Forgot PIN? Enter ",
            style: TextStyle(
              color: Colors.orange,
              fontSize: 14,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              "0000",
              style: TextStyle(
                color: Colors.orange,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const Text(
            " to reset",
            style: TextStyle(
              color: Colors.orange,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _shakeController.dispose();
    _dotController.dispose();

    for (var controller in _buttonControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'PIN Settings',
          style: GoogleFonts.poppins(
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Progress indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        bool isActive = index + 1 <= step;
                        bool isCompleted = index + 1 < step;

                        return Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted
                                    ? Colors.green
                                    : isActive
                                    ? Colors.blue
                                    : Colors.grey[300],
                              ),
                              child: Center(
                                child: isCompleted
                                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                                    : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive ? Colors.white : Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (index < 2)
                              Container(
                                width: 40,
                                height: 2,
                                color: index + 1 < step ? Colors.blue : Colors.grey[300],
                              ),
                          ],
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Step icon and loading
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(
                      strokeWidth: 3,
                    )
                        : Icon(
                      step == 1 ? Icons.lock_open : Icons.lock_reset,
                      size: 40,
                      color: Colors.blue,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Title
                  Text(
                    _getStepTitle(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    _getStepSubtitle(),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // Forgot PIN helper
                  _buildForgotPinHelper(),

                  const SizedBox(height: 20),

                  // PIN dots display
                  SlideTransition(
                    position: _shakeAnimation,
                    child: _buildPinDots(),
                  ),

                  const SizedBox(height: 20),

                  // Success message
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: successText.isNotEmpty ? 40 : 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: successText.isNotEmpty ? 1.0 : 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              successText,
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

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
                          color: Colors.red.withOpacity(0.1),
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
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              errorText,
                              style: const TextStyle(
                                color: Colors.red,
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
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
                            const SizedBox(width: 72), // Empty space for symmetry
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
    );
  }
}