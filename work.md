1. Supabase 초기화 작업 완료 (2024-06-17)

- supabase_flutter, postgrest 패키지 추가
- .env.example 파일 생성 및 환경 변수 설정
- SupabaseClientService 클래스 구현
- AuthService 클래스 구현 (Supabase Auth 연동)
- LoginScreen 수정
- 에러 해결: User 클래스 충돌 해결 (hide 키워드 사용)
  Supabase 초기 설정 완료 및 로그인 화면 오류 수정 (2024-06-17)

# 작업 로그

## 2024-06-18: 차트 화면 레이아웃 버그 수정

### 문제 상황

차트 메뉴를 누르면 앱이 멈추고 다음과 같은 오류가 발생:

```
BoxConstraints forces an infinite width.
These invalid constraints were provided to RenderPhysicalShape's layout() function by the following function, which probably computed the invalid constraints in question:
  RenderConstrainedBox.performLayout (package:flutter/src/rendering/proxy_box.dart:293:14)
The offending constraints were:
  BoxConstraints(w=Infinity, 48.0<=h<=Infinity))
```

### 원인 분석

- Row 또는 Column 내부에 무한한 너비를 가진 위젯이 있을 때 발생하는 레이아웃 오류
- 특히 차트 화면의 시간 프레임 선택 위젯과 차트 타입 선택 위젯에서 문제 발생
- Row 내부에 있는 위젯들이 명시적인 너비 제약 없이 무한한 공간을 요구함

### 해결 방법 (1차 시도)

1. 차트 타입 선택 위젯의 Row에 `mainAxisSize: MainAxisSize.min` 추가
2. 오프라인 모드 표시 Row를 Center 위젯으로 감싸서 무한 너비 문제 해결
3. 차트 타입 선택 위젯을 Center 위젯으로 감싸서 무한 너비 문제 해결
4. 시간 프레임 그룹 위젯의 Column에 `mainAxisSize: MainAxisSize.min` 추가
5. 시간 프레임 버튼들을 표시하는 Row를 SingleChildScrollView로 감싸고 `mainAxisSize: MainAxisSize.min` 추가

### 해결 방법 (2차 시도 - 추가 수정)

오류가 계속되어 더 광범위한 수정이 필요했습니다:

1. 차트 영역 위젯(\_buildChartArea)의 모든 Column에 `mainAxisSize: MainAxisSize.min` 추가
2. 모든 Center 위젯에 SizedBox 또는 ConstrainedBox로 명시적인 너비 제한 추가
3. 차트 타입 버튼과 시간 프레임 버튼에 명시적인 크기 설정(SizedBox로 감싸기)
4. 시간 프레임 그룹 위젯에 고정 너비 추가 (버튼 개수에 기반한 예상 너비)
5. 차트 화면 body를 SafeArea로 감싸고 crossAxisAlignment 명확히 설정
6. 차트 설정 다이얼로그 content를 ConstrainedBox로 감싸서 크기 제한

### 적용된 주요 변경사항

1. 모든 버튼 위젯에 명시적인 크기 제한 추가:

```dart
// 차트 타입 버튼
return SizedBox(
  width: 100, // 명시적인 너비 설정
  height: 40, // 명시적인 높이 설정
  child: ElevatedButton.icon(...)
);

// 시간 프레임 버튼
return SizedBox(
  width: 70, // 명시적인 너비 설정
  height: 36, // 명시적인 높이 설정
  child: Padding(...)
);
```

2. 모든 Center 위젯 내부에 명시적인 너비 제한 추가:

```dart
return SizedBox(
  width: double.infinity,
  child: Center(
    child: Column(...)
  )
);
```

3. 차트 오프라인 인디케이터에 최대 너비 제한 추가:

```dart
return Container(
  constraints: const BoxConstraints(maxWidth: 200),
  ...
);
```

4. 시간 프레임 선택기에 명시적인 높이와 너비 제한 추가:

```dart
return SizedBox(
  width: MediaQuery.of(context).size.width,
  height: 100,
  child: SingleChildScrollView(...)
);
```

### 결과

- 차트 메뉴 클릭 시 발생하던 무한 너비 제약 조건 오류 해결
- 차트 화면이 정상적으로 표시됨
- 모든 위젯이 적절한 크기 제약을 가지게 되어 레이아웃 안정성 향상

### 개발 규칙 업데이트

- 레이아웃 구현 시 무한 너비 제약 조건 오류를 방지하기 위해 Row와 Column에 적절한 크기 제약을 설정
- 위젯이 무한한 크기를 가지지 않도록 mainAxisSize: MainAxisSize.min 사용
- 스크롤 가능한 위젯 내부에서는 SingleChildScrollView나 ListView를 사용하여 오버플로우 방지
- Center 위젯 내부의 위젯에는 항상 명시적인 너비 제한(SizedBox, ConstrainedBox 등)을 추가
