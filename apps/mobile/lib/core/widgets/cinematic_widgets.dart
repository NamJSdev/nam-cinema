import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nam_cinema/core/theme/app_theme.dart';
import 'package:nam_cinema/features/home/domain/media_models.dart';

class RatingBadge extends StatelessWidget {
  final double rating;

  const RatingBadge({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: NamCinemaColors.warning.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: NamCinemaColors.warning, size: 13),
          const SizedBox(width: 3),
          Text(
            rating > 0 ? rating.toStringAsFixed(1) : 'Mới',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class StreamingProviderBadge extends StatelessWidget {
  final String availabilityBadge;
  final String? customLabel;

  const StreamingProviderBadge({
    super.key,
    required this.availabilityBadge,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    late final Color badgeColor;
    late final String label;
    late final IconData icon;

    switch (availabilityBadge) {
      case 'playable':
        badgeColor = NamCinemaColors.playableBadge;
        label = customLabel ?? 'PHÁT NGAY';
        icon = Icons.play_circle_fill_rounded;
        break;
      case 'external':
        badgeColor = NamCinemaColors.externalBadge;
        label = customLabel ?? 'ĐỐI TÁC';
        icon = Icons.open_in_new_rounded;
        break;
      default:
        badgeColor = NamCinemaColors.secondaryText;
        label = customLabel ?? 'THÔNG TIN';
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withOpacity(0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class GenreChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const GenreChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? NamCinemaColors.primaryAccent : NamCinemaColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? NamCinemaColors.primaryAccent
                : NamCinemaColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : NamCinemaColors.secondaryText,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: NamCinemaColors.primaryAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NamCinemaColors.primaryText,
                    fontSize: 17.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: NamCinemaColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text(
                'Xem tất cả',
                style: TextStyle(
                  color: NamCinemaColors.primaryAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PremiumButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;

  const PremiumButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? NamCinemaColors.primaryAccent
              : NamCinemaColors.surface,
          foregroundColor: Colors.white,
          elevation: isPrimary ? 4 : 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isPrimary
                ? BorderSide.none
                : const BorderSide(color: NamCinemaColors.divider),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class CinematicNetImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CinematicNetImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final child = (imageUrl == null || imageUrl!.isEmpty)
        ? Container(
            width: width,
            height: height,
            color: NamCinemaColors.surface,
            alignment: Alignment.center,
            child: const Icon(
              Icons.movie_creation_outlined,
              color: NamCinemaColors.secondaryText,
              size: 32,
            ),
          )
        : CachedNetworkImage(
            imageUrl: imageUrl!,
            width: width,
            height: height,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 220),
            placeholder: (_, __) => Container(
              width: width,
              height: height,
              color: NamCinemaColors.surface,
            ),
            errorWidget: (_, __, ___) => Container(
              width: width,
              height: height,
              color: NamCinemaColors.surface,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: NamCinemaColors.secondaryText,
                size: 28,
              ),
            ),
          );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}

class MoviePosterCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final double width;

  const MoviePosterCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 136,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CinematicNetImage(
                    imageUrl: item.posterUrl,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: RatingBadge(rating: item.voteAverage),
                  ),
                  if (item.availabilityBadge == 'playable')
                    const Positioned(
                      bottom: 8,
                      right: 8,
                      child: StreamingProviderBadge(
                        availabilityBadge: 'playable',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NamCinemaColors.primaryText,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.releaseYear.isNotEmpty
                  ? '${item.releaseYear} • ${item.contentType == "tv" ? "Phim bộ" : "Phim lẻ"}'
                  : (item.contentType == 'tv' ? 'Phim bộ' : 'Phim lẻ'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NamCinemaColors.secondaryText,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MovieLandscapeCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final double width;

  const MovieLandscapeCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 240,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CinematicNetImage(
                    imageUrl: item.backdropUrl ?? item.posterUrl,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.75),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: StreamingProviderBadge(
                      availabilityBadge: item.availabilityBadge,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 10,
                    right: 10,
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContinueWatchingCard extends StatelessWidget {
  final WatchHistoryModel item;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const ContinueWatchingCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onRemove,
  });

  String _formatRemaining() {
    final remaining = (item.durationSeconds - item.currentPositionSeconds).clamp(0, 86400);
    final minutes = (remaining / 60).ceil();
    return 'Còn $minutes phút';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: NamCinemaColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NamCinemaColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CinematicNetImage(
                    imageUrl: item.backdropPath ?? item.posterPath,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: NamCinemaColors.primaryAccent.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  if (onRemove != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: Colors.white,
                        onPressed: onRemove,
                      ),
                    ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: item.progressRatio.clamp(0.02, 1.0),
              backgroundColor: NamCinemaColors.divider,
              color: NamCinemaColors.primaryAccent,
              minHeight: 3.5,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NamCinemaColors.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatRemaining(),
                    style: const TextStyle(
                      color: NamCinemaColors.secondaryText,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeroBanner extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onDetailsTap;
  final VoidCallback? onPlayTap;

  const HeroBanner({
    super.key,
    required this.item,
    required this.onDetailsTap,
    this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDetailsTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CinematicNetImage(
            imageUrl: item.backdropUrl ?? item.posterUrl,
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.45, 0.85, 1.0],
                colors: [
                  Color(0x6608090D),
                  Colors.transparent,
                  Color(0xCC08090D),
                  NamCinemaColors.primaryBackground,
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    StreamingProviderBadge(
                      availabilityBadge: item.availabilityBadge,
                    ),
                    const SizedBox(width: 8),
                    RatingBadge(rating: item.voteAverage),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                if (item.overview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.overview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NamCinemaColors.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (item.isDirectlyPlayable && onPlayTap != null) ...[
                      PremiumButton(
                        label: 'Xem Ngay',
                        icon: Icons.play_arrow_rounded,
                        onPressed: onPlayTap,
                      ),
                      const SizedBox(width: 12),
                    ],
                    PremiumButton(
                      label: 'Chi Tiết',
                      icon: Icons.info_outline_rounded,
                      isPrimary: !item.isDirectlyPlayable,
                      onPressed: onDetailsTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeaturedCarousel extends StatefulWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item) onDetailsTap;
  final void Function(MediaItem item)? onPlayTap;

  const FeaturedCarousel({
    super.key,
    required this.items,
    required this.onDetailsTap,
    this.onPlayTap,
  });

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  late final PageController _controller;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 410,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (idx) => setState(() => _activeIndex = idx),
            itemBuilder: (_, index) {
              final item = widget.items[index];
              return HeroBanner(
                item: item,
                onDetailsTap: () => widget.onDetailsTap(item),
                onPlayTap: widget.onPlayTap != null
                    ? () => widget.onPlayTap!(item)
                    : null,
              );
            },
          ),
          Positioned(
            bottom: 8,
            right: 20,
            child: Row(
              children: List.generate(
                widget.items.length,
                (idx) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.only(left: 5),
                  width: _activeIndex == idx ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _activeIndex == idx
                        ? NamCinemaColors.primaryAccent
                        : NamCinemaColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CastCard extends StatelessWidget {
  final CastMemberModel member;

  const CastCard({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          CinematicNetImage(
            imageUrl: member.profileUrl,
            width: 72,
            height: 72,
            borderRadius: BorderRadius.circular(36),
          ),
          const SizedBox(height: 6),
          Text(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NamCinemaColors.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (member.character != null && member.character!.isNotEmpty)
            Text(
              member.character!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NamCinemaColors.secondaryText,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

class LoadingSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 180,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: NamCinemaColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: NamCinemaColors.secondaryText),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NamCinemaColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NamCinemaColors.secondaryText,
                fontSize: 13.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Đã xảy ra sự cố kết nối',
      subtitle: message,
      action: PremiumButton(
        label: 'Thử Lại',
        icon: Icons.refresh_rounded,
        onPressed: onRetry,
      ),
    );
  }
}

class NamCinemaSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final String hintText;

  const NamCinemaSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
    this.hintText = 'Tìm phim lẻ, phim bộ, diễn viên...',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: NamCinemaColors.primaryText, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: NamCinemaColors.secondaryText,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                onPressed: onClear,
                icon: const Icon(
                  Icons.clear_rounded,
                  color: NamCinemaColors.secondaryText,
                ),
              )
            : null,
      ),
    );
  }
}

class NamCinemaBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const NamCinemaBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NamCinemaColors.secondaryBackground,
        border: Border(
          top: BorderSide(color: NamCinemaColors.divider, width: 1),
        ),
      ),
      child: NavigationBar(
        height: 66,
        backgroundColor: NamCinemaColors.secondaryBackground,
        indicatorColor: NamCinemaColors.primaryAccent.withOpacity(0.18),
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(
              Icons.home_rounded,
              color: NamCinemaColors.primaryAccent,
            ),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(
              Icons.search_rounded,
              color: NamCinemaColors.primaryAccent,
            ),
            label: 'Tìm kiếm',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(
              Icons.bookmark_rounded,
              color: NamCinemaColors.primaryAccent,
            ),
            label: 'Danh sách',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: NamCinemaColors.primaryAccent,
            ),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}
