import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../develop/upload_to_dev_serve.dart';
import '../model/photo_provider.dart';
import '../util/common_util.dart';
import '../widget/dialog/list_dialog.dart';
import '../widget/image_item_widget.dart';
import '../widget/loading_widget.dart';

import 'copy_to_another_gallery_example.dart';
import 'detail_page.dart';
import 'move_to_another_gallery_example.dart';

class GalleryContentListPage extends StatefulWidget {
  const GalleryContentListPage({
    Key? key,
    required this.path,
  }) : super(key: key);

  final AssetPathEntity path;

  @override
  _GalleryContentListPageState createState() => _GalleryContentListPageState();
}

class _GalleryContentListPageState extends State<GalleryContentListPage> {
  late final PhotoProvider photoProvider = Provider.of<PhotoProvider>(context);

  AssetPathEntity get path => widget.path;

  AssetPathProvider readPathProvider(BuildContext c) =>
      c.read<AssetPathProvider>();

  AssetPathProvider watchPathProvider(BuildContext c) =>
      c.watch<AssetPathProvider>();

  @override
  void initState() {
    super.initState();
    path
        .getAssetListRange(start: 0, end: path.assetCount)
        .then((List<AssetEntity> value) {
      if (value.isEmpty) {
        return;
      }
      if (mounted) {
        return;
      }
      PhotoCachingManager().requestCacheAssets(
        assets: value,
        option: thumbOption,
      );
    });
  }

  @override
  void dispose() {
    PhotoCachingManager().cancelCacheRequest();
    super.dispose();
  }

