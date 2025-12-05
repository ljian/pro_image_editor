// Dart imports:
import 'dart:developer' as developer;
import 'dart:ui';

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_background_remover/image_background_remover.dart';

// Project imports:
import '../../../core/utils/image_converter.dart';
import '/core/models/editor_configs/pro_image_editor_configs.dart';
import '/core/models/editor_image.dart';
import '/shared/widgets/auto_image.dart';
import '../../tune_editor/models/tune_adjustment_matrix.dart';
import '../types/filter_matrix.dart';
import 'filter_generator.dart';

/// Represents an image where filters and blur factors can be applied.
class FilteredWidget extends StatefulWidget {
  /// Constructor for creating an instance of FilteredImage.
  const FilteredWidget({
    super.key,
    required this.width,
    required this.height,
    required this.configs,
    required this.filters,
    required this.tuneAdjustments,
    required this.blurFactor,
    this.filterKey,
    this.fit = BoxFit.contain,
    this.image,
    this.blankSize,
    this.videoPlayer,
    this.enableCachedSize = false,
    this.removeBackground,
  }) : assert(image != null || videoPlayer != null || blankSize != null,
            'Image or videoPlayer or blankSize cannot be null');

  /// A key that uniquely identifies the [ColorFilterGeneratorState] widget and
  /// allows access to its state. This can be used to manipulate the state of
  /// the color filter generator from outside the widget tree.
  ///
  /// This key is optional and can be null.
  final GlobalKey<ColorFilterGeneratorState>? filterKey;

  /// The width of the image.
  final double width;

  /// The height of the image.
  final double height;

  /// A class representing configuration options for the Image Editor.
  final ProImageEditorConfigs configs;

  /// The list of filters to be applied on the image.
  final FilterMatrix filters;

  /// The list of tune adjustments to be applied on the image.
  final List<TuneAdjustmentMatrix> tuneAdjustments;

  /// The editor image to display.
  final EditorImage? image;

  /// The video player to display.
  final Widget? videoPlayer;

  /// How the image should be inscribed into the space allocated for it.
  final BoxFit fit;

  /// The size of the blank canvas when no image is present.
  final Size? blankSize;

  /// The blur factor
  final double blurFactor;

  /// Indicate to the engine that the image must be decoded at the specified
  /// size.
  final bool enableCachedSize;
  final bool? removeBackground;

  @override
  State<FilteredWidget> createState() => _FilteredWidgetState();
}

class _FilteredWidgetState extends State<FilteredWidget> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        // StackFit.expand is important for [transformed_content_generator.dart]
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          ColorFilterGenerator(
            key: widget.filterKey,
            filters: widget.filters,
            tuneAdjustments: widget.tuneAdjustments,
            child: FutureBuilder<Widget>(future: _buildContent(context), builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
              if (snapshot.hasData) {
                return snapshot.data!;
              } else {
                return _buildContentOrigin(context, widget.image!);
              }
            }),
          ),
          if (widget.blurFactor > 0) _buildBlur(),
        ],
      ),
    );
  }

  Widget _buildBlur() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: widget.blurFactor, sigmaY: widget.blurFactor),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
        ),
      ),
    );
  }

  Future<Widget> _buildContent(BuildContext context) async {
    developer.log("BackgroundRemover.instance.removeBg ${widget.removeBackground}");
    EditorImage? imageResult = widget.image;
    if (widget.removeBackground != null) {
      final resultImage = await BackgroundRemover.instance.removeBg(
        await widget.image!.safeByteArray(context),
        threshold: 0.5,
        enhanceEdges: true,
        smoothMask: true,
      );
      imageResult = EditorImage(byteArray: await ImageConverter.instance.uiImageToImageBytes(
        resultImage,
        context: context,
      ));
    }

    return _buildContentOrigin(context, imageResult!);
  }

  Widget _buildContentOrigin(BuildContext context, EditorImage? imageResult) {
    if (widget.videoPlayer != null) return widget.videoPlayer!;
    if (imageResult != null) {
      return AutoImage(
        imageResult,
        enableCachedSize: widget.enableCachedSize,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        configs: widget.configs,
      );
    }
    return SizedBox.fromSize(size: widget.blankSize);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);

    properties
      ..add(DoubleProperty('width', widget.width))
      ..add(DoubleProperty('height', widget.height))
      ..add(DiagnosticsProperty<FilterMatrix>('filters', widget.filters))
      ..add(IterableProperty<TuneAdjustmentMatrix>(
          'tuneAdjustments', widget.tuneAdjustments))
      ..add(DoubleProperty('blurFactor', widget.blurFactor))
      ..add(EnumProperty<BoxFit>('fit', widget.fit))
      ..add(FlagProperty('enableCachedSize',
          value: widget.enableCachedSize, ifTrue: 'cached size enabled'))
      ..add(DiagnosticsProperty<EditorImage?>('image', widget.image))
      ..add(FlagProperty('hasVideoPlayer',
          value: widget.videoPlayer != null, ifTrue: 'video player set'));
  }
}
