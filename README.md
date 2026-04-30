# 보드미 (Bodeumi) - 가족 사진/동영상 공유 앱

가족 구성원들이 아기 사진과 동영상을 쉽게 공유할 수 있는 프라이빗 앨범 앱입니다.

---

## 주요 기능

### 사진/동영상
- 카메라 촬영 또는 갤러리에서 사진+동영상 동시 선택 업로드
- 실시간 업로드 진행률 표시 (파일별 퍼센트)
- 자동 이미지 리사이즈/압축 (긴 변 2048px, JPEG 85%)
- 동영상 원본 유지, 첫 프레임 썸네일 자동 생성
- 최대 500MB 파일 업로드 지원
- HEIC/HEIF 포맷 지원

### 갤러리
- 월별 갤러리 뷰 (5개월 탭 네비게이션)
- 3열 그리드: 동영상 2x2 크기, 사진 1x1 크기로 혼재 배치
- 동영상 위치 좌우 교대 배치, 빈 공간 자동 채움
- 스와이프로 월 이동 (좌=최신, 우=과거)
- 파스텔 라벤더→핑크 그라데이션 배경

### 최신 피드
- 업로더별 그룹 카드 형태 (소셜 피드 스타일)
- "엄마님이 3장을 공유했습니다" + 상대 시간 표시
- 이니셜 아바타 + 별명 + 장수 + 시간

### 뷰어
- 사진: 풀스크린 뷰어 (확대/축소, 스와이프)
- 동영상: Chewie 플레이어 (재생 컨트롤)
- 액션 버튼: 공개설정 → 삭제 → 즐겨찾기 → 다운로드 → 정보

### 일괄 작업 (멀티 셀렉트)
- 사진 길게 눌러 선택 모드 진입
- 전체 선택 / 개별 토글
- 일괄 공개설정, 삭제, 즐겨찾기, 다운로드

### 사용자/권한
- 아이디 + 별명 + 비밀번호 회원가입
- JWT 인증 (30일 자동 유지)
- 첫 가입자 자동 Admin
- Admin이 멤버별 권한 관리:
  - 업로드 / 삭제 / 다운로드 / 공개설정
- 사용자별 독립 즐겨찾기
- 사진별 공개 범위 설정 (전체 공개 / 특정 사용자)

---

## 기술 스택

### 백엔드
| 항목 | 기술 |
|------|------|
| 프레임워크 | FastAPI (Python 3.11) |
| 서버 | Uvicorn (ASGI) |
| DB | SQLite + SQLModel ORM |
| 인증 | JWT (PyJWT) |
| 이미지 처리 | Pillow |
| 동영상 썸네일 | ffmpeg |
| 파일 저장 | Google Cloud Storage |
| 컨테이너 | Docker |

### 프론트엔드 (Android)
| 항목 | 기술 |
|------|------|
| 프레임워크 | Flutter (Dart) |
| HTTP | http + Dio (업로드 진행률) |
| 이미지 캐시 | cached_network_image |
| 사진 뷰어 | photo_view |
| 동영상 플레이어 | video_player + chewie |
| 다운로드 | image_gallery_saver_plus |
| 상태 저장 | shared_preferences |

### 인프라
| 항목 | 내용 |
|------|------|
| 클라우드 | Google Cloud Platform |
| VM | Compute Engine (e2-small, 서울 리전) |
| 스토리지 | Google Cloud Storage (`gs://bodme-photo`) |
| 시간대 | Asia/Seoul (KST) |

---

## 프로젝트 구조