  ThumbnailOption get thumbOption => ThumbnailOption(
        size: const ThumbnailSize.square(200),
        format: photoProvider.thumbFormat,
      );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AssetPathProvider>(
      create: (_) => AssetPathProvider(widget.path),
      builder: (BuildContext context, _) => Scaffold(
        appBar: AppBar(title: Text(path.name)),
        body: buildRefreshIndicator(context, path.assetCount),
      ),
    );
  }

  Widget buildRefreshIndicator(BuildContext context, int length) {
    return RefreshIndicator(
      onRefresh: () => _onRefresh(context),
      child: Scrollbar(
        child: CustomScrollView(
          slivers: <Widget>[
            Consumer<AssetPathProvider>(
              builder: (BuildContext c, AssetPathProvider p, _) => SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, int index) => Builder(
                    builder: (BuildContext c) => _buildItem(context, index),
                  ),
                  childCount: p.showItemCount,
                  findChildIndexCallback: (Key? key) {
                    if (key is ValueKey<String>) {
                      return findChildIndexBuilder(
                        id: key.value,
                        assets: p.list,
                      );
                    }
                    return null;
                  },
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  mainAxisSpacing: 2,
                  crossAxisCount: 4,
                  crossAxisSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final List<AssetEntity> list = watchPathProvider(context).list;
    if (list.length == index) {
      onLoadMore(context);
      return loadWidget;
    }

    if (index > list.length) {
      return Container();
    }

    final AssetEntity entity = list[index];

    return ImageItemWidget(
      key: ValueKey<String>(entity.id),
      entity: entity,
      option: thumbOption,
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => ListDialog(
          children: <Widget>[
            if (entity.type == AssetType.image)
              ElevatedButton(
                child: const Text('Show origin bytes image in dialog'),
                onPressed: () => showOriginBytes(entity),
              ),
            ElevatedButton(
              child: const Text('isLocallyAvailable'),
              onPressed: () => entity.isLocallyAvailable.then(
                (bool r) => print('isLocallyAvailable: $r'),
              ),
            ),
            ElevatedButton(
              child: const Text('getMediaUrl'),
              onPressed: () async {
                final Stopwatch watch = Stopwatch()..start();
                final String? url = await entity.getMediaUrl();
                watch.stop();
                print('Media URL: $url');
                print(watch.elapsed);
              },
            ),
            ElevatedButton(
              child: const Text('Show detail page'),
              onPressed: () => routeToDetailPage(entity),
            ),
            ElevatedButton(
              child: const Text('Show info dialog'),
              onPressed: () => CommonUtil.showInfoDialog(context, entity),
            ),
            ElevatedButton(
              child: const Text('show 500 size thumb '),
              onPressed: () => showThumb(entity, 500),
            ),
            ElevatedButton(
              child: const Text('Delete item'),
              onPressed: () => _deleteCurrent(context, entity),
            ),
            ElevatedButton(
              child: const Text('Upload to my test server.'),
              onPressed: () => UploadToDevServer.upload(entity),
            ),
            ElevatedButton(
              child: const Text('Copy to another path'),
              onPressed: () => copyToAnotherPath(entity),
            ),
            _buildMoveAnotherPath(entity),
            _buildRemoveInAlbumWidget(entity),
            ElevatedButton(
              child: const Text('Test progress'),
              onPressed: () => testProgressHandler(entity),
            ),
            ElevatedButton(
              child: const Text('Test thumb size'),
              onPressed: () => testThumbSize(
                entity,
                <int>[500, 600, 700, 1000, 1500, 2000],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int findChildIndexBuilder({
    required String id,
    required List<AssetEntity> assets,
  }) {
    return assets.indexWhere((AssetEntity e) => e.id == id);
  }

  Future<void> routeToDetailPage(AssetEntity entity) async {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => DetailPage(entity: entity)),
    );
  }

  Future<void> onLoadMore(BuildContext context) async {
    if (!mounted) {
      return;
    }
    await readPathProvider(context).onLoadMore();
  }

  Future<void> _onRefresh(BuildContext context) async {
    if (!mounted) {
      return;
    }
    await readPathProvider(context).onRefresh();
  }

  Future<void> _deleteCurrent(BuildContext context, AssetEntity entity) async {
    if (Platform.isAndroid) {
      final AlertDialog dialog = AlertDialog(
        title: const Text('Delete the asset'),
        actions: <Widget>[
          TextButton(
            child: const Text(
              'delete',
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () async {
              readPathProvider(context).delete(entity);
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
      showDialog<void>(context: context, builder: (_) => dialog);
    } else {
      readPathProvider(context).delete(entity);
    }
  }

  Future<void> showOriginBytes(AssetEntity entity) async {
    final String title;
    if (entity.title?.isEmpty != false) {
      title = await entity.titleAsync;
    } else {
      title = entity.title!;
    }
    print('entity.title = $title');
    showDialog<void>(
      context: context,
      builder: (_) {
        return FutureBuilder<Uint8List?>(
          future: entity.originBytes,
          builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
            Widget w;
            if (snapshot.hasError) {
              return ErrorWidget(snapshot.error!);
            } else if (snapshot.hasData) {
              w = Image.memory(snapshot.data!);
            } else {
              w = Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: const CircularProgressIndicator(),
                ),
              );
            }
            return GestureDetector(
              child: w,
              onTap: () => Navigator.pop(context),
            );
          },
        );
      },
    );
  }

  Future<void> copyToAnotherPath(AssetEntity entity) {
    return Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CopyToAnotherGalleryPage(assetEntity: entity),
      ),
    );
  }

  Widget _buildRemoveInAlbumWidget(AssetEntity entity) {
    if (!(Platform.isIOS || Platform.isMacOS)) {
      return Container();
    }

    return ElevatedButton(
      child: const Text('Remove in album'),
      onPressed: () => deleteAssetInAlbum(entity),
    );
  }

  void deleteAssetInAlbum(AssetEntity entity) {
    readPathProvider(context).removeInAlbum(entity);
  }

  Widget _buildMoveAnotherPath(AssetEntity entity) {
    if (!Platform.isAndroid) {
      return Container();
    }
    return ElevatedButton(
      onPressed: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MoveToAnotherExample(entity: entity),
        ),
      ),
      child: const Text('Move to another gallery.'),
    );
  }

  Future<void> showThumb(AssetEntity entity, int size) async {
    final String title;
    if (entity.title?.isEmpty != false) {
      title = await entity.titleAsync;
    } else {
      title = entity.title!;
    }
    print('entity.title = $title');
    return showDialog(
      context: context,
      builder: (_) {
        return FutureBuilder<Uint8List?>(
          future: entity.thumbnailDataWithOption(
            ThumbnailOption.ios(
              size: const ThumbnailSize.square(500),
              // resizeContentMode: ResizeContentMode.fill,
            ),
          ),
          builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
            Widget w;
            if (snapshot.hasError) {
              return ErrorWidget(snapshot.error!);
            } else if (snapshot.hasData) {
              final Uint8List data = snapshot.data!;
              ui.decodeImageFromList(data, (ui.Image result) {
                print('result size: ${result.width}x${result.height}');
                // for 4288x2848
              });
              w = Image.memory(data);
            } else {
              w = Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: const CircularProgressIndicator(),
                ),
              );
            }
            return GestureDetector(
              child: w,
              onTap: () => Navigator.pop(context),
            );
          },
        );
      },
    );
  }

  Future<void> testProgressHandler(AssetEntity entity) async {
    final PMProgressHandler progressHandler = PMProgressHandler();
    progressHandler.stream.listen((PMProgressState event) {
      final double progress = event.progress;
      print('progress state onChange: ${event.state}, progress: $progress');
    });
    // final file = await entity.loadFile(progressHandler: progressHandler);
    // print('file = $file');

    // final thumb = await entity.thumbDataWithSize(
    //   300,
    //   300,
    //   progressHandler: progressHandler,
    // );

    // print('thumb length = ${thumb.length}');

    final File? file = await entity.loadFile(
      progressHandler: progressHandler,
    );
    print('file = $file');
  }

  Future<void> testThumbSize(AssetEntity entity, List<int> list) async {
    for (final int size in list) {
      // final data = await entity.thumbDataWithOption(ThumbOption.ios(
      //   width: size,
      //   height: size,
      //   resizeMode: ResizeMode.exact,
      // ));
      final Uint8List? data = await entity.thumbnailDataWithSize(
        ThumbnailSize.square(size),
      );

      if (data == null) {
        return;
      }
      ui.decodeImageFromList(data, (ui.Image result) {
        print(
          'size: $size, '
          'length: ${data.length}, '
          'width*height: ${result.width}x${result.height}',
        );
      });
    }
  }
}
