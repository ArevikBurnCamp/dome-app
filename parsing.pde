void receive(byte[] ubuf) {
  if (ubuf[0] != 'G' || ubuf[1] != 'T') return;
  int[] data = new int[10];
  for (int i = 0; i < ubuf.length - 2; i++) {
    data[i] = int(ubuf[i+2]);
    //println(data[i]);
  }

  if (parseMode != data[0]) return;

  switch (data[0]) {
  case 0: // Поиск
    String ip = brIP.substring(0, brIP.lastIndexOf('.')+1) + str(data[1]);
    if (!ips.hasValue(ip)) ips.append(ip);
    break;

  case 1: // Настройки 
    searchF = false;
    leds.text = str(data[1] * 100 + data[2]);
    power.value = boolean(data[3]);
    bri.value = data[4];
    auto.value = boolean(data[5]);
    rnd.value = boolean(data[6]);
    prd.value = data[7];
    offT.value = boolean(data[8]);
    offS.value = data[9];
    break;

  case 4: // Эффект
    fav.value = boolean(data[1]);
    scl.value = data[2];
    spd.value = data[3];
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
