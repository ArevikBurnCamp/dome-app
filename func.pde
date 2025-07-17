
void precomputeLedMapMetrics() {
  if (globalLedMap == null || globalLedMap.isEmpty()) {
    ledMapCenter = null;
    ledMapMaxRadius = 0;
    return;
  }

  ledMapCenter = new PVector(0, 0);
  for (LedPoint p : globalLedMap.values()) {
    ledMapCenter.add(p.x, p.y);
  }
  ledMapCenter.div(globalLedMap.size());

  ledMapMaxRadius = 0;
  for (LedPoint p : globalLedMap.values()) {
    float dist = PVector.dist(ledMapCenter, new PVector(p.x, p.y));
    if (dist > ledMapMaxRadius) {
      ledMapMaxRadius = dist;
    }
  }
}

void startSearch() {
  String[] ipParts = split(KetaiNet.getIP(), '.');
  String[] maskParts = split(subnet.text, '.');

  if (ipParts.length < 4 || maskParts.length < 4) {
    println("Error: Invalid IP or subnet mask format.");
    ips.clear();
    ips.append("Invalid IP/Mask");
    if (dropIP != null) dropIP.selected = 0;
    searchF = false;
    return;
  }

  int[] ipv4 = int(ipParts);
  int[] mask = int(maskParts);
  found = false;
  curIP = "";
  brIP = "";
  for (int i = 0; i < 4; i++) {
    brIP += ipv4[i] | (mask[i] ^ 0xFF);
    if (i != 3) brIP += '.';
  }

  searchF = true;
  parseMode = 0;

  // выводим однократно
  ips.clear();
  ips.append("searching...");
  dropIP.selected = 0;
  // ui(); // This should be called in the main draw loop
  ips.clear();

  curIP = brIP;
  sendData(new int[] {0});
  actionTmr = millis();
}

void requestCfg() {
  parseMode = 1;
  int[] buf = {1};
  sendData(buf);
}

void sendData(int[] data) {
  int[] buf = {'G', 'T'};
  buf = concat(buf, data);
  sendData(byte(buf));
}

void sendData(byte[] data) {
  if (curIP != null && !curIP.isEmpty() && curIP.charAt(0) != 'n') {
    udp.send(data, curIP, port);
    delay(15);
    udp.send(data, curIP, port);
  }
}

color[] sampleLedColors() {
  color[] ledColors = new color[TOTAL_LEDS];

  if (leds == null || leds.length == 0 || ledMapCenter == null || ledMapMaxRadius == 0) {
    // Заполняем черным, если карта не загружена или метрики не рассчитаны
    for (int i = 0; i < TOTAL_LEDS; i++) {
      ledColors[i] = color(0);
    }
    return ledColors;
  }

  for (int i = 0; i < leds.length; i++) {
    LedPoint led = leds[i];
    if (led == null) { // Используем 'leds' массив, он уже учитывает калибровку
      ledColors[i] = color(0);
      continue;
    }

    // Рассчитываем вектор от центра карты до светодиода
    PVector ledVector = new PVector(led.x - ledMapCenter.x, led.y - ledMapCenter.y);

    // Находим полярные координаты
    float angle = ledVector.heading(); // Угол в радианах
    float radius = ledVector.mag();

    // Преобразуем в UV-координаты для текстуры
    float u = (angle + PI) / TWO_PI; // u (0..1) - по окружности
    float v = radius / ledMapMaxRadius;   // v (0..1) - от центра к краю

    // Инвертируем v для эффекта "от краев к центру"
    v = 1.0 - v;

    // Рассчитываем итоговые (x, y) для сэмплирования с холста эффектов
    int sample_x = (int)(u * effectsCanvas.width);
    int sample_y = (int)(v * effectsCanvas.height);

    // Ограничиваем координаты, чтобы не выйти за пределы холста
    sample_x = constrain(sample_x, 0, effectsCanvas.width - 1);
    sample_y = constrain(sample_y, 0, effectsCanvas.height - 1);

    // Берем цвет и сохраняем
    ledColors[i] = effectsCanvas.get(sample_x, sample_y);
  }
  
  return ledColors;
}

