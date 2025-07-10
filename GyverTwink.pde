// Исходник приложения GyverTwink
// Написано на коленке, возможно позже переделаю =(
// v1.0 beta
// v1.1 release
// v1.2 - калибровка больше 255, автоматический масштаб интерфейса, поля ввода подвинул наверх, оптимизация от TheAirBlow 
// v1.3 - опять фиксы масштаба
// v1.6 - починил связь с гирляндой
// v1.7 - порядок в меню, ОПЯТЬ ПОЧИНИЛ СВЯЗЬ

// ============== ВАЖНО! ===============
// Установить библиотеки из менеджера библиотек:
// (Набросок/Импортировать библиотеку/Добавить библиотеку)
// - Video
// - Ketai

// Установить библиотеки вручную:
// (в documents/processing/libraries)
// - http://ubaa.net/shared/processing/udp/ - download Processing library

// Android/Sketch Permissions установлены
// - CAMERA
// - INTERNET
// - READ_EXTERNAL_STORAGE

// ============== НАСТРОЙКИ ===============
// true - Android режим, false - PC режим
private static final boolean androidMode = false;

// для PC режима раскомментируй две строки ниже. Для Android - закомментируй
void openKeyboard() {}
void closeKeyboard() {}

// чтобы сбилдить под Android - нужно установить Android mode
// встроенный билдер собирает под SDK версии 29
// я собирал проект в Android Studio под target 32 версии

// масштаб интерфейса
float androidScale/* = 2.8*/;
float pcScale = 1.3;

// ============== LIBRARIES ===============
import processing.video.*;
import hypermedia.net.*;
import ketai.camera.*;
import ketai.net.*;
import gab.opencv.*;
KetaiCamera Acam;
Capture Wcam;
UDP udp;
OpenCV opencv;

// ============== VARIABLES ================
PGraphics layer1_Canvas;    // Плазма
PGraphics layer2_Canvas;    // Пятна
PGraphics layer3_Canvas;    // Вспышки и петли
PGraphics effectsCanvas;    // Финальный композитинг
PShader plasmaShader, spotsShader, flaresShader, glitchShader, scanlinesShader;
PImage frame;
boolean camReady = false;
boolean camStart = false;
String brIP, curIP;
int port = 8888;
boolean searchF, found = false;
byte parseMode = 0;
int actionTmr;
StringList ips = new StringList();

long lastFrameTime = 0;
final int FRAME_INTERVAL = 33; // ~30 FPS
color[] ledColors;
int totalLeds = 5250; // Значение по умолчанию, будет обновляться

boolean calibF = false;
int calibCount = 0;
int WW, W;
int offs = 30;
String[] file;
HashMap<Integer, LedPoint> globalLedMap = new HashMap<Integer, LedPoint>();
LedPoint[] leds;

// ============== ПРОГРАММА ===============
void settings() {
  if (!androidMode) size(600, 900);
  smooth(8);
}

void setup() {
  androidScale = width/400.0;
  offs = width / 25;
  if (androidMode) W = width/2;
  else W = 300;      
  WW = width-W-offs;

  file = loadStrings("subnet.txt");
  if (file == null) {
    println("Subnet text file is empty");
    file = new String[1];
    file[0] = "255.255.255.0";
    saveStrings("subnet.txt", file);
  }
  subnet.text = file[0];

  if (androidMode) uiSetScale(androidScale);
  else uiSetScale(pcScale);

  udp = new UDP(this);
  udp.listen(true);
  startSearch();
  opencv = new OpenCV(this, width, height);
  loadMapFromFile();

  effectsCanvas = createGraphics(512, 512, P2D);
  layer1_Canvas = createGraphics(512, 512, P2D);
  layer2_Canvas = createGraphics(512, 512, P2D);
  layer3_Canvas = createGraphics(512, 512, P2D);

  // Загружаем шейдеры для слоев
  plasmaShader = loadShader("data/plasma.frag", "data/plasma.vert");
  spotsShader = loadShader("data/spots.frag", "data/spots.vert");
  flaresShader = loadShader("data/flares.frag", "data/flares.vert");
  glitchShader = loadShader("data/glitch.frag");
  scanlinesShader = loadShader("data/scanlines.frag");
  ledColors = new color[totalLeds];
}

