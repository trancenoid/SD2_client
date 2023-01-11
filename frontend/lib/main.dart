
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imagelib;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const SD2Canvas());

class SD2Canvas extends StatelessWidget {
  const SD2Canvas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Painter Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SD2CanvasApp(),
    );
  }
}

class SD2CanvasApp extends StatefulWidget {
  const SD2CanvasApp({super.key});

  @override
  SD2CanvasAppState createState() => SD2CanvasAppState();
}



class SD2CanvasAppState extends State<SD2CanvasApp> {
  List<Offset> points = [];
  List<double> currTransform = [0.0, 0.0, 1.0]; // [x,y,scale]
  late TapDownDetails doubleTapDetails;
  late TransformationController tfmController;
  bool isZoomed = false;
  late ui.Image mainImage;

  Future<ui.Image> loadImage(String path) async {
    final ByteData bytes = await rootBundle.load(path);
    ui.Image decodedImage = await decodeImageFromList(bytes.buffer.asUint8List());
    return decodedImage;
  }

  Future<Widget> uiImageToWidget(ui.Image img) async {
    final bytes = await mainImage.toByteData(format: ui.ImageByteFormat.png);

    return Image.memory(
        Uint8List.view(bytes!.buffer)
    );
  }

  @override
  void initState() {
    super.initState();
    mainImage = loadImage("assets/sample.png") as ui.Image;
    tfmController = TransformationController();
  }

  Offset transformOffset(Offset o) {
    double dx = o.dx;
    double dy = o.dy;
    return Offset((dx - currTransform[0]) / currTransform[2],
        (dy - currTransform[1]) / currTransform[2]);
  }

  Widget _makeCanvas() {
    return GestureDetector(
      onDoubleTapDown: (details) {
        setState(() {
          doubleTapDetails = details;
          isZoomed = !isZoomed;
        });
      },
      onDoubleTap: () {
        Matrix4 zoomed = Matrix4.identity();
        double x, y, scale;
        if (!isZoomed) {
          scale = 2.0;
          x = -doubleTapDetails.localPosition.dx * (scale - 1);
          y = -doubleTapDetails.localPosition.dy * (scale - 1);
          zoomed
            ..translate(x, y)
            ..scale(scale);
        } else {
          x = y = 0;
          scale = 1.0;
        }

        setState(() {
          currTransform = [x, y, scale];
        });
        tfmController.value = zoomed;
      },
      child: InteractiveViewer(
        onInteractionUpdate: (event) {
          setState(() {
            if (event.pointerCount == 1) {
              points.add(transformOffset(event.localFocalPoint));
              print(points[points.length - 1]);
            }
          });
        },
        onInteractionStart: (event) {
          setState(() {
            if (event.pointerCount == 1) {
              points.add(transformOffset(event.localFocalPoint));
              print(points[points.length - 1]);
            }
          });
        },
        clipBehavior: Clip.none,
        panEnabled: false,
        scaleEnabled: false,
        transformationController: tfmController,
        child: Stack(
          children: [
            Center(
              child: uiImageToWidget(mainImage),
            ),
            CustomPaint(
              size : Size(mainImage.width as double, mainImage.height as double),
              painter: CanvasMaskPainter(points),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SD2 Canvas"),
      ),
      body: Column(
        children: [
          ClipRect(
            child: Align(
              widthFactor: 1.0,
              heightFactor: 1.0,
              alignment: Alignment.center,
              child: _makeCanvas(),
            ),
          ),
          // TextFormField(initialValue: "Realistic Landscape, Artstation",),
          ButtonBar(
            alignment: MainAxisAlignment.center,
            children: [
              MaterialButton(
                onPressed: () async {
                  ImagePicker picker = ImagePicker();
                  XFile? image =
                      await picker.pickImage(source: ImageSource.gallery);
                  setState(() {
                    mainImage = Image.file(File(image!.path));
                  });
                },
                color: Colors.blue,
                child: const Text("Select Image"),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class CanvasMaskPainter extends CustomPainter {
  List<Offset> points;

  CanvasMaskPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    var paint1 = Paint()
      ..color = const Color(0xff63aa65)
      ..strokeWidth = 10;

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPoints(ui.PointMode.points, points, paint1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