HashMap<Integer, LedPoint> scanCurrentView() {
    int commandId = int(random(65535)); // Уникальный ID для этой сессии сканирования

    ArrayList<ArrayList<PVector>> passData = new ArrayList<ArrayList<PVector>>();
    for (int i = 0; i < PASS_COUNT; i++) {
      ArrayList<Integer> ledsToLight = getLedsForPass(i);
      sendLightCommand(ledsToLight, commandId);
      delay(100);
      
      readCam();
      passData.add(findBrightestPoints()); 
      commandId++; // Новый ID для следующей команды
    }
    sendLightCommand(new ArrayList<Integer>(), commandId); // Выключить все

    // ЗАДАЧА 5: Логика сопоставления и декодирования
    HashMap<Integer, LedPoint> resultMap = new HashMap<Integer, LedPoint>();
    final float MAX_DIST = 10.0;
    final float MAX_DIST_SQR = MAX_DIST * MAX_DIST;

    // 1. Собрать все точки в один список
    ArrayList<PVector> allPointsPos = new ArrayList<PVector>();
    ArrayList<Integer> allPointsPass = new ArrayList<Integer>();
    for (int i = 0; i < PASS_COUNT; i++) {
      for (PVector p : passData.get(i)) {
        allPointsPos.add(p);
        allPointsPass.add(i);
      }
    }

    if (allPointsPos.isEmpty()) {
      return resultMap; // Нет точек для анализа
    }

    // 2. Ускорение поиска соседей при помощи сетки
    HashMap<String, ArrayList<Integer>> grid = new HashMap<String, ArrayList<Integer>>();
    for (int i = 0; i < allPointsPos.size(); i++) {
      PVector p = allPointsPos.get(i);
      String key = (int)(p.x / MAX_DIST) + "_" + (int)(p.y / MAX_DIST);
      if (!grid.containsKey(key)) {
        grid.put(key, new ArrayList<Integer>());
      }
      grid.get(key).add(i);
    }

    // 3. Кластеризация точек
    ArrayList<ArrayList<Integer>> clustersOfIndices = new ArrayList<ArrayList<Integer>>();
    boolean[] visited = new boolean[allPointsPos.size()];

    for (int i = 0; i < allPointsPos.size(); i++) {
      if (visited[i]) continue;

      ArrayList<Integer> newClusterIndices = new ArrayList<Integer>();
      Queue<Integer> toProcess = new LinkedList<Integer>();

      visited[i] = true;
      toProcess.add(i);

      while (!toProcess.isEmpty()) {
        int currentIdx = toProcess.poll();
        newClusterIndices.add(currentIdx);
        PVector currentPos = allPointsPos.get(currentIdx);
        int cellX = (int)(currentPos.x / MAX_DIST);
        int cellY = (int)(currentPos.y / MAX_DIST);

        for (int dx = -1; dx <= 1; dx++) {
          for (int dy = -1; dy <= 1; dy++) {
            String key = (cellX + dx) + "_" + (cellY + dy);
            if (grid.containsKey(key)) {
              for (int neighborIdx : grid.get(key)) {
                if (visited[neighborIdx]) continue;

                PVector neighborPos = allPointsPos.get(neighborIdx);
                float ddx = currentPos.x - neighborPos.x;
                float ddy = currentPos.y - neighborPos.y;
                if ((ddx * ddx + ddy * ddy) < MAX_DIST_SQR) {
                  visited[neighborIdx] = true;
                  toProcess.add(neighborIdx);
                }
              }
            }
          }
        }
      }
      clustersOfIndices.add(newClusterIndices);
    }

    // 4. Декодирование кластеров
    for (ArrayList<Integer> clusterIndices : clustersOfIndices) {
      // Эвристика: кластер должен быть достаточно большим, чтобы считать его стабильным
      if (clusterIndices.size() < 5) {
        continue;
      }

      PVector center = new PVector(0, 0);
      for (int idx : clusterIndices) {
        center.add(allPointsPos.get(idx));
      }
      center.div(clusterIndices.size());

      int ledId = 0;
      boolean possible = true;
      for (int bit = 0; bit < BIT_COUNT; bit++) {
        boolean presentOnDirect = false;
        boolean presentOnInverse = false;

        for (int idx : clusterIndices) {
          int pass = allPointsPass.get(idx);
          if (pass == bit) {
            presentOnDirect = true;
          }
          if (pass == bit + BIT_COUNT) {
            presentOnInverse = true;
          }
        }

        if (presentOnDirect && !presentOnInverse) {
          ledId |= (1 << bit);
        } else if (!presentOnDirect && presentOnInverse) {
          // бит равен 0, ничего не делаем
        } else {
          // Неоднозначность (точка есть в обоих проходах или нет ни в одном)
          // Считаем траекторию невалидной
          possible = false;
          break;
        }
      }

      if (possible) {
        resultMap.put(ledId, new LedPoint(ledId, center.x, center.y));
      }
    }
    
    return resultMap;
  }

