import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../library/models.dart';
import '../../ui/media_cards.dart';
import '../../ui/theme.dart';
import '../detail/detail_screen.dart';

/// All titles of a library as a poster grid.
class LibraryGrid extends StatelessWidget {
  const LibraryGrid({super.key, required this.library});

  final MediaLibrary library;

  @override
  Widget build(BuildContext context) {
    final store = context.services.store;
    final wide = Breakpoints.isWide(context);
    return Scaffold(
      appBar: AppBar(title: Text(library.name)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final titles = store.titlesOfLibrary(library.id);
          return LayoutBuilder(builder: (context, c) {
            final pad = wide ? Space.xxl : Space.l;
            final target = wide ? 170.0 : 120.0;
            final cols = ((c.maxWidth - pad * 2 + Space.l) / (target + Space.l)).floor().clamp(2, 12);
            final w = (c.maxWidth - pad * 2 - Space.l * (cols - 1)) / cols;
            return GridView.builder(
              padding: EdgeInsets.fromLTRB(pad, Space.s, pad, Space.xxxl),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: Space.l,
                mainAxisSpacing: Space.xl,
                childAspectRatio: w / (w * 1.5 + 26),
              ),
              itemCount: titles.length,
              itemBuilder: (context, i) => PosterCard(
                title: titles[i],
                width: w,
                autofocus: i == 0,
                onTap: () => DetailScreen.open(context, titles[i].key),
              ),
            );
          });
        },
      ),
    );
  }
}
