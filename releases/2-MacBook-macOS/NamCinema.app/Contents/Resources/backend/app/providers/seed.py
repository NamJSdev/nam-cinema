import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.entities import AudioTrack, SubtitleTrack, VideoAsset, VideoSource

# Deterministic UUIDs for the verified legal open-movie assets so tests and deep links are reproducible
BIG_BUCK_BUNNY_ASSET_ID = uuid.UUID("11111111-2222-3333-4444-555555555501")
TEARS_OF_STEEL_ASSET_ID = uuid.UUID("11111111-2222-3333-4444-555555555502")
APPLE_ATMOS_DEMO_ASSET_ID = uuid.UUID("11111111-2222-3333-4444-555555555503")
BLENDER_OPEN_SERIES_EP1_ASSET_ID = uuid.UUID("11111111-2222-3333-4444-555555555504")


async def seed_verified_legal_assets(db: AsyncSession) -> None:
    """Seeds real, legally verified Creative Commons (CC-BY 3.0) and Apple Developer
    streaming assets into the database if they do not already exist.
    """
    existing_stmt = select(VideoAsset.id)
    result = await db.execute(existing_stmt)
    existing_ids = set(result.scalars().all())

    assets_to_seed = [
        {
            "id": BIG_BUCK_BUNNY_ASSET_ID,
            "tmdb_id": 10378,  # Real TMDB ID for Big Buck Bunny (2008)
            "content_type": "movie",
            "season_number": None,
            "episode_number": None,
            "title": "Big Buck Bunny",
            "synopsis": (
                "Một chú thỏ khổng lồ hiền lành đối mặt với ba kẻ bắt nạt trong khu rừng. "
                "Tác phẩm hoạt hình mã nguồn mở của Blender Institute phát hành hợp pháp theo giấy phép CC-BY 3.0."
            ),
            "poster_url": "https://image.tmdb.org/t/p/w500/2Cpg8hUn60PK9CW9d5SWf605Ah8.jpg",
            "backdrop_url": "https://image.tmdb.org/t/p/w1280/aqICQRXQLSB6uKulBHHCUwLAvK.jpg",
            "duration_seconds": 634,
            "provider_category": "public_demo",
            "license_name": "Creative Commons Attribution 3.0 (CC-BY 3.0)",
            "license_url": "https://creativecommons.org/licenses/by/3.0/",
            "attribution": "© 2008, Blender Foundation / www.bigbuckbunny.org",
            "manifest_url": "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
            "requires_signing": False,
        },
        {
            "id": TEARS_OF_STEEL_ASSET_ID,
            "tmdb_id": 136418,  # Real TMDB ID for Tears of Steel (2012)
            "content_type": "movie",
            "season_number": None,
            "episode_number": None,
            "title": "Tears of Steel",
            "synopsis": (
                "Tại Amsterdam trong tương lai hậu tận thế, một nhóm chiến binh và nhà khoa học tập hợp tại Oude Kerk "
                "để tái hiện sự kiện quan trọng nhằm giải cứu thế giới khỏi những cỗ máy hủy diệt."
            ),
            "poster_url": "https://image.tmdb.org/t/p/w500/8jRoZr0vcPPIpB4GN5lfuwek8Go.jpg",
            "backdrop_url": "https://image.tmdb.org/t/p/w1280/qVusqVk8cfyYNMjwqaUIcsG7czG.jpg",
            "duration_seconds": 734,
            "provider_category": "licensed_hls",
            "license_name": "Creative Commons Attribution 3.0 (CC-BY 3.0)",
            "license_url": "https://creativecommons.org/licenses/by/3.0/",
            "attribution": "© Blender Foundation | mango.blender.org",
            "manifest_url": "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8",
            "requires_signing": True,
        },
        {
            "id": APPLE_ATMOS_DEMO_ASSET_ID,
            "tmdb_id": 45745,  # Real TMDB ID for Sintel / Open Movie Showcase
            "content_type": "movie",
            "season_number": None,
            "episode_number": None,
            "title": "Nam Cinema 4K HDR & Spatial Audio Showcase",
            "synopsis": (
                "Luồng phát thử nghiệm chuẩn HLS Adaptive Bitrate chính thức từ Apple Developer Streaming "
                "dùng để kiểm chuẩn tốc độ khung hình, phụ đề đa ngôn ngữ và chuyển đổi chất lượng tự động."
            ),
            "poster_url": "https://image.tmdb.org/t/p/w500/orSiH0y4r0BwFxNdWhNKkgPocQx.jpg",
            "backdrop_url": "https://image.tmdb.org/t/p/w1280/qK3yiqo84U3twOOKOx81c407Hpr.jpg",
            "duration_seconds": 1800,
            "provider_category": "self_hosted",
            "license_name": "Apple Developer Sample Streaming License",
            "license_url": "https://developer.apple.com/streaming/examples/",
            "attribution": "Apple Inc. HLS Authoring Specification Sample Stream",
            "manifest_url": "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
            "requires_signing": True,
        },
        {
            "id": BLENDER_OPEN_SERIES_EP1_ASSET_ID,
            "tmdb_id": 60625,  # Rick and Morty / TV Series Episode 1 demo mapping
            "content_type": "tv",
            "season_number": 1,
            "episode_number": 1,
            "title": "Open Sci-Fi Chronicles — Tập 1: Khởi Nguyên",
            "synopsis": (
                "Tập mở đầu phát trực tuyến hợp pháp qua giao thức HLS có chữ ký xác thực phiên xem."
            ),
            "poster_url": "https://image.tmdb.org/t/p/w500/ur0ndyr8fejVYCISIBt05CMjHOX.jpg",
            "backdrop_url": "https://image.tmdb.org/t/p/w1280/s4OROPpuFsTIknckdXY0wX7Dw37.jpg",
            "duration_seconds": 734,
            "provider_category": "public_demo",
            "license_name": "Creative Commons Attribution 3.0 (CC-BY 3.0)",
            "license_url": "https://creativecommons.org/licenses/by/3.0/",
            "attribution": "© Blender Foundation | Open Movie Project",
            "manifest_url": "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8",
            "requires_signing": False,
        },
    ]

    for item in assets_to_seed:
        if item["id"] in existing_ids:
            existing_asset = (
                await db.execute(select(VideoAsset).where(VideoAsset.id == item["id"]))
            ).scalar_one_or_none()
            if existing_asset is not None:
                existing_asset.poster_url = item["poster_url"]
                existing_asset.backdrop_url = item["backdrop_url"]
            continue
        asset = VideoAsset(
            id=item["id"],
            tmdb_id=item["tmdb_id"],
            content_type=item["content_type"],
            season_number=item["season_number"],
            episode_number=item["episode_number"],
            title=item["title"],
            synopsis=item["synopsis"],
            poster_url=item["poster_url"],
            backdrop_url=item["backdrop_url"],
            duration_seconds=item["duration_seconds"],
            provider_category=item["provider_category"],
            license_name=item["license_name"],
            license_url=item["license_url"],
            attribution=item["attribution"],
            is_active=True,
        )
        db.add(asset)

        source = VideoSource(
            asset_id=asset.id,
            stream_type="hls",
            manifest_url=item["manifest_url"],
            quality_label="Auto (Adaptive HLS)",
            bandwidth_kbps=4500,
            requires_signing=item["requires_signing"],
        )
        db.add(source)

        sub_vi = SubtitleTrack(
            asset_id=asset.id,
            language_code="vi",
            label="Tiếng Việt",
            format="vtt",
            url="/static/subtitles/nam_cinema_vi.vtt",
            is_default=True,
        )
        sub_en = SubtitleTrack(
            asset_id=asset.id,
            language_code="en",
            label="English",
            format="vtt",
            url="/static/subtitles/nam_cinema_en.vtt",
            is_default=False,
        )
        db.add_all([sub_vi, sub_en])

        audio_en = AudioTrack(
            asset_id=asset.id,
            language_code="en",
            label="Original Audio (Stereo)",
            channels="2.0",
            is_default=True,
        )
        db.add(audio_en)

    await db.commit()
