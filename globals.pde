// ============== LIBRARIES ===============
import processing.video.*;
import hypermedia.net.*;
import ketai.camera.*;
import ketai.net.*;
import gab.opencv.*;
import java.util.Queue;
import java.util.LinkedList;
import java.util.List;

// ============== CONSTANTS ===============
final int TOTAL_LEDS = 5250;
final int BIT_COUNT = 13;
final int PASS_COUNT = BIT_COUNT * 2;
final int FRAME_INTERVAL = 33; // ~30 FPS

// ============== GLOBALS =================

// --- System & Hardware ---
KetaiCamera Acam;
Capture Wcam;
UDP udp;
OpenCV opencv;
PImage frame;
boolean camReady = false;
boolean camStart = false;

// --- Networking ---
String brIP, curIP;
int port = 8888;
boolean searchF, found = false;
byte parseMode = 0;
int actionTmr;
StringList ips = new StringList();

// --- UI & State ---
int curTab = 0;
float androidScale;
float pcScale = 1.3;
int WW, W;
int offs = 30;
TextInput ledsInput = new TextInput();
TextInput subnet = new TextInput();
DropDown dropIP = new DropDown();
Toggle power = new Toggle();
Toggle offT = new Toggle();
Slider bri = new Slider();
Slider offS = new Slider();
Toggle auto = new Toggle();
Toggle rnd = new Toggle();
Slider prd = new Slider();
Toggle fav = new Toggle();
Slider scl = new Slider();
Slider spd = new Slider();

// --- Rendering & Effects ---
PGraphics layer1_Canvas;    // Плазма
PGraphics layer2_Canvas;    // Пятна
PGraphics layer3_Canvas;    // Вспышки и петли
PGraphics effectsCanvas;    // Финальный композитинг
PShader plasmaShader, spotsShader, flaresShader, glitchShader, scanlinesShader;
long lastFrameTime = 0;
color[] ledColors;

// --- Calibration & LED Map ---
boolean calibF = false;
int calibCount = 0;
String[] file;
HashMap<Integer, LedPoint> globalLedMap = new HashMap<Integer, LedPoint>();
LedPoint[] leds;
PVector ledMapCenter;
float ledMapMaxRadius;

// --- Scenario ---
ScenarioState currentState = ScenarioState.IDLE;
long stateEnterTime = 0;
float phaseValue = 0.0;
float breathValue = 0.0;
float glitchScanlinePos = 0.0;

ArrayList<SunSpot> sunSpots = new ArrayList<SunSpot>();
ArrayList<Flare> flares = new ArrayList<Flare>();
ArrayList<CoronalLoop> coronalLoops = new ArrayList<CoronalLoop>();