import org.opencv.core.Mat;
import org.opencv.core.MatOfPoint2f;
import org.opencv.core.Point;
import org.opencv.calib3d.Calib3d;
import org.opencv.core.Core;
import java.util.List;

void stitchNewPoints(HashMap<Integer, LedPoint> newPoints) {
  if (globalLedMap.isEmpty()) {
    globalLedMap.putAll(newPoints);
    precomputeLedMapMetrics();
    return;
  }

  ArrayList<PVector> globalMatchPVectors = new ArrayList<PVector>();
  ArrayList<PVector> localMatchPVectors = new ArrayList<PVector>();

  for (Integer id : newPoints.keySet()) {
    if (globalLedMap.containsKey(id)) {
      globalMatchPVectors.add(new PVector(globalLedMap.get(id).x, globalLedMap.get(id).y));
      localMatchPVectors.add(new PVector(newPoints.get(id).x, newPoints.get(id).y));
    }
  }

  if (globalMatchPVectors.size() >= 4) {
    MatOfPoint2f globalMatPoints = pvectorToMatOfPoint2f(globalMatchPVectors);
    MatOfPoint2f localMatPoints = pvectorToMatOfPoint2f(localMatchPVectors);

    Mat homography = Calib3d.findHomography(localMatPoints, globalMatPoints, Calib3d.RANSAC, 5);

    ArrayList<PVector> allNewPointsPVectors = new ArrayList<PVector>();
    for(LedPoint p : newPoints.values()){
      allNewPointsPVectors.add(new PVector(p.x, p.y));
    }
    
    MatOfPoint2f allNewPointsMat = pvectorToMatOfPoint2f(allNewPointsPVectors);
    MatOfPoint2f transformedPointsMat = new MatOfPoint2f();

    Core.perspectiveTransform(allNewPointsMat, transformedPointsMat, homography);
    
    Point[] transformedPoints = transformedPointsMat.toArray();
    int i = 0;
    for (LedPoint p : newPoints.values()) {
      Point tp = transformedPoints[i];
      globalLedMap.put(p.id, new LedPoint(p.id, (float)tp.x, (float)tp.y));
      i++;
    }
  }
  
  precomputeLedMapMetrics();
}

MatOfPoint2f pvectorToMatOfPoint2f(ArrayList<PVector> points) {
    Point[] pointArray = new Point[points.size()];
    for (int i = 0; i < points.size(); i++) {
        pointArray[i] = new Point(points.get(i).x, points.get(i).y);
    }
    return new MatOfPoint2f(pointArray);
}

