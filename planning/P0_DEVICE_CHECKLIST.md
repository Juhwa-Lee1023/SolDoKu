# P0 Device Validation Checklist (iOS 16+)

Last updated: 2026-02-25

## 1. 목적

- P0 안정화 항목 중 실기기 검증이 필요한 권한/카메라/이미지 solve 플로우를 재현 가능한 체크리스트로 고정한다.
- PR 머지 전/릴리즈 전 동일 절차로 회귀 확인이 가능하도록 한다.

## 2. 범위

- 대상 OS: iOS 16.x, iOS 17.x, iOS 18.x
- 대상 디바이스: 최소 2종 (Notch 기기 + Home Button 계열 1종 권장)
- 대상 기능:
  - Camera Solve
  - Gallery/Image Solve
  - Manual Import Solve
  - 권한 거부/재허용 Settings 전환

## 3. 사전 조건

- [ ] `main` 최신 기준 클린 빌드 완료
- [ ] OpenCV bootstrap 수행 (`./scripts/bootstrap_opencv.sh`)
- [ ] 테스트 수행
  - [ ] `swift test`
  - [ ] `xcodebuild -project Sudoku.xcodeproj -scheme Sudoku -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
  - [ ] `xcodebuild -project Sudoku.xcodeproj -scheme Sudoku -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`

## 4. 권한 플로우

### 4.1 Camera Permission
- [ ] 최초 실행에서 카메라 권한 요청 노출
- [ ] `Don't Allow` 선택 시 Settings 유도 alert 노출
- [ ] Settings 이동 후 권한 허용 시 카메라 화면 정상 복귀

### 4.2 Photo Permission
- [ ] 최초 실행에서 사진 권한 요청 노출
- [ ] `Selected Photos`(limited) 상태에서 이미지 선택 가능
- [ ] 거부 상태에서 Settings 유도 alert 동작

## 5. 기능 플로우

### 5.1 Camera Solve
- [ ] 보드 인식 전/후 버튼 상태가 일관적임 (`solve` 중 재진입 불가)
- [ ] 인식 실패 시 indicator가 종료되고 UI가 복구됨
- [ ] 숫자 17개 미만 경고 alert 이후 `Yes/No` 동작 정상
- [ ] solve 성공 시 오버레이 숫자 렌더링 정상

### 5.2 Picker Solve
- [ ] 이미지 선택 후 solve 실행 가능
- [ ] solve 중 중복 탭 시 병렬 solve가 발생하지 않음
- [ ] 실패/취소 경로에서 버튼 상태가 정상 복구됨

### 5.3 Import Solve
- [ ] 수동 입력 후 solve 동작
- [ ] solve 중 입력 UI interaction 잠금/복구 동작 확인
- [ ] 불가능한 퍼즐에서 경고 alert/indicator 종료 정상

## 6. 앱 생명주기/안정성

- [ ] Camera Solve 중 백그라운드 진입 후 복귀 시 크래시 없음
- [ ] 권한 alert/Settings 이동 후 복귀 시 화면 상태 정상
- [ ] 메모리 경고/회전(지원 방향 내)에서 크래시 없음

## 7. 결과 기록 템플릿

| Date | Device | iOS | Build SHA | Tester | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD | iPhone XX | 16.x | `<commit>` | `<name>` | PASS/FAIL | `재현 절차/로그` |

## 8. 완료 기준

- 위 체크 항목 PASS 100%
- FAIL 항목은 이슈 번호/재현 절차/로그 첨부 후 P0 완료 판정 보류
