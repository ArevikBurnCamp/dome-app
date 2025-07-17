void receive(byte[] ubuf) {
  if (ubuf == null || ubuf.length < 3) return;
  if (ubuf[0] != 'G' || ubuf[1] != 'T') return;

  ArrayList<Integer> data = new ArrayList<Integer>();
  for (int i = 2; i < ubuf.length; i++) {
    data.add(int(ubuf[i]));
  }

  if (data.size() == 0) return;
  if (parseMode != data.get(0)) return;

  switch (data.get(0)) {
  case 0: // Поиск
    if (data.size() < 2) return;
    String ip = brIP.substring(0, brIP.lastIndexOf('.')+1) + str(data.get(1));
    if (!ips.hasValue(ip)) ips.append(ip);
    break;

  case 1: // Настройки 
    if (data.size() < 10) return;
    searchF = false;
    ledsInput.text = str(data.get(1) * 100 + data.get(2));
    power.value = boolean(data.get(3));
    bri.value = data.get(4);
    auto.value = boolean(data.get(5));
    rnd.value = boolean(data.get(6));
    prd.value = data.get(7);
    offT.value = boolean(data.get(8));
    offS.value = data.get(9);
    break;

  case 4: // Эффект
    if (data.size() < 4) return;
    fav.value = boolean(data.get(1));
    scl.value = data.get(2);
    spd.value = data.get(3);
    break;
  }
}

// ======================== STREAMING ========================
static int commandId = 0;
final int CHUNK_SIZE = 512; // Максимальный размер данных в чанке

void streamFrameToController(color[] colors) {
  if (curIP == null || colors == null) return;

  // 1. Преобразование color[] в byte[] (RGB)
  byte[] colorData = new byte[colors.length * 3];
  for (int i = 0; i < colors.length; i++) {
    color c = colors[i];
    colorData[i * 3 + 0] = (byte) red(c);
    colorData[i * 3 + 1] = (byte) green(c);
    colorData[i * 3 + 2] = (byte) blue(c);
  }

  // 2. Расчет количества чанков
  int totalChunks = (int) Math.ceil((double) colorData.length / CHUNK_SIZE);
  if (totalChunks == 0) return;

  commandId = (commandId + 1) % 65536; // Увеличиваем ID кадра

  // 3. Отправка чанков
  for (int i = 0; i < totalChunks; i++) {
    int offset = i * CHUNK_SIZE;
    int length = min(CHUNK_SIZE, colorData.length - offset);

    // 4. Формирование пакета
    // [7, cmdId_H, cmdId_L, total_chunks, chunk_idx, ...data, CRC8]
    byte[] packet = new byte[6 + length];
    packet[0] = 7; // Код команды
    packet[1] = (byte) (commandId >> 8);
    packet[2] = (byte) (commandId & 0xFF);
    packet[3] = (byte) totalChunks;
    packet[4] = (byte) i;
    
    System.arraycopy(colorData, offset, packet, 5, length);
    
    packet[packet.length - 1] = crc8(packet, 0, packet.length - 1);

    // Отправка по UDP
    udp.send(packet, curIP, port);
  }
}

byte crc8(byte[] data, int offset, int len) {
  byte crc = 0x00;
  for (int i = offset; i < len; i++) {
    byte extract = data[i];
    for (byte tempI = 8; tempI != 0; tempI--) {
      byte sum = (byte) ((crc & 0xFF) ^ (extract & 0xFF));
      sum = (byte) ((sum & 0xFF) & 0x01);
      if (sum != 0) {
        crc = (byte) ((crc & 0xFF) ^ 0x18);
      }
      crc = (byte) (((crc & 0xFF) & 0x01) != 0 ? (byte) (((crc & 0xFF) >> 1) | 0x80) : (byte) ((crc & 0xFF) >> 1));
      extract = (byte) (((extract & 0xFF) & 0x01) != 0 ? (byte) (((extract & 0xFF) >> 1) | 0x80) : (byte) ((extract & 0xFF) >> 1));
    }
  }
  return (byte) (crc & 0xFF);
}
