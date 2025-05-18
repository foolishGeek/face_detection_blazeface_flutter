# face_detection_blazeface_flutter
In this code we are using Google's Blazeface ML model and tflite_flutter and camera package to detect faces in flutter
This code is a Flutter application that uses the camera plugin to access the device's camera, captures images, and performs face detection using the BlazeFace model (a TensorFlow Lite model). It also displays bounding boxes around detected faces. Below is a breakdown of the key components:

1. Imports
'dart:io': Provides I/O functionality for file operations.
'dart:math': Offers mathematical functions like max() used in Intersection over Union (IoU) calculations 3
(https://pub.dev/packages/camera ).
'package:flutter/material.dart': Core Flutter framework for building Material Design UIs 2
(https://pub.dev/packages/camera ).
'package:camera/camera.dart': Plugin to control the camera hardware, such as capturing images and previewing the camera feed 1
(https://pub.dev/packages/camera ).
'package:tflite_flutter/tflite_flutter.dart': Used for running TensorFlow Lite models on Android/iOS devices.
'package:image/image.dart' as img: A Dart image library for decoding/encoding images and performing transformations.
2. Global Variables
List<CameraDescription> cameras = []: Stores available camera devices.
Future<void> main() async: Initializes the app, fetches camera descriptions, and runs MyApp.
3. MyApp Class
This is the root widget of the application.
Returns BlazeFaceScreen as the home screen 9
(https://pub.dev/packages/camera ).
4. BoundingBox Class
Represents a rectangular area around a detected face with coordinates (xmin, ymin, xmax, ymax) and confidence score.
5. BlazeFaceScreen Class
A StatefulWidget that manages the state for face detection.
Contains the controller for managing the camera and interpreter for loading and running the TFLite model.
Holds variables for results display, including bounding boxes and image data.
6. Lifecycle Methods
initState(): Initializes the camera and loads the TFLite model.
initializeCamera(): Sets up the back-facing camera and initializes the controller.
loadModel(): Loads the blazeface.tflite model for face detection 2
(https://pub.dev/packages/tflite_flutter ).
7. Mathematical Functions
sigmoid(double x): Converts raw scores into probabilities between 0 and 1.
iou(BoundingBox a, BoundingBox b): Calculates the Intersection over Union (IoU), which measures overlap between two bounding boxes.
nonMaximumSuppression(List<BoundingBox> boxes): Removes overlapping bounding boxes by applying IoU thresholding 5
(https://pub.dev/documentation/camera/latest/ ).
8. Face Detection Logic
runBlazeFace(img.Image? image): Processes the input image, resizes it, and feeds it into the model.
Resizes the image to 128x128 pixels for model compatibility.
Normalizes pixel values to range [0, 1].
Runs inference using the interpreter.
Extracts bounding boxes and confidence scores from outputs.
Applies non-maximum suppression to filter out overlapping boxes 6
(https://pub.dev/documentation/tflite_flutter/latest/ ).
9. Image Capture and Detection
captureAndDetect(): Captures an image using the camera, rotates it, and runs face detection.
Clears previous results.
Captures an image using takePicture().
Decodes the image using the image package.
Iterates through rotated versions of the image for better detection accuracy.
Updates the UI with results 1
(https://pub.dev/documentation/camera/latest/ ).
10. UI Components
Camera Preview : Displays the live camera feed using CameraPreview(controller) 1
(https://pub.dev/documentation/camera/latest/ ).
Capture Button : Triggers captureAndDetect() when pressed.
Results Display :
Shows detected faces, confidence scores, and bounding boxes.
Uses ListView.builder to show each processed image and its results 9
(https://pub.dev/documentation/camera/latest/ ).
11. Key Dependencies
Flutter Camera Plugin : For accessing the camera hardware and displaying previews 1
(https://pub.dev/packages/camera ).
TFLite Flutter : For running TensorFlow Lite models on mobile devices 6
(https://pub.dev/packages/tflite_flutter ).
Image Package : For image manipulation tasks like resizing and encoding 3
(https://pub.dev/packages/image ).
Summary
This Flutter app integrates camera capture, TensorFlow Lite-based face detection (using BlazeFace), and real-time result visualization. It demonstrates how to use the camera, tflite_flutter, and image packages together to build advanced computer vision applications 2
(https://pub.dev/packages/camera )6
(https://pub.dev/packages/tflite_flutter )3
(https://pub.dev/packages/image ).
