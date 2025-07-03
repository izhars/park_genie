import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class FetchTextFromCamera extends StatefulWidget {
  const FetchTextFromCamera({super.key});

  @override
  _FetchTextFromCameraState createState() => _FetchTextFromCameraState();
}

class _FetchTextFromCameraState extends State<FetchTextFromCamera> {
  CameraController? _cameraController;
  late List<CameraDescription> cameras;
  bool isCameraInitialized = false;
  String recognizedText = "";

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    cameras = await availableCameras();
    _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
    await _cameraController!.initialize();
    if (mounted) {
      setState(() {
        isCameraInitialized = true;
      });
    }
  }

  Future<void> _captureAndRecognizeText() async {
    if (!_cameraController!.value.isInitialized) return;

    final XFile imageFile = await _cameraController!.takePicture();
    final String imagePath = imageFile.path;

    // Process image with ML Kit
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer();
    final RecognizedText recognized = await textRecognizer.processImage(inputImage);

    setState(() {
      recognizedText = recognized.text;
    });

    textRecognizer.close();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Text Recognition")),
      body: Column(
        children: [
          if (isCameraInitialized)
            SizedBox(
              height: 300,
              child: CameraPreview(_cameraController!),
            ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _captureAndRecognizeText,
            child: const Text("Capture & Recognize"),
          ),
          const SizedBox(height: 10),
          Text(
            recognizedText.isNotEmpty ? "Recognized Text: \n$recognizedText" : "No text recognized",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
