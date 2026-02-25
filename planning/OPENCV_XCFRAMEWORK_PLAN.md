# OpenCV XCFramework Migration Design (P0 Closure)

Last updated: 2026-02-25

## 1. 배경

- 현재는 `Framework/opencv2.framework.zip` + `scripts/bootstrap_opencv.sh` 조합으로 의존성을 복원한다.
- 이 방식은 로컬 환경에 따라 복원 실패 여지가 있고, 아티팩트 provenance/checksum 관리가 약하다.
- P0 목표는 "빌드 재현성" 확보이므로, OpenCV 의존성을 `xcframework` 기반으로 고정하고 checksum 검증 가능한 형태로 전환한다.

## 2. 목표

- iOS Device/Simulator를 단일 `opencv2.xcframework`로 제공
- 버전/체크섬이 명시된 아티팩트 배포
- 앱 타깃이 직접 zip을 풀지 않고 패키지 의존성으로 소비

## 3. 비목표

- OpenCV 알고리즘 자체 변경
- wrapper API 의미 변경 (P1 단계 계약 정리는 별도)

## 4. 타깃 구조

## 4.1 Artifact
- `Dependencies/OpenCV/opencv2.xcframework.zip`
- 포함 슬라이스:
  - `ios-arm64`
  - `ios-arm64_x86_64-simulator`

## 4.2 배포 방식
- 로컬 패키지(`Dependencies/OpenCVBinary/Package.swift`)에서 `binaryTarget` 선언
- checksum 고정:
  - `swift package compute-checksum Dependencies/OpenCV/opencv2.xcframework.zip`
- Xcode 프로젝트는 local package product를 링크

## 5. 구현 단계

### Phase A: 아티팩트 생성
- [ ] OpenCV 버전 pin (`4.x.y`) 확정
- [ ] iOS + iOS Simulator 빌드 스크립트 작성
- [ ] `xcodebuild -create-xcframework`로 `opencv2.xcframework` 생성
- [ ] zip 압축 + checksum 생성

### Phase B: 프로젝트 연결
- [ ] `OpenCVBinary` 패키지 추가
- [ ] 기존 `Framework/opencv2.framework.zip`/bootstrap 경로 제거
- [ ] `wrapper.mm` 헤더 include 경로를 패키지 링크 기준으로 검증

### Phase C: 게이트/검증
- [ ] Device/Simulator `xcodebuild` green
- [ ] CI에서 checksum mismatch 시 실패하도록 스크립트 추가
- [ ] `README.md` 설치 절차 업데이트

## 6. 체크리스트

- [ ] 새로 clone한 환경에서 bootstrap 없이 빌드 가능
- [ ] Apple Silicon 시뮬레이터 빌드 성공
- [ ] 링크 에러 없이 `wrapper.mm` 빌드 성공
- [ ] 기존 solve 기능 회귀 없음

## 7. 리스크와 대응

### 7.1 아티팩트 용량 증가
- 대응: Release attachment 또는 별도 artifact 저장 경로 사용, Git history 비대화 방지 정책 적용

### 7.2 OpenCV 버전 상향에 따른 행위 변화
- 대응: `wrapper.mm` 기준 fixture regression 테스트 추가 (P1 테스트 트랙 연계)

### 7.3 CI 환경별 캐시 불일치
- 대응: checksum 검증 실패 시 캐시 무효화 후 재다운로드

## 8. 롤백 전략

- package reference를 기존 zip + bootstrap 경로로 되돌리는 fallback 브랜치 유지
- fallback 적용 시에도 checksum 문서화를 남겨 재시도 가능 상태 유지
