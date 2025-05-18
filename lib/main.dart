import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: BlazeFaceScreen());
  }
}

class BoundingBox {
  final double xmin, ymin, xmax, ymax, score;

  BoundingBox(
      {required this.xmin,
      required this.ymin,
      required this.xmax,
      required this.ymax,
      required this.score});
}

class BlazeFaceScreen extends StatefulWidget {
  const BlazeFaceScreen({super.key});

  @override
  State<BlazeFaceScreen> createState() => _BlazeFaceScreenState();
}

class _BlazeFaceScreenState extends State<BlazeFaceScreen> {
  late CameraController controller;
  late Interpreter interpreter;
  String resultText = "Initializing...";
  List<Rect> detectedRects = [];
  File? capturedImageFile;
  List<BoundingBox> capturedBoxes = [];
  int imageWidth = 0, imageHeight = 0;
  List<img.Image> imageFiles = [];
  List<int> facesList = [];
  List<Object> confidences = [];

  @override
  void initState() {
    super.initState();
    initializeCamera();
    loadModel();
  }

  Future<void> initializeCamera() async {
    final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back);
    controller = CameraController(frontCamera, ResolutionPreset.medium);
    await controller.initialize();
    if (mounted) setState(() => resultText = "Camera ready");
  }

  Future<void> loadModel() async {
    interpreter = await Interpreter.fromAsset(
      'assets/blazeface.tflite',
      options: InterpreterOptions()..threads = 2,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    interpreter.close();
    super.dispose();
  }

  double sigmoid(double x) => 1 / (1 + exp(-x));

  double iou(BoundingBox a, BoundingBox b) {
    final double x1 = max(a.xmin, b.xmin);
    final double y1 = max(a.ymin, b.ymin);
    final double x2 = min(a.xmax, b.xmax);
    final double y2 = min(a.ymax, b.ymax);

    final double interArea = max(0, x2 - x1) * max(0, y2 - y1);
    final double boxAArea = (a.xmax - a.xmin) * (a.ymax - a.ymin);
    final double boxBArea = (b.xmax - b.xmin) * (b.ymax - b.ymin);

    return interArea / (boxAArea + boxBArea - interArea);
  }

  List<BoundingBox> nonMaximumSuppression(List<BoundingBox> boxes,
      {double iouThreshold = 0.3}) {
    final List<BoundingBox> picked = [];
    boxes.sort((a, b) => b.score.compareTo(a.score));

    final used = List<bool>.filled(boxes.length, false);

    for (int i = 0; i < boxes.length; i++) {
      if (used[i]) continue;
      picked.add(boxes[i]);
      for (int j = i + 1; j < boxes.length; j++) {
        if (!used[j] && iou(boxes[i], boxes[j]) > iouThreshold) {
          used[j] = true;
        }
      }
    }
    return picked;
  }

  Future<List<Map<String, dynamic>>> runBlazeFace(img.Image? image,
      {double threshold = 0.75}) async {
    if (image == null) return [];

    imageWidth = image.width;
    imageHeight = image.height;

    final resized = img.copyResizeCropSquare(image, size: 128);
    final input = [
      List.generate(
          128,
          (y) => List.generate(128, (x) {
                final pixel = resized.getPixel(x, y);
                return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
              })),
    ];

    final regressors = List.generate(
        1, (_) => List.generate(896, (_) => List.filled(16, 0.0)));
    final classificators =
        List.generate(1, (_) => List.generate(896, (_) => List.filled(1, 0.0)));

    final outputs = {0: regressors, 1: classificators};
    interpreter.runForMultipleInputs([input], outputs);

    final regressionOutput = outputs[0] as List;
    final classifierOutput = outputs[1] as List;

    List<BoundingBox> rawBoxes = [];

    for (int i = 0; i < 896; i++) {
      final confidence = sigmoid(classifierOutput[0][i][0]);
      if (confidence >= threshold) {
        final bbox = regressionOutput[0][i];
        rawBoxes.add(BoundingBox(
          xmin: bbox[1],
          ymin: bbox[0],
          xmax: bbox[3],
          ymax: bbox[2],
          score: confidence,
        ));
      }
    }

    final finalBoxes = nonMaximumSuppression(rawBoxes);
    detectedRects = finalBoxes
        .map((box) => Rect.fromLTWH(
              box.xmin,
              box.ymin,
              box.xmax - box.xmin,
              box.ymax - box.ymin,
            ))
        .toList();

    return finalBoxes.map((b) => {'confidence': b.score, 'bbox': b}).toList();
  }

  Future<void> captureAndDetect() async {
    setState(() {
      resultText = "Capturing...";
      imageFiles.clear();
      facesList.clear();
      confidences.clear();
    });

    final xFile = await controller.takePicture();
    final image = img.decodeImage(await xFile.readAsBytes());
    if (image == null) return;

    //    final rotations = [image, img.copyRotate(image, angle: 90), img.copyRotate(image, angle: 180), img.copyRotate(image, angle: 270)];

    final rotations = [image];

    for (var rotated in rotations) {
      imageFiles.add(rotated);
      final faces = await runBlazeFace(rotated);
      final faceCount = faces.length;
      final faceConf = faces
          .map((f) => (f['confidence'] as double).toStringAsFixed(2))
          .toList();
      facesList.add(faceCount);
      confidences.add(faceConf);
    }

    setState(() {
      resultText = "Detection complete";
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("BlazeFace Face Detector"),
        centerTitle: true,
        backgroundColor: Colors.black87,
      ),
      body: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 📷 Camera Preview Section
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: SizedBox(
                  height: 520,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CameraPreview(controller),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 🧾 Status Text
              Text(
                resultText,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // 📸 Capture Button
              ElevatedButton.icon(
                onPressed: captureAndDetect,
                icon: const Icon(Icons.camera_alt),
                label: const Text("Capture & Detect"),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 30),

              // 🖼️ Results Section
              if (imageFiles.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: imageFiles.length,
                  itemBuilder: (context, index) {
                    final imageMem =
                        Uint8List.fromList(img.encodeJpg(imageFiles[index]));
                    final confidenceText =
                        (confidences[index] as List).join(', ');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "📸 Rotation: ${index * 90}°",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Image with Bounding Box Overlay (simulated via description)
                          Container(
                            width: 256,
                            height: 256,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.deepPurple, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                imageMem,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.face,
                                  size: 18, color: Colors.green),
                              const SizedBox(width: 5),
                              Text(
                                "Faces: ${facesList[index]}",
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),

                          const SizedBox(height: 5),

                          Text(
                            "Confidence: $confidenceText",
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
