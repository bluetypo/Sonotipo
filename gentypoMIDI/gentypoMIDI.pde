import geomerative.*;
import beads.*;
import processing.pdf.*;
//import gifAnimation.*;
import themidibus.*;

float audioGain = 30;
float angle = 0;               // Grid rotation angle
float rot = 0;                 // Text rotation angle

int fontSize = 320;            // Font size for screen rendering
float verticalSpacing = 1.2;   // Vertical interline spacing
int waveformBaseline = 600;    // Y-position of waveform and audio spectrum plot
int segmentResolution = 1;     // Distance (in pixels) between font nodes
int gridSize = 20;             // Spacing of deformation grid
int freqBands = 20;            // Number of frequency bands used for horizontal deformation

float zoom = 0;                // Initial zoom factor (0 = no zoom)
color textColor = color(255);  // Text color
color[] backColors = { color(131, 175, 156), color(84, 123, 132), color(49, 174, 170), color(244, 106, 60), color(242, 67, 100), color(239, 19, 71) };
color backColorIdx = 5;        // Initial background color index


RFont font;              // loaded font (soon to be a font array)
PShape credits;          // Pre-loaded credits logo
String[] text;           // Text to be displayed
float[] xmodulator;      // Horizontal modulator signal
float[] ymodulator;      // Vertical modulator signal
int idxStore;            // Pointer to next storage position in modulation signal
int currentLine;         // Pointer to current text line to be edited

int numBarsX, numBarsY;  // Size of deformation grid
boolean showCursor;      // Show or hide cursor
boolean drawContours;    // Draw contours or filled characters

PGraphics jpgExport;     // PGraphics for JPG exports
PGraphics gifFrame;
//GifMaker gifExport;    // For GIF exports
boolean saveGifFrame;
boolean isThisThingOn;

svdButtonMenu menu;

GenSen gs;
MidiBus midi;
final int angleCC = 10;
final int resoCC = 74;
final int gridCC = 71;
final int rotCC = 76;
final int zoomCC = 77;
final int backCC = 93;

final int[] textCC = { 73, 114, 18, 19, 16, 17, 75, 91, 79, 72 };
int[] textParam = new int[10];
boolean useGS = false;

void controllerChange(int channel, int number, int value) {
  int k;
  boolean flag = true;
  switch (number) {
    case angleCC: angle = PI / 2 * (float)(64 - value) / 64.0; break;
    case resoCC: segmentResolution = (int)(1 + value / 2); break;
    case gridCC: gridSize = (int)(value / 4 + 2); break;
    case zoomCC: zoom = (value - 64.0) / 6; break;
    case rotCC:  rot = -PI / 2 * (float)(64 - value) / 64.0; break;
    case backCC: backColorIdx = value % backColors.length; break;
    default: for (k = 0; k < textCC.length; k++) {
                if (number == textCC[k]) textParam[k] = value;
                flag = false;
                useGS = true;
             }
             if (flag) println(channel + ": CC " + number + " = " + value);
  }
}

void noteOn(int channel, int pitch, int velocity) {
  switch (pitch) {
    default: println(channel + ": Note = " + pitch + ", Vel = ", velocity);
  }
}



class micButton extends svdButton {
  micButton() { super("001_mic.svg", 10, 5, 17, 27, color(255), "Freeze audio input (click again to unfreeze)"); }
  void action() { isThisThingOn = !isThisThingOn; }
}

class pdfButton extends svdButton {
  pdfButton() { super("002_pdf.svg", 32, 5, 27, 27, color(255), "Export a PDF file (vector graphics)"); }
  void action() { exportPDF(); }
}

class gifButton extends svdButton {
  gifButton() { super("003_gif.svg", 64, 5, 27, 27, color(255), "Export a low-res animated GIF (start/stop)"); }
  void action() { exportGifButton(); }
}

class jpgButton extends svdButton {
  jpgButton() { super("004_jpg.svg", 96, 5, 27, 27, color(255), "Export a hi-res JPG file"); }
  void action() { exportJPG(); }
}

