# focustella-ios

## 디렉토리 구조 (현재 기준)

```text
focustella-ios/
├─ App/
│  ├─ FocustellaApp.swift
│  ├─ MainTabView.swift
│  ├─ RootView.swift
│  ├─ DI/
│  └─ Routing/
├─ Core/
│  ├─ Constants/
│  ├─ Contracts/
│  ├─ Extensions/
│  ├─ Utilities/
│  └─ DesignSystem/
│     ├─ Colors/
│     ├─ Components/
│     └─ Typography/
├─ Network/
│  ├─ APIClient/
│  ├─ DTO/
│  │  ├─ Auth/
│  │  ├─ Common/
│  │  ├─ Focus/
│  │  ├─ Friend/
│  │  ├─ Sky/
│  │  └─ User/
│  ├─ Endpoint/
│  └─ Interceptor/
├─ Data/
│  ├─ Local/
│  ├─ Mapper/
│  ├─ Persistence/
│  ├─ Remote/
│  └─ Repositories/
├─ Domain/
│  ├─ Entities/
│  ├─ RepositoryInterfaces/
│  └─ UseCases/
├─ Features/
│  ├─ Auth/
│  │  ├─ Views/
│  │  └─ ViewModels/
│  ├─ Dev/
│  │  ├─ Components/
│  │  ├─ Models/
│  │  ├─ Support/
│  │  ├─ ViewModels/
│  │  └─ Views/
│  ├─ Friends/
│  │  ├─ Components/
│  │  ├─ Models/
│  │  ├─ ViewModels/
│  │  └─ Views/
│  ├─ MyPage/
│  │  ├─ Components/
│  │  ├─ Models/
│  │  ├─ ViewModels/
│  │  └─ Views/
│  ├─ MySky/
│  │  ├─ Views/
│  │  ├─ ViewModels/
│  │  ├─ Components/
│  │  │  ├─ Background/
│  │  │  ├─ Dev/
│  │  │  ├─ Effects/
│  │  │  ├─ Overlays/
│  │  │  ├─ Rendering/
│  │  │  └─ Sheets/
│  │  └─ Models/
│  │     ├─ Camera/
│  │     ├─ Daily/
│  │     ├─ Dev/
│  │     ├─ Scene/
│  │     └─ Session/
│  └─ Session/
│     ├─ Components/
│     ├─ Dependencies/
│     ├─ Models/
│     │  └─ Runtime/
│     ├─ ViewModels/
│     └─ Views/
├─ Shared/
│  ├─ Components/
│  ├─ Modifiers/
│  └─ Protocols/
├─ System/
├─ Resources/
│  ├─ Fonts/
│  ├─ Lottie/
│  └─ Mock/
├─ Preview/
│  ├─ Fixtures/
│  └─ Mocks/
├─ Assets.xcassets/
├─ Info.plist
└─ Secrets.xcconfig
```

## 디렉터리 설명

### 루트 레벨
- `App`: 앱 시작점과 루트 화면 조립 계층.
- `Core`: 기능 비종속 공통 코드(계약/유틸/확장/디자인 시스템).
- `Network`: HTTP 전송, Endpoint, DTO, 인터셉터 계층.
- `Data`: 저장소/원격/로컬/매핑 등 데이터 구현 계층.
- `Domain`: 엔티티/유스케이스/저장소 인터페이스 등 비즈니스 규칙 계층.
- `Features`: 기능 단위(Vertical Slice) UI/상태/연출 구현 계층.
- `Shared`: 여러 기능에서 공통으로 쓰는 컴포넌트/Modifier/프로토콜.
- `System`: 접근성, 햅틱 등 플랫폼 어댑터 계층.
- `Resources`: 폰트, 로티, 목 데이터 등 정적 리소스.
- `Preview`: SwiftUI 프리뷰 전용 fixture/mock 리소스.
- `Assets.xcassets`: 앱 아이콘, 색상 등 에셋 카탈로그.
- `Info.plist`: 앱 번들 설정.
- `Secrets.xcconfig`: 환경별 비밀/설정 값.

### `App`
- `App/DI`: 의존성 조립(컨테이너/팩토리)용 폴더.
- `App/Routing`: 앱 전역 라우팅/네비게이션 상태 관리용 폴더.
- `App/FocustellaApp.swift`: `@main` 진입점.
- `App/RootView.swift`: 로그인 상태 기준 루트 분기.
- `App/MainTabView.swift`: 탭 구성 및 주요 Feature 주입 지점.

### `Core`
- `Core/Constants`: 전역 상수 정의.
- `Core/Contracts`: 기능 경계를 넘나드는 프로토콜 계약(예: 런타임 저장소 계약).
- `Core/Extensions`: Foundation/SwiftUI 타입 확장 및 공용 Notification 이름.
- `Core/Utilities`: 로깅/헬퍼 유틸리티.
- `Core/DesignSystem/Colors`: 색상 토큰.
- `Core/DesignSystem/Components`: 공용 UI 원자 컴포넌트.
- `Core/DesignSystem/Typography`: 폰트/타이포그래피 토큰.

### `Network`
- `Network/APIClient`: 공통 요청 실행기, 에러 처리.
- `Network/DTO/*`: API 요청/응답 스키마 타입.
- `Network/Endpoint`: API 엔드포인트 명세.
- `Network/Interceptor`: 인증/세션/로깅 인터셉터.

