
class PBox {
  float xi, yi, xf, yf;
  PBox() { xi = yi = xf = yf = 0; }
  boolean isInside(float x, float y) {
    return ((x >= xi) && (x <= xf) && (y >= yi) && (y <= yf));
  }
}

class svdButton {
  int x, y;
  int w, h;
  PShape shape;
  color offColor;
  color onColor;
  boolean focus;
  String tooltip;
  
  
  
  PBox box;    // Bounding box
  
  svdButton(String svdFileName, int _x, int _y, int _w, int _h, color c, String t) {
    box = new PBox();
    shape = loadShape(svdFileName);
    normalize();
    shape.translate(_x, _y);
    shape.setStroke(false);
    x = _x;
    y = _y;
    w = _w;
    h = _h;
    onColor = c;
    offColor = color(red(c) * 235.0 / 255.0, green(c) * 235.0 / 255.0, blue(c) * 235.0 / 255.0);
    shape.setFill(offColor);
    tooltip = t;
    focus = false;
    findBoundingBox();
  }
  
  void normalize() {
    float sx, sy;

    PBox box = new PBox();
    box.xi = box.yi = 1e10;
    box.xf = box.yf = -1e10;

    findBoxRec(shape, box);
    //println("(", box.xi, ", ", box.yi, ") - (", box.xf, ", ", box.yf, ")");
    
    sx = 32 / (box.xf - box.xi);
    sy = 32 / (box.yf - box.yi);
    
    shape.translate(-box.xi, -box.yi);
    shape.scale(sx, sy);
  }
  
  void findBoxRec(PShape s, PBox box) {
    int i;
    PVector v;
    
    for (i = 0; i < s.getVertexCount(); i++) {
      v = s.getVertex(i);
      if (v.x < box.xi) box.xi = v.x;
      if (v.x > box.xf) box.xf = v.x;
      if (v.y < box.yi) box.yi = v.y;
      if (v.y > box.yf) box.yf = v.y;
    }

    for (i = 0; i < s.getChildCount(); i++) {
      findBoxRec(s.getChild(i), box);
    }
  }
  
  void setFillRec(PShape s, color c) {
    int i;
    s.setFill(c);
    for (i = 0; i < s.getChildCount();  i++) setFillRec(s.getChild(i), c);
  }
  
  void findBoundingBox() {
    int px, py, i = 0;
    PGraphics temp = createGraphics(width, height, P3D);
    temp.beginDraw();
    temp.background(color(0));
    temp.shape(shape, x, y, w, h);
    temp.endDraw();
    temp.loadPixels();
    box.xi = temp.width; box.yi = temp.height; box.xf = 0; box.yf = 0;
    for (py = 0; py < temp.height; py++) {
      for (px = 0; px < temp.width; px++) {
        if ((temp.pixels[i++] & 0xFFFFFF) != 0) {
          if (px < box.xi) box.xi = px;
          if (py < box.yi) box.yi = py;
          if (px > box.xf) box.xf = px;
          if (py > box.yf) box.yf = py;
        }
      }
    }
  }

  void draw() {
    setFillRec(shape, (box.isInside(mouseX, mouseY) && mousePressed) ? onColor : offColor);
    
    shape(shape, x, y, w, h);
    pushStyle();
    if (box.isInside(mouseX, mouseY)) {
      fill(255);
      textAlign(LEFT, TOP);
      textSize(14);
      text(tooltip, box.xi + 2, box.yf + 4);
      if (mousePressed) {
        focus = true;
      } else {
        if (focus) { action(); }
        focus = false;
      }
    } else {
      focus = false;
    }
    popStyle();
  }
  
  public void action() {
  }
}



class svdButtonMenu {
  svdButton[] button;
  
  svdButtonMenu() {
    button = new svdButton[0];
  }
  
  void addButton(svdButton newButton) {
    if (button != null && newButton != null) button = (svdButton[])append(button, newButton);
  }
  
  void draw() {
    if (button != null) {
      for (int i = 0; i < button.length; i++) {
        button[i].draw();
      }
    }
  }
}