---
title: Nam Cinema 4K
emoji: 🎬
colorFrom: red
colorTo: gray
sdk: docker
app_port: 7860
pinned: true
---

# 🎬 Nam Cinema 4K — Your Cinema. Anywhere.

Hệ thống rạp phim cá nhân 4K HDR đa nền tảng (iPhone, Android, MacBook, Windows, Smart TV) tích hợp trình phát Netflix 4K và phụ đề Tiếng Việt tự động.

## 🚀 Cách triển khai miễn phí 24/7 trên Hugging Face Spaces (2 vCPU + 16GB RAM)

1. Truy cập **https://huggingface.co/spaces** (đăng ký tài khoản miễn phí nếu chưa có).
2. Bấm **New Space**:
   - **Space name**: `nam-cinema`
   - **Select the Space SDK**: Chọn **Docker** → chọn **Blank**.
   - **Visibility**: Chọn **Public** — bấm **Create Space**.
3. Chọn **Files** → **Add file** → **Upload files**, kéo toàn bộ file và thư mục trong thư mục `backend` này (`app/`, `static/`, `Dockerfile`, `pyproject.toml`, `requirements.txt`, `README.md`) thả vào và bấm **Commit changes to main**.
4. Chờ khoảng 2 phút để hệ thống tự động Build. Khi hiện chữ **Running**, mở đường link:
   - `https://<ten-tai-khoan-cua-ban>-nam-cinema.hf.space`
   - Hoặc bấm biểu tượng `⋮` góc phải trên → **Embed this Space** → copy **Direct URL** để mở trực tiếp trên iPhone, Android, MacBook, Windows mà không cần cài đặt!
