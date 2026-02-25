# SolDoKu SwiftUI Migration Plan (iOS 16+)

Last updated: 2026-02-25

## 0) 고정 결정 사항

- [x] Minimum iOS version: **16.0+**
- [x] `README.md`/Xcode 설정의 최소 버전 표기를 iOS 16+로 통일
- [x] iOS 16+ 전제로 API 사용 기준 확정 (`PHPickerViewController`, modern permission handling, Swift Concurrency)

## 1) 목표

- [ ] UIKit + Storyboard 기반 앱을 SwiftUI 기반 앱으로 마이그레이션
- [ ] 도메인/인프라/피처 모듈 분리로 테스트 가능한 구조 확보
- [ ] 빌드 재현성, 릴리즈 게이트, 보안/품질 기준을 갖춘 상태로 전환

## 2) 비목표 (이번 마이그레이션 범위 밖)

- [ ] 백엔드/클라우드 아키텍처 신규 도입은 제외
- [ ] 대규모 기능 확장(신규 게임 모드, 계정 시스템) 제외
- [ ] 디자인 전면 개편 제외 (필요 최소 UX 개선만 수행)

## 3) 목표 아키텍처 (모듈)

- [ ] `App` (SwiftUI entry + DI composition root)
- [ ] `DesignSystem` (색상/타이포/공통 컴포넌트)
- [ ] `DomainSudoku` (solver, rule validation, entities)
- [ ] `DomainVision` (board detection / OCR protocol contracts)
- [ ] `InfraOpenCV` (ObjC++ bridge adapter)
- [ ] `InfraML` (CoreML adapter)
- [ ] `InfraPermissions` (camera/photo permission service)
- [ ] `FeatureHome` (SwiftUI)
- [ ] `FeatureManualSolve` (SwiftUI)
- [ ] `FeatureImageSolve` (SwiftUI)
- [ ] `FeatureCameraSolve` (SwiftUI)
- [ ] `TestSupport` (fixtures, mocks, stubs)

---

## P0) 안정화/게이트 복구 (선행 필수)

### P0-1. 빌드 재현성
- [x] OpenCV 의존성 전략 확정 (`xcframework` 권장, checksum 고정, [planning/OPENCV_XCFRAMEWORK_PLAN.md](OPENCV_XCFRAMEWORK_PLAN.md))
- [x] 현재 zip 기반 의존성(`Framework/opencv2.framework.zip`) 해소 또는 bootstrap 스크립트 제공
- [x] 현재 워크트리 기준 `xcodebuild build` 성공 (device/simulator)
- [x] Apple Silicon simulator 빌드 정책 명시 (`EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64`)

### P0-2. 런타임 안정성
- [x] 권한 플로우 수정: `.notDetermined/.limited/denied` 정상 처리
- [x] 카메라/앨범 접근 시 Settings 강제 유도 흐름 정리
- [x] `fatalError()`/force unwrap 우선 제거 (사용자 경로 중심)
- [x] solve/OCR 연산을 메인 스레드에서 분리

### P0-3. 테스트/CI 최소 게이트
- [x] `SudokuDomainTests` 타깃 생성 (Swift Package)
- [x] solver 최소 테스트 추가 (유효/무효 보드, 경계 케이스)
- [x] CI 추가: build + test (최소)
- [x] 머지 차단 조건 정의(게이트 실패 시 merge 금지, [planning/MERGE_GATE.md](MERGE_GATE.md))

### P0 완료 기준 (DoD)
- [x] iOS 16+ 환경에서 clean checkout 빌드 성공
- [x] 최소 단위 테스트 green
- [x] 주요 크래시 포인트 정리 완료
- [x] 권한 흐름 실기기 검증 체크리스트 작성 ([planning/P0_DEVICE_CHECKLIST.md](P0_DEVICE_CHECKLIST.md))
- [x] CI에서 build/test 자동 검증

---

## P1) 모듈화 기반 구축

### P1-1. 도메인 분리
- [x] `sudokuCalculation.swift`를 `DomainSudoku`로 이동
- [x] solver API를 순수 함수/타입 기반으로 정리 (`SudokuSolver`)
- [x] “완성된 무효 보드”를 reject하는 검증 로직 추가

### P1-2. 계약(Contract) 정리
- [ ] `wrapper.mm` 배열 인덱스 기반 반환값을 타입 DTO 계약으로 교체
- [x] `DomainVision` 프로토콜 정의 (`detectBoard`, `sliceCells`, `predictDigits`)
- [x] 에러 모델 표준화 착수 (`VisionContractError`, `SudokuPipelineError`)

