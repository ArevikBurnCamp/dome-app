// All scenario-related enums and global variables are now in enums.pde and globals.pde

// Управление появлением пятен
final int MAX_SPOTS = 50;
float timeSinceLastSpot = 0;
float nextSpotIn = 20.0; // секунд
ArrayList<SunSpot> sunspots = new ArrayList<SunSpot>();


// Управление появлением вспышек и петель
final int MAX_FLARES = 20;
final int MAX_LOOPS = 10;
float timeSinceLastFlare = 0;
float nextFlareIn = 5.0; // Вспышки чаще
float timeSinceLastLoop = 0;
float nextLoopIn = 15.0;
// ArrayList<Flare> flares = new ArrayList<Flare>(); // Moved to globals.pde
ArrayList<CoronalLoop> loops = new ArrayList<CoronalLoop>();

// ================== TIMING ==================
long scenarioStartTime = 0;
float breathingValue = 1.0;
// lastFrameTime is now global

// Длительность фаз в миллисекундах
final int SUNRISE_DURATION = 30000; // 30 секунд
final int ZENITH_DURATION = 60000;  // 1 минута (условно)
final int SUNSET_DURATION = 30000;  // 30 секунд

// ================== GLITCH STATE ==================
GlitchPhase currentGlitchPhase;
long glitchPhaseStartTime = 0;
// glitchScanlinePos is now global

// Длительность фаз глитча
final int GLITCH_INFECTION_DURATION = 2000; // 2 секунды
final int GLITCH_MAIN_DURATION = 10000; // 10 секунд
final int GLITCH_RECOVERY_DURATION = 2000; // 2 секунды

// Таймер для запуска глитча
float timeSinceLastGlitch = 0;
float nextGlitchIn = 600.0; // 10 минут