void saveMapToFile() {
  JSONObject json = new JSONObject();
  JSONArray ledsArray = new JSONArray();
  
  for (LedPoint p : globalLedMap.values()) {
    JSONObject ledData = new JSONObject();
    ledData.setInt("id", p.id);
    ledData.setFloat("x", p.x);
    ledData.setFloat("y", p.y);
    ledsArray.setJSONObject(ledsArray.size(), ledData);
  }
  
  json.setJSONArray("leds", ledsArray);
  saveJSONObject(json, "data/ledmap.json");
  
  // Обновляем глобальный массив leds для сэмплирования
  updateLedsArray();
}

void loadMapFromFile() {
  try {
    JSONObject json = loadJSONObject("data/ledmap.json");
    if (json == null) {
      println("ledmap.json not found or is empty.");
      globalLedMap = new HashMap<Integer, LedPoint>();
      updateLedsArray();
      return;
    }
    
    JSONArray ledsArray = json.getJSONArray("leds");
    globalLedMap.clear();
    for (int i = 0; i < ledsArray.size(); i++) {
      JSONObject ledData = ledsArray.getJSONObject(i);
      int id = ledData.getInt("id");
      float x = ledData.getFloat("x");
      float y = ledData.getFloat("y");
      globalLedMap.put(id, new LedPoint(id, x, y));
    }
  } catch (Exception e) {
    println("Error loading or parsing ledmap.json:");
  e.printStackTrace();
    globalLedMap = new HashMap<Integer, LedPoint>();
  }
  
  updateLedsArray();
  precomputeLedMapMetrics(); // Вызываем предрасчет после загрузки
}

void updateLedsArray() {
  if (globalLedMap == null || globalLedMap.isEmpty()) {
    leds = new LedPoint[0];
    return;
  }
  
  // Находим максимальный ID, чтобы определить размер массива
  int maxId = 0;
  for (LedPoint p : globalLedMap.values()) {
    if (p.id > maxId) {
      maxId = p.id;
    }
  }
  
  leds = new LedPoint[maxId + 1];
  for (LedPoint p : globalLedMap.values()) {
    leds[p.id] = p;
  }
}

void sendLightCommand(ArrayList<Integer> ledsToLight, int commandId) {
  final int MAX_LEDS_PER_PACKET = 512;
  
  if (ledsToLight.isEmpty()) {
    // Отправляем один пакет с пустым списком для выключения всех диодов
    int[] header = {6, commandId / 256, commandId % 256, 1, 0, 0, 0};
    sendData(header);
    return;
  }

  int numChunks = (int)ceil((float)ledsToLight.size() / MAX_LEDS_PER_PACKET);

  for (int i = 0; i < numChunks; i++) {
    int startIndex = i * MAX_LEDS_PER_PACKET;
    int endIndex = min((i + 1) * MAX_LEDS_PER_PACKET, ledsToLight.size());
    List<Integer> chunk = ledsToLight.subList(startIndex, endIndex);

    // Заголовок: {код, id_H, id_L, всего_пакетов, номер_пакета, кол-во_в_пакете_H, кол-во_в_пакете_L}
    int[] command = new int[7 + chunk.size() * 2];
    command[0] = 6;
    command[1] = commandId / 256;
    command[2] = commandId % 256;
    command[3] = numChunks;
    command[4] = i;
    command[5] = chunk.size() / 256;
    command[6] = chunk.size() % 256;

    for (int j = 0; j < chunk.size(); j++) {
      int ledId = chunk.get(j);
      command[7 + j * 2] = ledId / 256;
      command[8 + j * 2] = ledId % 256;
    }
    sendData(command);
    delay(5); // Небольшая задержка между пакетами
  }
}

ArrayList<Integer> getLedsForPass(int pass) {
  ArrayList<Integer> leds = new ArrayList<Integer>();
  boolean inverted = (pass >= BIT_COUNT);
  int bit = inverted ? pass - BIT_COUNT : pass;

  for (int i = 0; i < TOTAL_LEDS; i++) {
    boolean bitIsSet = ((i >> bit) & 1) == 1;
    if (inverted ? !bitIsSet : bitIsSet) {
      leds.add(i);
    }
  }
  return leds;
}
