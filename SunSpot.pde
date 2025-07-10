class SunSpot {
  PVector position; // Координаты центра пятна (в пикселях на effectsCanvas)
  float size;       // Радиус пятна в пикселях
  float age;        // Текущий возраст в секундах
  float lifetime;   // Максимальное время жизни в секундах
  
  SunSpot(float x, float y, float s, float lt) {
    position = new PVector(x, y);
    size = s;
    lifetime = lt;
    age = 0;
  }
  
  void update(float dt) {
    age += dt;
    
    // Добавляем небольшой дрейф
    float angle = noise(position.x * 0.01, position.y * 0.01, age * 0.1) * TWO_PI * 2.0;
    float speed = 5.0; // пикселей в секунду
    position.x += cos(angle) * speed * dt;
    position.y += sin(angle) * speed * dt;
  }
  
  boolean isDead() {
    return age > lifetime;
  }
}