class colorButton extends svdButton {
  colorButton() { super("005_color.svg", 120, 10, 30, 18, color(255), "Change background color (left/right arrows)"); }
  void action() { backColorIdx = (backColorIdx + 1) % backColors.length; }
}

class zoomButton extends svdButton {
  zoomButton() { super("006_zoom.svg", 220, 10, 10, 18, color(255), "Change zoom factor (up/down arrows)"); }
  //void action() {  }
}


// Audio analysis objects
AudioContext ac;
UGen audioIn;
ShortFrameSegmenter sfs;
FFT fft;
PowerSpectrum ps;

void setup() {
  fullScreen(P3D);
  //size(1200, 700, P3D);
  //frame.setResizable(true);
  frameRate(24);
  waveformBaseline = height - 100;

  jpgExport = createGraphics(1200, 1200, P3D);
  gifFrame = createGraphics(width / 3, height / 3, P3D);
  saveGifFrame = false;
  isThisThingOn = true;

  RG.init(this);

  text = new String[1];
  text[0] = "";
  currentLine = 0;

  font = new RFont("SonotipoBase.ttf", fontSize, CENTER);
  credits = loadShape("credits.svg");
  credits.setFill(color(255));
  credits.setStroke(false);
  credits.translate(width - credits.width, height - credits.height);
  
  // Build menu
  menu = new svdButtonMenu();
  menu.addButton(new micButton());
  menu.addButton(new pdfButton());
  menu.addButton(new gifButton());
  menu.addButton(new jpgButton());
  menu.addButton(new colorButton());
  menu.addButton(new zoomButton());
  
  RCommand.setSegmentLength(segmentResolution);
  RCommand.setSegmentator(RCommand.UNIFORMLENGTH);

  setGridSize(gridSize);
  showCursor = true;
  drawContours = false;
  
  gs = new GenSen();
  
  MidiBus.list();
  midi = new MidiBus(this, "Arturia BeatStep", "Arturia BeatStep");

  ac = new AudioContext();
  audioIn = ac.getAudioInput();
  Gain g = new Gain(ac, 1, 0);
  g.addInput(audioIn);
  ac.out.addInput(g);

  sfs = new ShortFrameSegmenter(ac);
  fft = new FFT();
  ps = new PowerSpectrum();
  sfs.addInput(audioIn);
  sfs.addListener(fft);
  fft.addListener(ps);
  ac.out.addDependent(sfs);

  ac.start();  
}


void keyPressed() {
  switch (keyCode) {
  case BACKSPACE: 
    if (text[currentLine].length() > 0) {
      text[currentLine] = text[currentLine].substring(0, text[currentLine].length() - 1);
    } else {
      if (currentLine > 0) {
        text = shorten(text);
        currentLine--;
      }
    }
    useGS = false;
    break;

  case UP: 
    zoom++; 
    break;

  case DOWN: 
    zoom--; 
    break;

  case LEFT: 
    backColorIdx = (backColorIdx - 1 + backColors.length) % backColors.length; 
    break;

  case RIGHT: 
    backColorIdx = (backColorIdx + 1) % backColors.length; 
    break;

  case ENTER:
    text = append(text, "");
    currentLine++;
    useGS = false;
    break;

  default: 
    if (keyCode >= 32 && keyCode <= 122) {
      text[currentLine] = text[currentLine] + key;
      useGS = false;
    }
  }
}


void mouseClicked() {
  //exportJPG();
  //exportPDF();
  //exportGifButton();
}


void exportJPG() {
  renderText(jpgExport);
  jpgExport.save("SON(o)TIPO-" + nf(frameCount, 6) + ".jpg");
}

void exportPDF() {
  color oldColor = textColor;
  
  RCommand.setSegmentLength((segmentResolution < 4) ? 4 : segmentResolution);

  PGraphics pdfExport = createGraphics(jpgExport.width, jpgExport.height, PDF, "SON(o)TIPO-" + nf(frameCount, 6) + ".pdf");
  pdfExport.beginDraw();
  jpgExport.beginRaw(pdfExport);
  textColor = color(0);
  renderText(jpgExport);
  jpgExport.endRaw();
  pdfExport.endDraw();
  pdfExport.dispose();
  textColor = oldColor;
  
  RCommand.setSegmentLength(segmentResolution);  
}