```
Sharing_Album/
├── app/                          # 백엔드 (FastAPI)
│   ├── main.py                   # 앱 진입점, CORS, 라우터 등록
│   ├── config.py                 # 설정 (DB, GCS, 업로드 제한)
│   ├── database.py               # DB 엔진 + 자동 마이그레이션
│   ├── models.py                 # DB 모델 (User, Photo, UserFavorite)
│   ├── schemas.py                # API 요청/응답 스키마
│   ├── auth.py                   # JWT, 비밀번호 해싱, 권한 체크
│   ├── routers/
│   │   ├── auth.py               # 인증/멤버 관리 API
│   │   └── photos.py             # 사진/동영상 CRUD API
│   └── utils/
│       ├── exif.py               # EXIF 날짜 추출
│       ├── image.py              # 이미지 리사이즈/압축/썸네일
│       ├── video.py              # 동영상 썸네일 (ffmpeg)
│       └── storage.py            # GCS/로컬 스토리지 추상화
├── bodeumi_app/                  # 프론트엔드 (Flutter)
│   ├── lib/
│   │   ├── main.dart             # 앱 진입점 (스플래시 → 로그인/홈)
│   │   ├── config.dart           # 서버 URL 설정
│   │   ├── models/
│   │   │   └── photo.dart        # Photo 모델
│   │   ├── services/
│   │   │   ├── api_service.dart  # API 호출 (Dio 업로드)
│   │   │   └── auth_service.dart # 인증 상태 관리
│   │   ├── screens/
│   │   │   ├── login_screen.dart       # 로그인/회원가입
│   │   │   ├── home_screen.dart        # 메인 (탭 + 업로드 + 메뉴)
│   │   │   ├── gallery_tab.dart        # 월별 갤러리
│   │   │   ├── recent_tab.dart         # 최신 피드
│   │   │   ├── favorites_tab.dart      # 즐겨찾기
│   │   │   ├── photo_view_screen.dart  # 사진 뷰어
│   │   │   ├── video_player_screen.dart# 동영상 플레이어
│   │   │   └── members_screen.dart     # 멤버 관리
│   │   ├── widgets/
│   │   │   └── photo_grid.dart         # 그리드 (멀티셀렉트)
│   │   └── utils/
│   │       ├── media_helper.dart       # 사진/동영상 뷰어 분기
│   │       ├── batch_actions.dart      # 일괄 작업 처리
│   │       └── visibility_dialog.dart  # 공개 범위 다이얼로그
│   └── assets/
│       └── icon.png              # 앱 아이콘
├── Dockerfile
├── requirements.txt
└── deploy/
    └── gce-setup.sh
```

---

## API 엔드포인트

### 인증
| 메서드 | 경로 | 설명 | 인증 |
|--------|------|------|------|
| POST | `/auth/register` | 회원가입 (첫 가입자 = admin) | - |
| POST | `/auth/login` | 로그인 → JWT 반환 | - |
| GET | `/auth/me` | 내 정보 | 필요 |
| GET | `/auth/users` | 멤버 목록 | 필요 |
| PUT | `/auth/users/{id}/permissions` | 권한 변경 | admin |

### 사진/동영상
| 메서드 | 경로 | 설명 | 인증 |
|--------|------|------|------|
| POST | `/photos/upload` | 업로드 | 필요 |
| GET | `/photos/months` | 월 목록 | - |
| GET | `/photos/?month=YYYY-MM` | 월별 조회 | 필요 |
| GET | `/photos/recent?limit=50` | 최신 목록 | 필요 |
| GET | `/photos/favorites` | 내 즐겨찾기 | 필요 |
| GET | `/photos/{id}` | 메타데이터 | 필요 |
| GET | `/photos/{id}/file?type=original` | 원본 파일 | - |
| GET | `/photos/{id}/file?type=thumbnail` | 썸네일 | - |
| PUT | `/photos/{id}/favorite` | 즐겨찾기 토글 | 필요 |
| PUT | `/photos/{id}/visibility` | 공개 범위 변경 | 필요 |
| DELETE | `/photos/{id}` | 삭제 | 필요 |

---

## 데이터베이스 모델

### User
| 필드 | 타입 | 설명 |
|------|------|------|
| id | UUID | 고유 ID |
| name | string (unique) | 로그인 아이디 |
| nickname | string | 앱 표시 별명 |
| password_hash | string | SHA256 + salt |
| role | string | `admin` / `member` |
| can_upload | bool | 업로드 권한 |
| can_delete | bool | 삭제 권한 |
| can_download | bool | 다운로드 권한 |
| can_set_visibility | bool | 공개설정 권한 |
| created_at | datetime | 가입일 (KST) |

