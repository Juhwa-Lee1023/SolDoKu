
# SolDoKu
![Frame 5](https://user-images.githubusercontent.com/63584245/198891933-9802142e-f07a-4cb0-a524-e2966e08ea75.svg)


 _**스도쿠 사진을 찍으면 스도쿠를 대신 풀어주는 앱입니다!**_ <br/>
 _**풀기 힘든 문제가 있다면 `솔더쿠`에게 부탁하세요!!**_
 _**지원 언어 : 영어, 한글, 한자 간체, 한자 번체, 일본어, 프랑스어, 스페인어, 독일어, 이탈리아**_

🔗App Store : <a href="https://apps.apple.com/kr/app/soldoku/id6443436449">SolDoKu</a>

<img width="217" alt="image" src="https://user-images.githubusercontent.com/63584245/196262442-78d3cd11-f7e0-4fb3-b399-47f0cc37e468.jpeg">

---
### 동작화면
<img src= "https://user-images.githubusercontent.com/63584245/194868092-6b418225-66e8-4955-8428-c999d884ab12.gif" width="296">
<img src= "https://user-images.githubusercontent.com/63584245/191350899-77975436-bbf7-4be5-aba0-b6f54dd57546.gif" width="296">
<img src= "https://user-images.githubusercontent.com/63584245/194869326-73162aad-ad56-43c8-bcf3-cdc88d670313.gif" width="296">


---
### :sparkles: Skills & Tech Stack
* UIKit
* Objective-C
* AVFoundation
* OpenCV
* TensorFlow
* Coremltools

### 🛠 Development Environment

<img width="77" alt="스크린샷 2021-11-19 오후 3 52 02" src="https://img.shields.io/badge/iOS-15.0+-silver"> <img width="95" alt="스크린샷 2021-11-19 오후 3 52 02" src="https://img.shields.io/badge/Xcode-13.3-blue">


## 기술적 도전

> **OpenCV Wrapping**
* UIKit는 swift를 기반으로 코딩되는데 OpenCV는 C,C++로 제작되어 직접 사용은 불가능하므로 Objective c++을 기반으로한 wrapper를 씌워 wrapper가 OpenCV를 호출하고 swift는 Objective c++로 작성된 wrapper를 부르는 방식으로 OpenCV를 사용하였습니다.

> **PyTorch로 만든 모델을 Coremltools로 변환하여 사용**
* 애플에서 제공하는 createML로 모델을 만들어 사용하니 정확성이 떨어져 PyTorch로 만든 모델을 Coremltools로 .mlmodel 로 변환하여 앱에서 사용하였다.


## Trouble Shooting

> * <a href="https://github.com/Juhwa-Lee1023/SolDoKu/pull/2">카메라가 비추는 것을 UIImageView 위에 올리기</a>
> * <a href="https://github.com/Juhwa-Lee1023/SolDoKu/pull/4">Swift로 효율적인 스도쿠 알고리즘 만들기</a>
> * <a href="https://github.com/Juhwa-Lee1023/SolDoKu/pull/6">비디오 프레임이 들어오면 해당되는 프레임을 핸들링하여 UIImageView에 올라기</a>
> * <a href="https://github.com/Juhwa-Lee1023/SolDoKu/pull/8">OpenCV로 비디오 프레임에서 사각형 인식하여 인식한 부분만 자르기</a>
> * <a href="https://github.com/Juhwa-Lee1023/SolDoKu/pull/16">OpenCV와 coremltools를 이용하여 숫자 인식률 개선</a>
> * <a href="https://github.com/Juhwa-Lee1023/SolDoKu/pull/18">스도쿠를 풀이할 수 없는 사진일 경우 어플이 종료되는 경우</a>
> * <a href="https://github.com/Juhwa-Lee1023/SolDoKu/pull/20">정제된 이미지와 앨범에서 사진을 불러올 때 사진이 90도 회전해있는 경우</a>
> * <a href="https://github.com/Juhwa-Lee1023/SolDoKu/pull/36">인식한 스도쿠 영역과 화면에 나타나는 영역이 다른경우</a>
> * <a href="https://github.com/Juhwa-Lee1023/SolDoKu/pull/36">실시간으로 스도쿠 영역에서 숫자를 인식하다 앱이 종료되는 경우</a>

