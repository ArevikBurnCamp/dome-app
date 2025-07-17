class CoronalLoop {
  PVector p1, p2;
  float lifetime;
  float age;

  CoronalLoop() {
    float w = effectsCanvas.width;
    float h = effectsCanvas.height;
    p1 = new PVector(random(w), random(h));
    // Вторая точка на некотором расстоянии
    p2 = PVector.add(p1, PVector.random2D().mult(random(100, 300)));
    // Ограничиваем, чтобы не выходить за холст
    p2.x = constrain(p2.x, 0, w);
    p2.y = constrain(p2.y, 0, h);

    lifetime = random(8, 15); // Долгая жизнь
    age = 0;
  }

  void update(float dt) {
    age += dt;
  }

  boolean isDead() {
    return age > lifetime;
  }
}
