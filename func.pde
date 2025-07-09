import java.util.*;

void startSearch() {
  int[] ipv4 = int(split(KetaiNet.getIP(), '.'));
  int[] mask = int(split(subnet.text, '.'));
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
  ui();
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
  if (curIP.charAt(0) != 'n') {
    udp.send(data, curIP, port);
    delay(15);
    udp.send(data, curIP, port);
  }
}

HashMap<Integer, LedPoint> scanCurrentView() {
    final int TOTAL_LEDS = 5250;
    final int BIT_COUNT = 13;
    final int PASS_COUNT = BIT_COUNT * 2;
    
    int commandId = int(random(65535)); // Уникальный ID для этой сессии сканирования

    ArrayList<ArrayList<PVector>> passData = new ArrayList<ArrayList<PVector>>();
    for (int i = 0; i < PASS_COUNT; i++) {
      ArrayList<Integer> ledsToLight = getLedsForPass(i, TOTAL_LEDS, BIT_COUNT);
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

void stitchNewPoints(HashMap<Integer, LedPoint> newPoints) {
  if (globalLedMap.isEmpty()) {
    globalLedMap.putAll(newPoints);
    return;
  }

  ArrayList<PVector> globalMatchPoints = new ArrayList<PVector>();
  ArrayList<PVector> localMatchPoints = new ArrayList<PVector>();

  for (Integer id : newPoints.keySet()) {
    if (globalLedMap.containsKey(id)) {
      globalMatchPoints.add(new PVector(globalLedMap.get(id).x, globalLedMap.get(id).y));
      localMatchPoints.add(new PVector(newPoints.get(id).x, newPoints.get(id).y));
    }
  }

  if (globalMatchPoints.size() >= 4) {
    PMatrix3D homography = opencv.findHomography(localMatchPoints, globalMatchPoints);
    
    for (LedPoint p : newPoints.values()) {
      PVector transformedPoint = new PVector(p.x, p.y);
      homography.mult(transformedPoint, transformedPoint);
      globalLedMap.put(p.id, new LedPoint(p.id, transformedPoint.x, transformedPoint.y));
    }
  }
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

ArrayList<Integer> getLedsForPass(int pass, int totalLeds, int bitCount) {
  ArrayList<Integer> leds = new ArrayList<Integer>();
  boolean inverted = (pass >= bitCount);
  int bit = inverted ? pass - bitCount : pass;

  for (int i = 0; i < totalLeds; i++) {
    boolean bitIsSet = ((i >> bit) & 1) == 1;
    if (inverted ? !bitIsSet : bitIsSet) {
      leds.add(i);
    }
  }
  return leds;
}