void draw() {
  updateScenario();

  if (currentState == ScenarioState.GLITCH) {
    // --- РЕНДЕРИНГ В РЕЖИМЕ ГЛИТЧА ---

    // 1. Рендерим базовую плазму (как фон для перехода)
    plasmaShader.set("time", millis() / 1000.0);
    plasmaShader.set("resolution", layer1_Canvas.width, layer1_Canvas.height);
    layer1_Canvas.beginDraw();
    layer1_Canvas.shader(plasmaShader);
    layer1_Canvas.rect(0, 0, layer1_Canvas.width, layer1_Canvas.height);
    layer1_Canvas.endDraw();

    // 2. Рендерим сам глитч-паттерн
    glitchShader.set("u_time", millis() / 1000.0);
    glitchShader.set("u_resolution", layer2_Canvas.width, layer2_Canvas.height);
    layer2_Canvas.beginDraw();
    layer2_Canvas.shader(glitchShader);
    layer2_Canvas.rect(0, 0, layer2_Canvas.width, layer2_Canvas.height);
    layer2_Canvas.endDraw();

    // 3. Смешиваем все с помощью scanlines шейдера
    scanlinesShader.set("u_time", millis() / 1000.0);
    scanlinesShader.set("u_resolution", effectsCanvas.width, effectsCanvas.height);
    scanlinesShader.set("u_baseTexture", layer1_Canvas);
    scanlinesShader.set("u_glitchTexture", layer2_Canvas);
    scanlinesShader.set("u_scanline_pos", glitchScanlinePos);
    scanlinesShader.set("u_scanline_width", 0.1); // Ширина размытия перехода

    effectsCanvas.beginDraw();
    effectsCanvas.shader(scanlinesShader);
    effectsCanvas.rect(0, 0, effectsCanvas.width, effectsCanvas.height);
    effectsCanvas.endDraw();

  } else {
    // --- ОБЫЧНЫЙ МНОГОСЛОЙНЫЙ РЕНДЕРИНГ ---

    // Проход 1: Рендерим плазму в layer1_Canvas
    plasmaShader.set("time", millis() / 1000.0);
    plasmaShader.set("resolution", layer1_Canvas.width, layer1_Canvas.height);
    layer1_Canvas.beginDraw();
    layer1_Canvas.shader(plasmaShader);
    layer1_Canvas.rect(0, 0, layer1_Canvas.width, layer1_Canvas.height);
    layer1_Canvas.endDraw();

    // Проход 2: Рендерим пятна в layer2_Canvas
    spotsShader.set("time", millis() / 1000.0);
    spotsShader.set("resolution", layer2_Canvas.width, layer2_Canvas.height);
    layer2_Canvas.beginDraw();
    layer2_Canvas.shader(spotsShader);
    layer2_Canvas.rect(0, 0, layer2_Canvas.width, layer2_Canvas.height);
    layer2_Canvas.endDraw();

    // Проход 3: Рендерим вспышки и петли в layer3_Canvas
    flaresShader.set("resolution", layer3_Canvas.width, layer3_Canvas.height);
    layer3_Canvas.beginDraw();
    layer3_Canvas.background(0, 0); // Прозрачный фон
    layer3_Canvas.shader(flaresShader);
    layer3_Canvas.rect(0, 0, layer3_Canvas.width, layer3_Canvas.height);
    layer3_Canvas.endDraw();

    // Финальное смешивание
    effectsCanvas.beginDraw();
    effectsCanvas.image(layer1_Canvas, 0, 0);
    effectsCanvas.blendMode(ADD);
    effectsCanvas.image(layer2_Canvas, 0, 0);
    effectsCanvas.image(layer3_Canvas, 0, 0);
    effectsCanvas.blendMode(BLEND);
    effectsCanvas.endDraw();
  }
  
  // Отображаем итоговый холст
  image(effectsCanvas, 0, 0, width, height);

  // 1. Сэмплируем цвета с помощью исправленной функции
  if (found && leds != null && leds.length > 0) {
      ledColors = sampleLedColors(); // Получаем массив цветов из func.pde
  }

  // 2. Отправляем кадр на контроллер
  if (found && millis() - lastFrameTime > FRAME_INTERVAL) {
      lastFrameTime = millis();
      if (ledColors != null) {
          streamFrameToController(ledColors);
      }
  }

  if (searchF) {
    if (millis() - actionTmr > 800) {
      searchF = false;
      if (ips.size() == 0) ips.append("not found");
      else {
        found = true;
        requestCfg();
      }
    }
  } else {
    drawTabs();
  }
}

void drawTabs() {
  uiFill();
  // ====== TABS =======
  int w = width / 3;
  int h = w / 2;
  int y = height - h;

  if (IconButton("wrench", 0, y, w, h, curTab == 0)) switchCfg();
  if (IconButton("power-off", w*1, y, w, h, curTab == 1)) switchEffects();
  if (IconButton("camera", w*2, y, w, h, curTab == 2)) switchCalib();

  if (curTab == 0) cfgTab();
  if (curTab == 1) effTab();
  if (curTab == 2) calibTab();
}