### `Data`
- `Data/Remote`: 원격 데이터소스 구현.
- `Data/Local`: 로컬 데이터/캐시/배치 관련 구현.
- `Data/Persistence`: 영속성 관련 구현 확장 포인트.
- `Data/Mapper`: DTO <-> Domain 매핑.
- `Data/Repositories`: Domain 저장소 인터페이스 구현체.

### `Domain`
- `Domain/Entities`: UI와 분리된 도메인 모델.
- `Domain/UseCases`: 기능 단위 비즈니스 로직.
- `Domain/RepositoryInterfaces`: UseCase가 의존하는 프로토콜.

### `Features` 공통
- `Views`: 화면 뷰 계층.
- `ViewModels`: 화면 상태/액션 처리.
- `Components`: 기능 전용 재사용 UI 조각.
- `Models`: 기능 전용 모델/상태/컨트롤러.

### `Features/Auth`
- 로그인 및 인증 진입 화면과 상태 관리.

### `Features/Dev`
- 개발자용 디버그 UI/도구.
- `Support`: 배치 fixture, 테스트용 유틸.

### `Features/Friends`
- 친구 목록/검색/요청 관련 기능.

### `Features/MyPage`
- 사용자 프로필/설정 관련 기능.

### `Features/MySky`
- 하늘 렌더링, 카메라, 별자리 상호작용, 세션 연출 핵심 기능.
- `Components/Background`: 배경 하늘 렌더링.
- `Components/Rendering`: Canvas 기반 별/별자리 렌더러.
- `Components/Effects`: 생성/완료/보상 이펙트.
- `Components/Overlays`: 세션/튜토리얼/보호 모드 오버레이.
- `Components/Sheets`: 슬롯 선택, 메모 입력 시트.
- `Components/Dev`: MySky 내 개발자 삽입 도구 UI.
- `Models/Camera`: 좌표 변환 및 카메라 상태/제어.
- `Models/Scene`: 하늘 상태, 기하/충돌, 상태 병합.
- `Models/Session`: 집중 세션 프레젠테이션 상태머신/디렉터.
- `Models/Daily`: 일일 보상 별 상태 저장소.
- `Models/Dev`: 입력 보호/탭 판정/개발자 삽입 코디네이터.

### `Features/Session`
- 일일 세션(체크리스트) 흐름과 집중 세션 런타임 저장소.
- `Dependencies`: Session 기능 조립용 의존성 팩토리.
- `Models/Runtime`: 집중 세션 런타임 상태 저장소 구현.
- `Components`: 세션 전용 UI 컴포넌트.
- `Views`/`ViewModels`: 세션 화면과 상태 관리.

### `Shared`
- `Shared/Components`: 범기능 공용 컴포넌트.
- `Shared/Modifiers`: 공용 ViewModifier.
- `Shared/Protocols`: 공용 프로토콜.

### `System`
- 접근성 상태, 햅틱 등 디바이스/OS 연동 코드.

## 의존 방향 가이드

`View -> ViewModel -> UseCase -> RepositoryInterface -> Data.Repository -> DataSource -> APIClient`

- `ViewModel`은 `APIClient`를 직접 호출하지 않습니다.
- DTO 스키마는 `Network/DTO`에서 관리합니다.
- DTO -> 도메인 변환은 `Data/Mapper`에서 처리합니다.
- 기능 간 공유 계약은 `Core/Contracts`에 둡니다.

## 신규 화면/기능 추가 가이드

1. 파일 배치 규칙을 먼저 정합니다.
- 화면은 `Features/<Feature>/Views`
- 상태/액션은 `Features/<Feature>/ViewModels`
- 기능 전용 UI 조각은 `Features/<Feature>/Components`
- 기능 내부 상태머신/컨트롤러는 `Features/<Feature>/Models`

2. 의존 방향을 지킵니다.
- `ViewModel`이 `APIClient`나 `Data` 구현체를 직접 호출하지 않습니다.
- 비즈니스 로직은 `Domain/UseCases`로 분리합니다.
- 저장소 프로토콜은 `Domain/RepositoryInterfaces`, 구현은 `Data/Repositories`에 둡니다.

3. 조립(Composition)은 상위에서만 합니다.
- 생성자 주입을 기본으로 사용합니다.
- 실제 구현체 결선은 `App/MainTabView.swift` 또는 `App/DI`에서 수행합니다.
- Feature 내부 기본값으로 외부 구현체를 직접 만들지 않습니다.

4. 기능 간 결합은 계약/이벤트로만 연결합니다.
- 직접 타입 참조 대신 `Core/Contracts` 프로토콜을 우선 사용합니다.
- Notification 이벤트 이름은 문자열 리터럴 금지, `Core/Extensions/NotificationName+*.swift`에 선언합니다.

5. MySky 관련 변경 시 좌표/렌더 규칙을 유지합니다.
- 좌표는 `sky space`를 단일 기준으로 사용합니다.
- 좌표 변환은 `MySkyCoordinateMapper`만 사용합니다.
- 카메라 상태는 `centerSky + zoom`을 단일 진실값으로 유지합니다.
- 정적 별/별자리는 Canvas, 진행 중 세션은 Live 레이어를 유지합니다.

6. 테스트를 함께 추가합니다.
- 신규 로직은 최소 1개 단위 테스트를 추가합니다.
- 좌표/카메라/프레젠테이션 전이는 회귀가 잦으므로 우선 테스트 대상입니다.

## 빈 디렉터리 정책
- 빈 폴더는 `.gitkeep`으로 유지합니다.
