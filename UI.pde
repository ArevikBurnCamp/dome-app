byte curTab = 0;
TextInput leds = new TextInput();
TextInput subnet = new TextInput();
DropDown dropIP = new DropDown();
Toggle power = new Toggle();
Toggle offT = new Toggle();
Slider bri = new Slider();
Slider offS = new Slider();

void cfgTab() {
  uiGlobalX(offs);
  uiResetStep(20);
  LabelCenter("GyverTwink", 20);
  Divider(width-offs*2);

  Label("Subnet:", 15);
  Label("Connection:", 15);
  if (found) {
    Divider(width-offs*2);
    Label("LED amount:", 15);
    Label("Power:", 15);
    Label("Brightness:", 15);
    Divider(width-offs*2);
    Label("Off timer:", 15);
    Label("Turn off in [1-240m]:", 15);
  }

  uiResetStep(20);
  uiStep();
  uiStep();

  if (found) { 
    uiStep();
    uiStep();
    uiStep();
    if (leds.show(WW, uiStep(), W) && androidMode) openKeyboard();
    if (leds.done()) {
      if (androidMode) closeKeyboard();
      int am = int(leds.text);
      totalLeds = am; // Обновляем глобальную переменную
      ledColors = new color[totalLeds]; // Пересоздаем массив
      sendData(new int[] {2, 0, am/100, am % 100});
    }
    if (power.show(WW, uiStep())) sendData(new int[] {2, 1, int(power.value)});
    if (bri.show(0, 255, WW, uiStep(), W)) sendData(new int[] {2, 2, int(bri.value)});
    uiStep();
    if (offT.show(WW, uiStep())) sendData(new int[] {2, 7, int(offT.value)});
    if (offS.show(0, 250, WW, uiStep(), W)) sendData(new int[] {2, 8, int(offS.value)});
  }

  uiResetStep(20);
  uiStep();
  uiStep();
  if (subnet.show(WW, uiStep(), W) && androidMode) openKeyboard();
  if (subnet.done()) {
    if (androidMode) closeKeyboard();
    file[0] = subnet.text;
    saveStrings("subnet.txt", file);
  }
  if (dropIP.show(ips.array(), WW, uiStep(), W-s_height)) {
    curIP = ips.get(dropIP.getSelected());
    requestCfg();
  }
  if (IconButton("sync", WW + W-s_height, uiPrevStep())) startSearch();
}

void effTab() {
  uiGlobalX(offs);
  uiResetStep(50);
  uiGlobalX(offs);
  if (found) {
    if (Button("Start Scenario", offs, height/2 - s_height/2, width - offs*2, s_height*2)) {
      startSunrise();
    }
  } else {
    Label("No devices detected!", 15);
  }
}

void drawCalibrationUI() {
  // 1. Отрисовка видео с камеры
  if (frame != null) {
    PImage frameScaled = frame.copy();
    frameScaled.resize(0, height * 4 / 5);
    image(frameScaled, (width - frameScaled.width) / 2, 0);
    
    // 2. Оверлей с точками из globalLedMap
    float scaleFactor = (float)frameScaled.height / frame.height;
    float offsetX = (width - frameScaled.width) / 2.0;
    float offsetY = 0;

    stroke(255, 0, 0, 200);
    strokeWeight(8);
    for (LedPoint p : globalLedMap.values()) {
      point(p.x * scaleFactor + offsetX, p.y * scaleFactor + offsetY);
    }
    noStroke();

  } else {
    background(0);
    fill(255);
    textAlign(CENTER, CENTER);
    text("Camera not available", width / 2, height / 2);
  }

  // 3. Кнопки
  int btnHeight = 50;
  int btnY = height - (width / 6) - btnHeight - 10;
  int btnWidth = (width - 40) / 3;

  if (Button("Добавить ракурс", 10, btnY, btnWidth, btnHeight)) {
    HashMap<Integer, LedPoint> newPoints = scanCurrentView();
    stitchNewPoints(newPoints);
  }
  if (Button("Сбросить", 20 + btnWidth, btnY, btnWidth, btnHeight)) {
    globalLedMap.clear();
  }
  if (Button("Сохранить", 30 + 2 * btnWidth, btnY, btnWidth, btnHeight)) {
    saveMapToFile();
  }
}

void calibTab() { 
  if (found) {
    // Камера не стартовала в PC режиме
    if (!androidMode && Wcam == null) {
      background(0);
      fill(255);
      textAlign(CENTER, CENTER);
      text("Camera not available on PC yet", width / 2, height / 2);
      return;
    }

    if (camReady) {
      camReady = false;
      readCam();
    }
    
    drawCalibrationUI();

  } else {
    uiGlobalX(offs);
    uiResetStep(50);
    uiGlobalX(offs);
    Label("No devices detected!", 15);
  }
}

void switchCfg() {
  curTab = 0;
  sendData(new int[] {2, 7});
  stopCam();
}
void switchEffects() {
  curTab = 1;
  stopCam();
}
void switchCalib() {
  curTab = 2;
  if (found) startCam();
}
