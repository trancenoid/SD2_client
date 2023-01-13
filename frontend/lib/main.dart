import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/services.dart';
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
  String currentImageSource = 'asset';
  String currentImagePath = ("assets/sample.png");
  late final ValueNotifier<bool> _isLoaded;

  void loadImage() async {
    Uint8List img;
    if (currentImageSource != 'asset') {
      img = await File(currentImagePath).readAsBytes();
    } else {
      final bytes = await rootBundle.load(currentImagePath);
      img = bytes.buffer.asUint8List();
    }

    final completer = Completer<ui.Image>();

    ui.decodeImageFromList(img, (image) {
      _isLoaded.value = true;
      return completer.complete(image);
    });
    mainImage = await completer.future;
  }

  Future<Widget> uiImageToImageWidget(ui.Image img) async {
    final bytes = await mainImage.toByteData(format: ui.ImageByteFormat.png);
    return Image.memory(Uint8List.view(bytes!.buffer));
  }

  @override
  void initState() {
    super.initState();
    _isLoaded = ValueNotifier<bool>(false);
    loadImage();
    tfmController = TransformationController();
  }

  Offset transformOffset(Offset o) {
    double dx = o.dx;
    double dy = o.dy;
    return Offset((dx - currTransform[0]) / currTransform[2],
        (dy - currTransform[1]) / currTransform[2]);
  }

  void interactionZoom(event) {
    return;
    Matrix4 zoomed = Matrix4.identity();
    double x, y, scale;
    scale = event is ScaleStartDetails ? 1.0 : event.scale;
    if (1.0 <= scale && scale <= 4.0) {
      print(scale);
      x = -event.focalPoint.dx * (scale - 1);
      y = -event.focalPoint.dy * (scale - 1);
      zoomed
        ..translate(x, y)
        ..scale(scale);
      setState(() {
        currTransform = [x, y, scale];
      });
    }
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
              // print(points[points.length - 1]);
            } else {
              interactionZoom(event);
            }
          });
        },
        onInteractionStart: (event) {
          setState(() {
            if (event.pointerCount == 1) {
              points.add(transformOffset(event.localFocalPoint));
              // print(points[points.length - 1]);
            } else {
              interactionZoom(event);
            }
          });
        },
        onInteractionEnd: (event) {
          if (event.pointerCount > 1) {
            interactionZoom(event);
          }
        },
        clipBehavior: Clip.none,
        panEnabled: false,
        scaleEnabled: false,
        transformationController: tfmController,
        child: Stack(
          children: [
            CustomPaint(
              size:
                  Size(mainImage.width.toDouble(), mainImage.height.toDouble()),
              painter: CanvasMaskPainter(points, mainImage),
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
          Expanded(
            child: FittedBox(
              alignment: FractionalOffset.center,
              child: ClipRect(
                child: ValueListenableBuilder(
                  valueListenable: _isLoaded,
                  builder: (_, loaded, __) {
                    if (loaded) {
                      return _makeCanvas();
                    } else {
                      return const SizedBox(
                        height: double.maxFinite,
                        width: double.maxFinite,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          // TextFormField(initialValue: "Realistic Landscape, Artstation",),
          ButtonBar(
            alignment: MainAxisAlignment.center,
            children: [
              MaterialButton(
                onPressed: () async {
                  _isLoaded.value =
                      false; // hack to remove and redraw custom painter with new image
                  // (need to investigate why this works)
                  ImagePicker picker = ImagePicker();
                  XFile? image =
                      await picker.pickImage(source: ImageSource.gallery);
                  setState(() {
                    if (image != null) {
                      currentImageSource = 'local';
                      currentImagePath = image.path;
                    }

                    loadImage();
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

  @override
  void dispose() {
    _isLoaded.dispose();
    super.dispose();
  }
}

class CanvasMaskPainter extends CustomPainter {
  List<Offset> points;
  ui.Image mainImage;
  CanvasMaskPainter(this.points, this.mainImage);

  @override
  void paint(Canvas canvas, Size size) {
    var paint1 = Paint()
      ..color = const Color(0xff63aa65)
      ..strokeWidth = 15;

    paintImage(
      image: mainImage,
      canvas: canvas,
      rect:
          Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
      filterQuality: FilterQuality.high,
    );

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPoints(ui.PointMode.points, points, paint1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
