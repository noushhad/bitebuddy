import 'package:flutter/material.dart';

class RestaurantCard extends StatelessWidget {
  final String name;
  final String address;
  final double rating;
  final String imageUrl;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const RestaurantCard({
    super.key,
    required this.name,
    required this.address,
    required this.rating,
    required this.imageUrl,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ImageThumb(imageUrl: imageUrl),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Favorite
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name.isEmpty ? 'Unnamed' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          iconSize: 22,
                          onPressed: onFavoriteToggle,
                          splashRadius: 22,
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          tooltip:
                              isFavorite ? 'Remove favorite' : 'Add favorite',
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Rating chip
                    Row(
                      children: [
                        _RatingPill(rating: rating),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Actions row (optional future actions)
                    Row(
                      children: [
                        Icon(Icons.place,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Tap for details, menu & directions',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final String imageUrl;
  const _ImageThumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width * 0.28; // responsive thumbnail width

    return SizedBox(
      width: width.clamp(110.0, 140.0),
      child: AspectRatio(
        aspectRatio: 1.2, // tall-ish thumbnail
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
          child: imageUrl.isEmpty
              ? _Placeholder()
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return _ShimmerSkeleton();
                  },
                  errorBuilder: (_, __, ___) => _Placeholder(),
                ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceVariant;
    return Container(
        color: color, child: const Icon(Icons.restaurant, size: 32));
  }
}

class _ShimmerSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceVariant;
    final highlight = Theme.of(context).colorScheme.surface;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (_, value, __) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1, -0.2),
              end: Alignment(1, 0.2),
              colors: [
                base,
                Color.lerp(base, highlight, 0.35)!,
                base,
              ],
              stops: [value * 0.2, value * 0.5, value * 0.8],
            ),
          ),
        );
      },
    );
  }
}

class _RatingPill extends StatelessWidget {
  final double rating;
  const _RatingPill({required this.rating});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.secondaryContainer;
    final fg = theme.colorScheme.onSecondaryContainer;

    final display =
        rating.isFinite && rating > 0 ? rating.toStringAsFixed(1) : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ShapeDecoration(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: bg)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(display,
              style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}