void updateScenario() {
  if (currentState == ScenarioState.IDLE) {
    return;
  }

  long currentTime = millis();
  long elapsedTime = currentTime - scenarioStartTime;

  switch (currentState) {
    case SUNRISE:
      if (elapsedTime < SUNRISE_DURATION) {
        // Логика восхода: волна света
        float waveProgress = (float)elapsedTime / SUNRISE_DURATION;
        PVector waveCenter = new PVector(0, effectsCanvas.height / 2.0); // "Восток"
        
        plasmaShader.set("waveProgress", waveProgress);
        plasmaShader.set("waveCenter", waveCenter.x, waveCenter.y);
        plasmaShader.set("isSunrise", true); // Флаг для шейдера
        plasmaShader.set("brightness", 1.0); // Яркость теперь контролируется в шейдере

      } else {
        // Переход в зенит
        currentState = ScenarioState.ZENITH;
        scenarioStartTime = currentTime;
        plasmaShader.set("waveProgress", 1.0); // Убедимся, что волна завершилась
        println("Scenario: ZENITH started");
      }
      break;

      case ZENITH:
        // --- Обновление времени ---
        float currentTimeSeconds = millis() / 1000.0f;
        float dt = (lastFrameTime > 0) ? (currentTimeSeconds - (lastFrameTime / 1000.0f)) : 0;
        lastFrameTime = millis();

        // --- Проверка на запуск глитча ---
        timeSinceLastGlitch += dt;
        if (timeSinceLastGlitch > nextGlitchIn) {
          currentState = ScenarioState.GLITCH;
          currentGlitchPhase = GlitchPhase.INFECTION;
          glitchPhaseStartTime = currentTime;
          timeSinceLastGlitch = 0;
          nextGlitchIn = random(600, 900); // Следующий через 10-15 минут
          println("Scenario: GLITCH started");
          break; 
        }

        if (elapsedTime < ZENITH_DURATION) {
          // --- Логика "дыхания" ---
          breathingValue = 0.85f + 0.15f * sin(millis() * 0.0001f);
          float currentBrightness = 1.0f * breathingValue;
          plasmaShader.set("brightness", currentBrightness);
          plasmaShader.set("waveProgress", 1.1); // Значение > 1.0, чтобы волна не влияла

          // --- Управление солнечными пятнами ---
          updateSunspots(dt);
          
          // --- Управление вспышками и петлями ---
          updateFlaresAndLoops(dt);
          
        } else {
          // Переход в закат
          currentState = ScenarioState.SUNSET;
          scenarioStartTime = currentTime;
          println("Scenario: SUNSET started");
        }
        break;

      case SUNSET:
        if (elapsedTime < SUNSET_DURATION) {
          // Логика заката: волна тьмы
          float waveProgress = (float)elapsedTime / SUNSET_DURATION;
          PVector waveCenter = new PVector(effectsCanvas.width, effectsCanvas.height / 2.0); // "Запад"
          
          plasmaShader.set("waveProgress", waveProgress);
          plasmaShader.set("waveCenter", waveCenter.x, waveCenter.y);
          plasmaShader.set("isSunrise", false); // Флаг для шейдера
          plasmaShader.set("brightness", 1.0); // Яркость теперь контролируется в шейдере

        } else {
          // Завершение сценария
          currentState = ScenarioState.IDLE;
          plasmaShader.set("brightness", 0.0); // Убедимся, что все погасло
          println("Scenario: Finished");
        }
        break;

      case GLITCH:
        long glitchElapsedTime = currentTime - glitchPhaseStartTime;
        switch (currentGlitchPhase) {
          case INFECTION:
            if (glitchElapsedTime < GLITCH_INFECTION_DURATION) {
              glitchScanlinePos = (float)glitchElapsedTime / GLITCH_INFECTION_DURATION;
            } else {
              currentGlitchPhase = GlitchPhase.MAIN;
              glitchPhaseStartTime = currentTime;
            }
            break;
          case MAIN:
            if (glitchElapsedTime < GLITCH_MAIN_DURATION) {
              // Основная фаза, ничего не меняем, просто ждем
            } else {
              currentGlitchPhase = GlitchPhase.RECOVERY;
              glitchPhaseStartTime = currentTime;
            }
            break;
          case RECOVERY:
            if (glitchElapsedTime < GLITCH_RECOVERY_DURATION) {
              glitchScanlinePos = 1.0 - ((float)glitchElapsedTime / GLITCH_RECOVERY_DURATION);
            } else {
              // Возвращаемся в зенит
              currentState = ScenarioState.ZENITH;
              scenarioStartTime = currentTime; // Сбрасываем таймер зенита
              println("Scenario: GLITCH finished, returning to ZENITH");
            }
            break;
        }
        break;
      
    case IDLE:
      // Ничего не делаем
      break;
  }
}

void updateSunspots(float dt) {
  // 1. Создание новых пятен
  timeSinceLastSpot += dt;
  if (sunspots.size() < MAX_SPOTS && timeSinceLastSpot > nextSpotIn) {
    // Создаем новое пятно
    float x = random(effectsCanvas.width);
    float y = random(effectsCanvas.height);
    float size = random(50, 150);
    float lifetime = random(20, 40);
    sunspots.add(new SunSpot(x, y, size, lifetime));
    
    // Сбрасываем таймер
    timeSinceLastSpot = 0;
    nextSpotIn = random(15, 25); // Следующее пятно появится через 15-25 сек
    println("New sunspot created. Total: " + sunspots.size());
  }
  
  // 2. Обновление и удаление старых пятен
  for (int i = sunspots.size() - 1; i >= 0; i--) {
    SunSpot spot = sunspots.get(i);
    spot.update(dt);
    if (spot.isDead()) {
      sunspots.remove(i);
      println("Sunspot removed. Total: " + sunspots.size());
    }
  }
  
  // 3. Передача данных в шейдер
  int numSpots = sunspots.size();
  spotsShader.set("spots_count", numSpots);

  if (numSpots > 0) {
    // Используем массивы фиксированного размера, чтобы соответствовать шейдеру
    float[] positions = new float[MAX_SPOTS * 2];
    float[] sizes = new float[MAX_SPOTS];
    float[] ages = new float[MAX_SPOTS];
    float[] lifetimes = new float[MAX_SPOTS];
    
    for (int i = 0; i < numSpots; i++) {
      SunSpot spot = sunspots.get(i);
      positions[i*2 + 0] = spot.position.x;
      positions[i*2 + 1] = spot.position.y;
      sizes[i] = spot.size;
      ages[i] = spot.age;
      lifetimes[i] = spot.lifetime;
    }
    
    spotsShader.set("spots_positions", positions);
    spotsShader.set("spots_sizes", sizes);
    spotsShader.set("spots_ages", ages);
    spotsShader.set("spots_lifetimes", lifetimes);
  }
}