void exportGifButton() {
/*  if (saveGifFrame) {
    gifExport.finish();
    saveGifFrame = false;
  } else {
    gifExport = new GifMaker(this, "SON(o)TIPO-" + nf(frameCount, 6) + ".gif");
    gifExport.setRepeat(0);
    saveGifFrame = true;
  }*/
}

/*
void exportGifFrame() {
  if (saveGifFrame && gifExport != null && gifFrame != null) {
    loadPixels();
    gifFrame.beginDraw();
    gifFrame.image(g, 0, 0, gifFrame.width, gifFrame.height);

    gifFrame.text(nf(frameCount, 6), 100, 100);

    gifFrame.endDraw();
    gifFrame.loadPixels();
    //pushStyle(); tint(255, 128); image(gifFrame, width - gifFrame.width, 0); popStyle();
    gifExport.setDelay(1000 / 12);
    //gifExport.addFrame(gifFrame.pixels, gifFrame.width, gifFrame.height);
    gifExport.addFrame();
  }
}
*/

void draw() {
  RGroup group;
  RPoint[][] pointPaths;
  float[] spectrum;
  String[] T = useGS ? gs.SVACS(textParam) : text;
  PVector center = new PVector(width / 2, height / 2);

  RCommand.setSegmentLength(segmentResolution);


  background(backColors[backColorIdx]);  

  // draw audio waveform
  noFill();
  stroke(255);
  line(0, waveformBaseline, width, waveformBaseline);
  stroke(0, 128, 0);
  float max = 0, y, y0 = waveformBaseline;
  for (int x = 0; x < width; x++) {
    int idx = (int)(x * ac.getBufferSize() / width);
    y = audioGain * audioIn.getValue(0, idx) * 100 + waveformBaseline;
    line(x-1, y0, x, y);

    if (abs(audioGain * audioIn.getValue(0, idx)) > max) max = abs(audioGain * audioIn.getValue(0, idx));
    y0 = y;
  }


  // compute audio RMS level (assumes zero mean)
  float z, rms = 0;
  for (int i = 0; i < ac.getBufferSize(); i++) {
    z = audioGain * audioIn.getValue(0, i);
    rms += z * z;
  }
  rms = sqrt(rms / ac.getBufferSize());
  if (isThisThingOn) storeSample(ymodulator, rms);

  // compute audio spectrum
  spectrum = ps.getFeatures();
  if (spectrum != null && isThisThingOn) {
    for (int i = 0; i < xmodulator.length; i++) xmodulator[i] = i * audioGain * spectrum[i + 1] / 10000;
  } else for (int i = 0; i < xmodulator.length; i++) xmodulator[i] = 0;


  float zdist = 0, zdiv = 1;
  for (int line = 0; line < T.length; line++) {
    if (T[line].length() > zdist) zdist = T[line].length();
  }
  //if (zdist < 4) zdist = 4;
  zdist *= exp(-zoom / 4);
  //zdiv = zdist;
  zdist *= fontSize / 4;

  pushMatrix();
  translate(0, 0, -zdist);

  // process text lines
  for (int line = 0; line < T.length; line++) { 
    float yoff = (0.5 - (float)T.length / 2 + line) * fontSize * verticalSpacing;
    group = font.toGroup(T[line]);
    group.rotate(angle);

    if (drawContours) pointPaths = group.getPointsInPaths();
    else pointPaths = getElementPoints(group);

    // draw text
    //xmodulator = sineModulator(numBarsX, 2, 0);
    float xmax = 0;
    if (pointPaths != null) {
      xmax = modulate(pointPaths, xmodulator, ymodulator, center, idxStore, 1, yoff);
    }
    

    pushMatrix();
    translate(center.x, (center.y + yoff) / zdiv, 0);
    rotate(-angle + rot);

    if ((pointPaths != null) && (T[0].length() > 0)) {
      for (int k = 0; k < pointPaths.length; k++) {
        RPoint[] points = pointPaths[k];

        if (points != null) {
          if (drawContours) { 
            stroke(textColor); 
            noFill();
          } else { 
            noStroke(); 
            fill(textColor);
          }

          beginShape();
          for (int i = 0; i < points.length; i++) {
            vertex(points[i].x / zdiv, points[i].y / zdiv);
          }
          endShape();
        }
      }
    }

    // draw cursor;
    rotate(angle);
    if ((line == currentLine) && showCursor && !useGS) {
      stroke(textColor);
      noFill();
      line(xmax+20, -200, xmax+20, 0);
    }

    popMatrix();
  }
  popMatrix();

  // plot audio spectrum
  if (spectrum != null) {
    float r, dx = (float)width / spectrum.length;
    noStroke();
    fill(249, 203, 203, 30);
    ellipseMode(CENTER);
    for (int i = 1; i < spectrum.length; i++) {
      r = i * spectrum[i] * dx / 2 / 100;
      if (r > dx * 100) r = dx * 100;
      ellipse((i - 0.5) * dx, waveformBaseline, r, r);
    }
  }

  // draw menu and credits
  if (credits != null) shape(credits, 0, 0);  

  // Handle GIF Export (only even frames for a framerate of 12 fps)
/*  if (saveGifFrame) {
    if (frameCount % 2 == 0) exportGifFrame();
    pushStyle();
    textSize(12);
    fill(color(0));
    noStroke();
    text(nf(frameCount, 6), width-100, 10);
    popStyle();
  }
*/
  
  menu.draw();
  textAlign(CENTER, CENTER);
  fill(0, 0, 255);
  //text("UP/DOWN for zoom - LEFT/RIGHT to change background color", width / 2, height - 20);
}