### Photo
| 필드 | 타입 | 설명 |
|------|------|------|
| id | UUID | 고유 ID |
| filename | string | 저장 파일명 |
| original_filename | string | 원본 파일명 |
| file_path | string | GCS 키 / 로컬 경로 |
| thumbnail_path | string | 썸네일 로컬 경로 |
| file_hash | string | MD5 (중복 방지) |
| file_size | int | 바이트 |
| media_type | string | `photo` / `video` |
| taken_at | datetime? | EXIF 촬영일 |
| uploaded_at | datetime | 업로드 시간 (KST) |
| month_folder | string | `2026-04` |
| uploader_name | string | 업로더 별명 |
| uploader_id | string? | 업로더 ID |
| visible_to | string? | null=전체, CSV=특정 사용자 |

### UserFavorite
| 필드 | 타입 | 설명 |
|------|------|------|
| id | UUID | 고유 ID |
| user_id | string | 사용자 ID |
| photo_id | string | 사진 ID |

---

## 권한 체계

```
Admin (관리자) - 첫 번째 가입자
├── 모든 기능 사용 가능
├── 멤버 권한 관리 (업로드/삭제/다운로드/공개설정)
└── 모든 사진 삭제/공개설정 가능

Member (멤버) - 이후 가입자
├── can_upload     → 사진/동영상 업로드
├── can_delete     → 본인 사진 삭제
├── can_download   → 원본 다운로드
└── can_set_visibility → 본인 사진 공개 범위 설정
```

---

## 배포 가이드

### 서버 (GCP VM + Docker)

```bash
# 1. VM에 접속
gcloud compute ssh bodme --zone=asia-northeast3-c

# 2. 프로젝트 클론
git clone https://github.com/jya1park/Sharing_Album.git
cd Sharing_Album
git checkout claude/photo-sharing-app-AeoVf
mkdir -p data

# 3. Docker 빌드 + 실행
sudo docker build -t bodeumi .
sudo docker run -d --name bodeumi -p 8000:8000 \
  -v $(pwd)/data:/data \
  -e GCS_BUCKET=bodme-photo \
  --restart always bodeumi

# 4. 확인
sudo docker ps
curl http://localhost:8000/health
```

### 앱 빌드 (PC)

```bash
cd Sharing_Album/bodeumi_app
flutter clean
flutter pub get
flutter build apk --release
```

APK 위치: `build/app/outputs/flutter-apk/bodme.apk`

### 서버 업데이트

```bash
cd ~/Sharing_Album
git pull origin claude/photo-sharing-app-AeoVf
sudo docker stop bodeumi && sudo docker rm bodeumi
sudo docker build -t bodeumi .
sudo docker run -d --name bodeumi -p 8000:8000 \
  -v $(pwd)/data:/data \
  -e GCS_BUCKET=bodme-photo \
  --restart always bodeumi
```

### 백업

```bash
# 수동 백업
~/backup.sh

# 자동 백업 (매일 새벽 3시)
crontab -l  # 확인
```

---

## 저장 구조

```
VM (로컬)                    GCS (gs://bodme-photo)
├── data/                    ├── 2026-04/
│   ├── bodeumi.db           │   └── original/
│   └── photos/              │       ├── xxx.jpg
│       └── 2026-04/         │       └── xxx.mp4
│           └── thumbnails/  └── 2026-05/
│               ├── xxx.jpg      └── original/
│               └── xxx.jpg          └── ...
```

| 파일 | 저장 위치 | 설명 |
|------|----------|------|
| 원본 사진/동영상 | GCS | $0.02/GB/월 |
| 썸네일 | VM 로컬 | 빠른 로딩 |
| DB | VM 로컬 | 메타데이터, 사용자 정보 |

---

## 예상 비용

| 항목 | 월 비용 |
|------|---------|
| VM (e2-small) | ~$15 |
| GCS 저장소 | $0.02/GB |
| 디스크 (30GB) | ~$1.2 |
| **합계** | **~$17~20** |