void updateFlaresAndLoops(float dt) {
  // 1. Создание новых вспышек
  timeSinceLastFlare += dt;
  if (flares.size() < MAX_FLARES && timeSinceLastFlare > nextFlareIn) {
    flares.add(new Flare());
    timeSinceLastFlare = 0;
    nextFlareIn = random(3, 8);
    println("New flare created. Total: " + flares.size());
  }

  // 2. Создание новых петель
  timeSinceLastLoop += dt;
  if (loops.size() < MAX_LOOPS && timeSinceLastLoop > nextLoopIn) {
    loops.add(new CoronalLoop());
    timeSinceLastLoop = 0;
    nextLoopIn = random(10, 20);
    println("New loop created. Total: " + loops.size());
  }

  // 3. Обновление и удаление старых объектов
  for (int i = flares.size() - 1; i >= 0; i--) {
    Flare f = flares.get(i);
    f.update(dt);
    if (f.isDead()) {
      flares.remove(i);
    }
  }
  for (int i = loops.size() - 1; i >= 0; i--) {
    CoronalLoop l = loops.get(i);
    l.update(dt);
    if (l.isDead()) {
      loops.remove(i);
    }
  }

  // 4. Передача данных в шейдер
  // Вспышки
  flaresShader.set("flares_count", flares.size());
  if (flares.size() > 0) {
    float[] flare_data = new float[MAX_FLARES * 4]; // pos.x, pos.y, dir.x, dir.y
    float[] flare_props = new float[MAX_FLARES * 2]; // age, lifetime
    for (int i = 0; i < flares.size(); i++) {
      Flare f = flares.get(i);
      flare_data[i*4 + 0] = f.startPoint.x;
      flare_data[i*4 + 1] = f.startPoint.y;
      flare_data[i*4 + 2] = f.direction.x;
      flare_data[i*4 + 3] = f.direction.y;
      flare_props[i*2 + 0] = f.age;
      flare_props[i*2 + 1] = f.lifetime;
    }
    flaresShader.set("flares_data", flare_data);
    flaresShader.set("flares_props", flare_props);
  }

  // Петли
  flaresShader.set("loops_count", loops.size());
  if (loops.size() > 0) {
    float[] loop_points = new float[MAX_LOOPS * 4]; // p1.x, p1.y, p2.x, p2.y
    float[] loop_props = new float[MAX_LOOPS * 2]; // age, lifetime
    for (int i = 0; i < loops.size(); i++) {
      CoronalLoop l = loops.get(i);
      loop_points[i*4 + 0] = l.p1.x;
      loop_points[i*4 + 1] = l.p1.y;
      loop_points[i*4 + 2] = l.p2.x;
      loop_points[i*4 + 3] = l.p2.y;
      loop_props[i*2 + 0] = l.age;
      loop_props[i*2 + 1] = l.lifetime;
    }
    flaresShader.set("loops_points", loop_points);
    flaresShader.set("loops_props", loop_props);
  }
}


// ================== КЛАССЫ ЭФФЕКТОВ ==================

class Flare {
  PVector startPoint;
  PVector direction;
  float lifetime;
  float age;

  Flare() {
    startPoint = new PVector(random(effectsCanvas.width), random(effectsCanvas.height));
    direction = PVector.random2D();
    lifetime = random(0.5, 1.5); // Короткая жизнь
    age = 0;
  }

  void update(float dt) {
    age += dt;
  }

  boolean isDead() {
    return age > lifetime;
  }
}



void startSunrise() {
  if (currentState == ScenarioState.IDLE) {
    currentState = ScenarioState.SUNRISE;
    scenarioStartTime = millis();
    lastFrameTime = millis();
    sunspots.clear();
    flares.clear();
    loops.clear();
    println("Scenario: SUNRISE started");
  }
}
