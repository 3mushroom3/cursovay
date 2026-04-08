## Как запустить проект (максимально подробно)

Проект лежит в `d:\Project\Приложение\kasabov_dgtu`.

Ниже инструкция для **Windows 10/11 + Android**. Для **iOS** в конце есть отдельный раздел (нужен macOS).

---

### 0) Что нужно установить (один раз)

#### Flutter SDK
- Скачайте Flutter (Stable) с `https://flutter.dev/docs/get-started/install`.
- Распакуйте, например в `C:\flutter`.
- Добавьте `C:\flutter\bin` в **PATH** Windows:
  - Пуск → “Переменные среды” → “Переменные среды…” → Path → Добавить.

Проверка (в PowerShell):

```bash
flutter --version
flutter doctor -v
```

Если `flutter` “не распознан”, значит PATH не применился (перезапустите терминал/ПК и проверьте Path).

#### Android Studio + Android SDK
- Установите Android Studio.
- Откройте Android Studio → **SDK Manager**:
  - **SDK Platforms**: установите Android (любую актуальную, например 34).
  - **SDK Tools**: поставьте галочки:
    - Android SDK Platform-Tools
    - Android SDK Build-Tools
    - Android SDK Command-line Tools (latest)

Примите лицензии:

```bash
flutter doctor --android-licenses
```

#### Git (желательно)
Удобно для работы, но не обязательно для запуска.

#### Node.js + Firebase CLI (для Emulator Suite и функций)
Если запускаете **через эмуляторы Firebase**:
- Установите Node.js LTS (18/20).
- Установите Firebase CLI:

```bash
npm i -g firebase-tools
firebase --version
```

---

### 1) Открыть проект

Откройте папку `d:\Project\Приложение\kasabov_dgtu` в VS Code / Cursor.

---

### 2) Установить зависимости Flutter

В терминале (PowerShell) в корне проекта:

```bash
cd "d:\Project\Приложение\kasabov_dgtu"
flutter clean
flutter pub get
```

---

### 3) Выбрать режим Firebase

Есть два режима:
- **A) Реальный Firebase** (лучше для настоящих push-уведомлений)
- **B) Firebase Emulator Suite** (удобно для диплома, когда нет доступа к Firebase Console)

#### 3A) Реальный Firebase (если будет доступ)

1) Создайте проект в Firebase Console.
2) Подключите Android/iOS приложения.
3) Скачайте и положите файлы:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
4) Убедитесь, что включены сервисы:
   - Authentication (Email/Password)
   - Firestore
   - Storage
   - Cloud Messaging (для push)
5) Правила безопасности берутся из файлов `firestore.rules` и `storage.rules`.

Если хотите сгенерировать `firebase_options.dart` через FlutterFire:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

#### 3B) Firebase Emulator Suite (рекомендуется сейчас)

1) Установить зависимости Cloud Functions:

```bash
cd "d:\Project\Приложение\kasabov_dgtu\functions"
npm i
npm run build
```

2) Запустить эмуляторы из корня проекта:

```bash
cd "d:\Project\Приложение\kasabov_dgtu"
firebase emulators:start
```

Откройте UI эмуляторов: `http://localhost:4000`.

Важно:
- Эмулятор **не гарантирует полноценный FCM push** как на реальном проекте, но триггеры функций/Firestore и правила можно отлаживать.

---

### 4) Запустить Android-устройство

Проверить устройства:

```bash
flutter devices
```

Если устройств нет:
- Создайте Emulator в Android Studio → Device Manager → Create device.
- Или подключите телефон по USB и включите “USB debugging”.

---

### 5) Запуск приложения

Из корня проекта:

```bash
cd "d:\Project\Приложение\kasabov_dgtu"
flutter run
```

Если хотите выбрать конкретное устройство:

```bash
flutter devices
flutter run -d <device_id>
```

---

### 6) Первичная настройка данных (рекомендуется)

Для нормальной работы UI желательно иметь категории.
Их можно создать в приложении:
- В ленте (после входа под модератором/админом) нажмите кнопку **категорий** и добавьте категории.

Тестовые сценарии: `docs/test_checklist.md`.

---

### 7) Типичные проблемы и решения

#### Flutter не найден (flutter: command not found)
- Проверьте PATH: `C:\flutter\bin`.
- Перезапустите терминал.

#### Android licenses / SDK
- Запустите `flutter doctor -v`.
- Примите лицензии: `flutter doctor --android-licenses`.

#### Gradle/Java ошибки при сборке
- Установите актуальный Android Studio (он ставит нужную JDK).
- Запустите:

```bash
flutter clean
flutter pub get
```

#### Firebase CLI не видит Java/Node
- Проверьте `node --version` и `npm --version`.
- Переустановите Node.js LTS.

---

### 8) iOS (только macOS)

На Windows iOS собрать нельзя.

На macOS:
1) Установите Xcode и CocoaPods.
2) В корне проекта:

```bash
flutter pub get
cd ios
pod install
cd ..
flutter run
```


