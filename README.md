# focustella-ios

## 디렉토리 구조

```text
focustella-ios/
├─ App/
│  ├─ DI/
│  └─ Routing/
├─ Core/
│  ├─ Constants/
│  ├─ Extensions/
│  ├─ Utilities/
│  └─ DesignSystem/
│     ├─ Colors/
│     ├─ Typography/
│     └─ Components/
├─ Network/
│  ├─ APIClient/
│  ├─ Endpoint/
│  ├─ DTO/
│  └─ Interceptor/
├─ Data/
│  ├─ Remote/
│  ├─ Local/
│  ├─ Persistence/
│  └─ Mapper/
├─ Domain/
│  ├─ Entities/
│  ├─ UseCases/
│  └─ RepositoryInterfaces/
├─ Features/
│  ├─ MySky/
│  │  ├─ Views/
│  │  ├─ ViewModels/
│  │  ├─ Components/
│  │  └─ Models/
│  ├─ Session/
│  │  ├─ Views/
│  │  ├─ ViewModels/
│  │  ├─ Components/
│  │  └─ Models/
│  ├─ Friends/
│  │  ├─ Views/
│  │  ├─ ViewModels/
│  │  ├─ Components/
│  │  └─ Models/
│  ├─ MyPage/
│  │  ├─ Views/
│  │  ├─ ViewModels/
│  │  ├─ Components/
│  │  └─ Models/
│  └─ Dev/
│     ├─ Views/
│     ├─ ViewModels/
│     ├─ Components/
│     └─ Models/
├─ Shared/
│  ├─ Components/
│  ├─ Modifiers/
│  └─ Protocols/
├─ System/
├─ Models/
├─ UI/
├─ Resources/
│  ├─ Fonts/
│  ├─ Lottie/
│  └─ Mock/
└─ Preview/
   ├─ Fixtures/
   └─ Mocks/
```

## 폴더 역할

### `App`
- 앱 진입/조립(Composition) 계층입니다.
- `DI`: 의존성 그래프 등록(`Live`, `Mock`, `Preview`)
- `Routing`: 탭/네비게이션 라우팅 및 화면 전환 상태

### `Core`
- 특정 기능에 종속되지 않는 공통 기반 계층입니다.
- 상수, 유틸리티, 확장, 디자인 토큰/컴포넌트를 관리합니다.

### `Network`
- 네트워크 전송(Transport) 전용 계층입니다.
- `APIClient`: 요청 실행, 재시도, 디코딩
- `Endpoint`: 타입 기반 요청 명세(path, method, query, body)
- `DTO`: 요청/응답 DTO(네트워크 스키마)
- `Interceptor`: 인증 헤더, 로깅, 토큰 갱신, 트레이싱

### `Data`
- Repository 실제 구현 계층입니다.
- `Remote`: API 기반 데이터 소스
- `Local`/`Persistence`: 캐시, 로컬 DB, 디스크 저장소
- `Mapper`: DTO <-> Domain 모델 변환

### `Domain`
- UI/프레임워크와 분리된 비즈니스 규칙 계층입니다.
- `Entities`: 유스케이스에서 사용하는 도메인 모델
- `UseCases`: 앱 동작 단위(세션 시작, 별자리 조회, 메모 저장 등)
- `RepositoryInterfaces`: 유스케이스가 의존하는 프로토콜

### `Features`
- 기능 단위(Vertical Slice) 구성입니다.
- 각 기능은 `Views`, `ViewModels`, 기능 전용 `Components`, 기능 전용 `Models`를 가집니다.

### `Shared`
- 여러 기능에서 재사용되는 UI/Modifier/프로토콜을 둡니다.
- 디자인 시스템의 원자 단위 컴포넌트는 `Core/DesignSystem`에 둡니다.

### `System`
- 플랫폼 어댑터 계층입니다(햅틱, 접근성 감지, 앱 생명주기 헬퍼 등).

### `Models` 와 `UI` (현재 전환 중 폴더)
- 기존 앱 모델과 공용 UI 컴포넌트가 일부 남아 있습니다.
- 리팩터링 시 `Domain/Entities` + `Features/*` + `Shared`로 점진 이동합니다.

### `Resources` / `Preview`
- 정적 리소스와 프리뷰 전용 fixture/mock을 관리합니다.

## 권장 API 연결 구조
아래 의존 방향을 권장합니다.

`View -> ViewModel -> UseCase -> RepositoryInterface -> Data.Repository -> RemoteDataSource -> APIClient`

가이드라인:
- `ViewModel`에서 `APIClient`를 직접 호출하지 않습니다.
- API 스키마는 `Network/DTO`에서 관리합니다.
- DTO -> 도메인 모델 변환은 `Data/Mapper`에서 처리합니다.
- 실제 구현체 바인딩은 `App/DI`에서 주입합니다.

## 빈 디렉토리 정책
- 빈 폴더는 `.gitkeep`으로 Git에 유지합니다.