### P1-3. 인프라 어댑터 분리
- [x] `SudokuInfrastructure` 파이프라인 스켈레톤 추가 (Vision contract -> Domain solver)
- [ ] OpenCV 접근 코드 -> `InfraOpenCV`
- [ ] CoreML 접근 코드 -> `InfraML`
- [ ] 권한 처리 코드 -> `InfraPermissions`

### P1-4. 테스트 확장
- [ ] Domain 단위 테스트 확장
- [x] Vision/ML contract 테스트(모의 구현) 추가
- [ ] 실패 시나리오(이미지 없음, 권한 거부, 인식 실패) 테스트 추가

### P1 완료 기준 (DoD)
- [ ] Feature 레이어가 OpenCV/CoreML 구현을 직접 참조하지 않음
- [ ] 도메인 테스트 커버리지 기준 충족(팀 합의 수치)
- [ ] 핵심 에러 코드가 일관된 경로로 전파됨

---

## P2) SwiftUI 앱 셸 전환

### P2-1. 진입점 전환
- [ ] Storyboard 기반 진입점 제거/축소
- [ ] SwiftUI `@main App` 구성
- [ ] Composition Root에서 의존성 주입 연결

### P2-2. 홈 화면 전환
- [ ] Home 화면을 SwiftUI로 구현
- [ ] 기존 3개 플로우 라우팅을 SwiftUI Navigation으로 연결
- [ ] 필요 시 임시 `UIViewControllerRepresentable` 브리지 사용

### P2-3. 공통 UI 체계
- [ ] `DesignSystem`에 컬러/타이포/버튼/알럿 컴포넌트 정리
- [ ] 로컬라이제이션 키 사용 일관화

### P2 완료 기준 (DoD)
- [ ] 앱 루트 네비게이션이 SwiftUI에서 동작
- [ ] 기존 기능 진입 동작 유지
- [ ] Storyboard 의존성이 루트에서는 제거됨

---

## P3) 기능별 SwiftUI 마이그레이션

### P3-1. Manual Solve (우선)
- [ ] 입력 그리드/키패드 UI를 SwiftUI로 구현
- [ ] 충돌 강조, 삭제/초기화, solve UX 동일 기능 이관
- [ ] 기존 UIKit 화면 제거

### P3-2. Image Solve (2순위)
- [ ] 이미지 선택/권한/인식/해결/오버레이 흐름 이관
- [ ] 실패 케이스 UX 표준화
- [ ] UIKit 의존 코드 제거

### P3-3. Camera Solve (3순위)
- [ ] 카메라 프리뷰 + 프레임 처리 파이프라인 이관
- [ ] 백그라운드 처리/취소/스로틀링 반영
- [ ] 기기별 성능 검증

### P3 완료 기준 (DoD)
- [ ] 3개 플로우가 SwiftUI 기반으로 동작
- [ ] UIKit ViewController 기반 핵심 화면 제거 완료
- [ ] 기능 회귀 테스트 green

---

## P4) 하드닝/릴리즈 준비

### P4-1. 품질/성능
- [ ] 성능 예산 수립 및 측정 (`solve latency p95`, UI blocking, memory growth)
- [ ] 회귀 fixture 세트 확정 (이미지 -> 기대 결과)
- [ ] 크래시 프리 세션 목표치 설정

### P4-2. 보안/컴플라이언스
- [ ] 모델 provenance/license 문서화
- [ ] 의존성 checksum/provenance 문서화
- [ ] 데이터 처리 정책 문서화(온디바이스 처리, 보관/전송 정책)
- [ ] 보안 게이트(SAST/secret/dependency audit) CI 연동

### P4-3. 릴리즈 운영
- [ ] CHANGELOG/릴리즈 노트 프로세스 도입
- [ ] TestFlight 롤아웃/롤백 절차 문서화
- [ ] 최종 체크리스트(빌드/테스트/보안/문서) 통합

### P4 완료 기준 (DoD)
- [ ] 릴리즈 게이트 전체 green
- [ ] 운영 문서(배포/롤백/인시던트) 준비 완료
- [ ] SwiftUI 마이그레이션 완료 선언 가능

---

## 트랙킹 템플릿 (주간)

- [ ] 이번 주 목표 달성 여부
- [ ] 블로커/의사결정 필요 항목 업데이트
- [ ] 리스크 변화 업데이트
- [ ] 다음 주 계획 확정

## 즉시 실행 항목 (이번 스프린트 권장)

- [x] P0-1 OpenCV 전략 확정
- [x] P0-2 권한/크래시 핫스팟 수정 시작
- [x] P0-3 테스트 타깃 + CI 최소 게이트 생성
- [x] P1 도메인/인프라 모듈 분리 착수 (package target 분리 + 파이프라인/테스트 초안)