void renderText(PGraphics pg) {
  RGroup group;
  RPoint[][] pointPaths;
  String[] T = text;
  PVector center = new PVector(pg.width / 2, pg.height / 2);

  RCommand.setSegmentLength(segmentResolution);

  pg.beginDraw();

  pg.background(backColors[backColorIdx]);
  fill(backColors[backColorIdx]);
  noStroke();
  rect(0, 0, pg.width, pg.height);

  float zdist = 0;
  for (int line = 0; line < T.length; line++) {
    if (T[line].length() > zdist) zdist = T[line].length();
  }  
  zdist *= fontSize / 4 * exp(-zoom / 4);

  pg.pushMatrix();
  pg.translate(0, 0, -zdist);

  // process text lines
  for (int line = 0; line < T.length; line++) { 
    float yoff = (1.0 - (float)T.length / 2 + line) * fontSize * verticalSpacing;
    group = font.toGroup(T[line]);
    group.rotate(angle);

    if (drawContours) pointPaths = group.getPointsInPaths();
    else pointPaths = getElementPoints(group);

    // draw text
    float xmax = 0;
    if (pointPaths != null) {
      xmax = modulate(pointPaths, xmodulator, ymodulator, center, idxStore, 1, yoff);
    }

    pg.pushMatrix();
    pg.translate(center.x, center.y + yoff, 0);
    rotate(-angle);

    if ((pointPaths != null) && (T[0].length() > 0)) {
      for (int k = 0; k < pointPaths.length; k++) {
        RPoint[] points = pointPaths[k];

        if (points != null) {
          if (drawContours) { 
            pg.stroke(textColor); 
            pg.noFill();
          } else { 
            pg.noStroke(); 
            pg.fill(textColor);
          }

          pg.beginShape();
          for (int i = 0; i < points.length; i++) {
            pg.vertex(points[i].x, points[i].y);
          }
          pg.endShape();
        }
      }
    }

    pg.popMatrix();
  }
  pg.popMatrix();

  pg.endDraw();
}



