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
  late TransformationController tfmController;
  late ui.Image mainImage;
  String currentImageSource = 'asset';
  String currentImagePath = ("assets/sample.png");
  late Uint8List currentImageBytes;
  BlendMode currMode = BlendMode.srcOver;
  StrokeMaker strokeMaker = StrokeMaker();

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
    return tfmController.toScene(o);
  }

  Widget _makeCanvas() {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
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

            points.add(strokeMaker.currStroke);
          }
        });
      },
      onInteractionUpdate: (event) {
        setState(() {
          if (event.pointerCount == 1) {
            strokeMaker.addPoint(transformOffset(event.localFocalPoint));
            points.removeLast();
            points.add(strokeMaker.currStroke);
          }
        });
      },
      clipBehavior: Clip.hardEdge,
      panEnabled: false,
      scaleEnabled: true,
      transformationController: tfmController,
      child: CustomPaint(
        size: Size(mainImage.width.toDouble(), mainImage.height.toDouble()),
        painter: CanvasMaskPainter(
            points: points,
            mainImage: mainImage,
            strokeWidthNotifier: strokeWidthNotifier,
            strokeMaker: strokeMaker),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                            max: 100.0,
                            divisions: 20,
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
              IconButton(
                onPressed: () {
                  if (points.isNotEmpty) {
                    points.removeLast();
                  }
                },
                icon: const Icon(
                  Icons.redo,
                  color: Colors.blue,
                ),
              ),
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
          Expanded(
            child: FittedBox(
              clipBehavior: Clip.hardEdge,
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              style: TextStyle(
                color: Colors.black,
              ),
              decoration: InputDecoration(
                suffixIcon: Icon(color: Colors.blue, Icons.send),
                fillColor: Colors.white,
                filled: true,
                hintText: "Realistic Landscape, Artstation",
              ),
              minLines: 1,
              maxLines: 2,
            ),
          ),
          ButtonBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(Colors.blue),
                ),
                onPressed: null,
                child: const Text(
                  "Save",
                  style: TextStyle(color: Colors.white),
                ),
              ),
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
