import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

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
  List<Stroke> points = [];
  List<double> currTransform = [0.0, 0.0, 1.0]; // [x,y,scale]
  late TapDownDetails doubleTapDetails;
  late TransformationController tfmController;
  bool isZoomed = false;
  late ui.Image mainImage;
  String currentImageSource = 'asset';
  String currentImagePath = ("assets/sample.png");
  late Uint8List currentImageBytes;
  BlendMode currMode = BlendMode.srcOver;
  StrokeMaker strokeMaker = StrokeMaker();
  int pointsTick = 0;

  ValueNotifier<double> strokeWidthNotifier = ValueNotifier(6.0);
  late final ValueNotifier<bool> _isLoaded;

  Future<ui.Image> imageWidgetFromBytes(Uint8List? bytes) async {
    final completer = Completer<ui.Image>();

    ui.decodeImageFromList(bytes!, (image) {
      return completer.complete(image);
    });

    return await completer.future;
  }

  void loadImage() async {
    Uint8List img;
    if (currentImageSource == 'File') {
      img = await File(currentImagePath).readAsBytes();
      currentImageBytes = img;
    } else if (currentImageSource == 'asset') {
      final bytes = await rootBundle.load(currentImagePath);
      img = bytes.buffer.asUint8List();
      currentImageBytes = img;
    }
    setMainImage(await imageWidgetFromBytes(currentImageBytes));
  }

  void setMainImage(ui.Image img) {
    _isLoaded.value = true;
    mainImage = img;
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
    // Matrix4 zoomed = Matrix4.identity();
    // double x, y, scale;
    // scale = event is ScaleStartDetails ? 1.0 : event.scale;
    // if (1.0 <= scale && scale <= 4.0) {
    //   print(scale);
    //   x = -event.focalPoint.dx * (scale - 1);
    //   y = -event.focalPoint.dy * (scale - 1);
    //   zoomed
    //     ..translate(x, y)
    //     ..scale(scale);
    //   setState(() {
    //     currTransform = [x, y, scale];
    //   });
    // }
    return;
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
        onInteractionStart: (event) {
          setState(() {
            if (event.pointerCount == 1) {
              strokeMaker.start(transformOffset(event.localFocalPoint),
                  strokeWidthNotifier.value, currMode);

              strokeMaker.currStroke.paint = Paint()
                ..color = const Color(0xff63aa65)
                ..strokeWidth = strokeMaker.currStroke.width
                ..style = PaintingStyle.stroke
                ..blendMode = strokeMaker.currStroke.mode;

              // points.add(strokeMaker.currStroke);

            } else {
              interactionZoom(event);
            }
          });
        },
        onInteractionUpdate: (event) {
          setState(() {
            if (event.pointerCount == 1) {
              strokeMaker.addPoint(transformOffset(event.localFocalPoint));

              strokeMaker.currStroke.paint = Paint()
                ..color = const Color(0xff63aa65)
                ..strokeWidth = strokeMaker.currStroke.width
                ..style = PaintingStyle.stroke
                ..blendMode = strokeMaker.currStroke.mode;

              pointsTick++;
              if (pointsTick%10 == 0) {
                points.add(strokeMaker.currStroke);

                strokeMaker.start(transformOffset(event.localFocalPoint),
                    strokeWidthNotifier.value, currMode);

                setState(() {
                  pointsTick = 0;
                });
              }
              // points.add(transformOffset(event.localFocalPoint));
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
              painter: CanvasMaskPainter(
                  points: points,
                  mainImage: mainImage,
                  strokeWidthNotifier: strokeWidthNotifier,
                  strokeMaker: strokeMaker),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("SD2 Canvas"),
      ),
      body: Column(
        children: [
          ButtonBar(
            children: [
              IconButton(
                  onPressed: () {
                    setState(() {
                      currMode = currMode == BlendMode.clear
                          ? BlendMode.srcOver
                          : BlendMode.clear;
                    });
                  },
                  icon: Icon(Icons.chrome_reader_mode,
                      color: currMode == BlendMode.clear
                          ? Colors.blue
                          : Colors.grey)),
              PopupMenuButton(
                  position: PopupMenuPosition.under,
                  color: Colors.black12,
                  icon: const Icon(
                    Icons.line_weight,
                    color: Colors.blue,
                  ),
                  itemBuilder: (_) {
                    return [
                      PopupMenuItem(child: StatefulBuilder(
                        builder: (BuildContext context, StateSetter setState) {
                          return Slider(
                            value: strokeWidthNotifier.value,
                            min: 6.0,
                            max: 60.0,
                            divisions: 15,
                            onChanged: (double newVal) {
                              setState(() {
                                strokeWidthNotifier.value = newVal;
                              });
                            },
                          );
                        },
                      ))
                    ];
                  }),
            ],
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
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
            alignment: MainAxisAlignment.end,
            children: [
              IconButton(
                  onPressed: () {
                    points.removeLast();
                  },
                  icon: const Icon(
                    Icons.redo,
                    color: Colors.blue,
                  )),
              IconButton(
                icon: const Icon(Icons.add_a_photo_sharp),
                onPressed: () async {
                  _isLoaded.value =
                      false; // hack to remove and redraw custom painter with new image
                  // (need to investigate why this works)
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'png']);

                  if (kIsWeb && result != null && result.files.isNotEmpty) {
                    Uint8List? bytes = result.files.first.bytes;
                    setMainImage(await imageWidgetFromBytes(bytes));
                    setState(() {
                      currentImageSource = 'as_bytes';
                      currentImageBytes = bytes!;
                    });
                  } else if (!kIsWeb) {
                    String? path = result?.files.single.path;
                    // ImagePicker picker = ImagePicker();

                    if (path != null) {
                      setState(() {
                        currentImageSource = 'File';
                        currentImagePath = path;
                      });
                    }
                  }

                  loadImage(); // load image regardless, if the pick image
                  // action was cancelled this will load the prev image

                  // XFile? image =
                  //     await picker.pickImage(source: ImageSource.gallery);
                  // setState(() {
                  //   if (image != null) {
                  //     currentImageSource = 'local';
                  //     currentImagePath = image.path;
                  //   }
                  //
                  //   loadImage();
                  // });
                },
                color: Colors.blue,
              ),
              IconButton(
                  onPressed: () {
                    points.clear();
                  },
                  icon: const Icon(
                    Icons.cancel,
                    color: Colors.blue,
                  ))
            ],
          ),
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

class Stroke {
  late Path path;
  late double width;
  late BlendMode mode;
  late Paint paint;
}

class StrokeMaker {
  late Stroke currStroke;
  late int status = 0; // 0 for no stroke in progress , 1 for stroke in progress

  void start(Offset startOffset, double width, BlendMode mode) {
    status = 1;
    currStroke = Stroke()
      ..path = (Path()..moveTo(startOffset.dx, startOffset.dy))
      ..width = width
      ..mode = mode;
  }

  void addPoint(Offset point) {
    currStroke.path.lineTo(point.dx, point.dy);
  }

  Stroke getStroke() {
    status = 0;
    return currStroke;
  }
}

class CanvasMaskPainter extends CustomPainter {
  List<Stroke> points;
  ui.Image mainImage;
  late StrokeMaker strokeMaker;
  ValueNotifier<double> strokeWidthNotifier;
  CanvasMaskPainter(
      {required this.points,
      required this.mainImage,
      required this.strokeWidthNotifier,
      required this.strokeMaker})
      : super(repaint: strokeWidthNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    var paint1 = Paint()
      ..color = const Color(0xff63aa65)
      ..strokeWidth = strokeWidthNotifier.value
      ..style = PaintingStyle.stroke;

    paintImage(
      image: mainImage,
      canvas: canvas,
      rect:
          Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
      filterQuality: FilterQuality.high,
    );
    //save base layer
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // add brush strokes
    for (int i = 0; i < points.length; i++) {
      canvas.drawPath(points[i].path, points[i].paint);
    }

    // blend erased-brush with base
    canvas.restore();

    // canvas.drawPoints(ui.PointMode.points, points, paint1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