RPoint[][] getElementPoints(RGroup group) {
  RPoint[][] ep = new RPoint[group.countElements()][];
  for (int i = 0; i < ep.length; i++) {
    ep[i] = group.elements[i].getPoints();
  }
  return ep;
}



void setGridSize(int gs) {
  gridSize = gs;
  numBarsX = (int)ceil(height / gs);
  numBarsY = (int)ceil(width / gs);
  xmodulator = new float[freqBands];
  ymodulator = new float[numBarsY];
  idxStore = 0;
}

void storeSample(float[] modulator, float sample) {
  modulator[idxStore] = sample;
  idxStore = (idxStore + 1) % modulator.length;
}

void drawGrid() {
  int x = 0, y = 0;
  stroke(0, 0, 255, 128);

  while (x < width) {
    line(x, 0, x, height);
    x += gridSize;
  }

  while (y < height) {
    line(0, y, width, y);
    y += gridSize;
  }
}

/*
float modulateHeight(RPoint[][] pointPaths, float[] modulator, int start, float depth) {
 int i, j, k;
 float scale, xmax = 0;
 for (i = 0; i < pointPaths.length; i++) {
 RPoint[] points = pointPaths[i];
 if (points != null) {
 for (j = 0; j < points.length; j++) {
 if (points[j].x > xmax) xmax = points[j].x;
 
 k = (start - (int)floor((points[j].x + width / 2) / gridSize)) % modulator.length;
 if (k < 0) k += modulator.length;
 
 scale = pow(2, depth * modulator[k]);
 points[j].y = (points[j].y - centroid.y) * scale + centroid.y;
 }
 }
 }
 return xmax;
 }
 */


/*
RPoint getRealCentroid(RPoint[][] pointPaths) {
 RPoint c = new RPoint(0, 0);
 int i, j, n = 0;
 if (pointPaths == null) return c;
 
 for (i = 0; i < pointPaths.length; i++) {
 RPoint[] points = pointPaths[i];
 if (points != null) {
 for (j = 0; j < points.length; j++) {
 c.x += points[j].x;
 c.y += points[j].y;
 n++;
 }
 }
 }
 c.x /= n;
 c.y /= n;
 return c;
 }
 */


RPoint getElementCentroid(RPoint[] points) {
  RPoint c = new RPoint(0, 0);
  int i, j, n = 0;

  if (points != null) {
    for (j = 0; j < points.length; j++) {
      c.x += points[j].x;
      c.y += points[j].y;
      n++;
    }
  }

  c.x /= n;
  c.y /= n;
  return c;
}

float modulate(RPoint[][] pointPaths, float[] xmodulator, float[] ymodulator, PVector center, int start, float depth, float yoff) {
  int i, j, kx, ky;
  float xoff, xscale, yscale, xmax = 0;
  RPoint centroid;
  for (i = 0; i < pointPaths.length; i++) {
    RPoint[] points = pointPaths[i];
    if (points != null) {
      centroid = getElementCentroid(points);
      for (j = 0; j < points.length; j++) {
        if (points[j].x > xmax) xmax = points[j].x;

        xoff = xmodulator.length * i / pointPaths.length;
        kx = (start - (int)floor(xoff + (points[j].y + yoff + center.y) / gridSize)) % xmodulator.length;
        if (kx < 0) kx += xmodulator.length;

        ky = (start - (int)floor((points[j].x + center.x) / gridSize)) % ymodulator.length;
        if (ky < 0) ky += ymodulator.length;

        xscale = pow(2, depth * xmodulator[kx]);
        yscale = pow(2, depth * ymodulator[ky]);
        points[j].x = (points[j].x - centroid.x) * xscale + centroid.x;
        points[j].y = (points[j].y - centroid.y) * yscale + centroid.y;
      }
    }
  }
  return xmax;
}

// Generate a test signal for modulation
float[] sineModulator(int length, float cycles, float eta) {
  float[] sine = new float[length];
  for (int i = 0; i < length; i++) {
    sine[i] = sin(2 * PI * cycles * i / length) + eta * random(-1, 1);
  }
  return sine;
}