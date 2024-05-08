# Sonotipo
Sonotipo (Sonotype) is an experimental typography based in the real-time distortion of individual characters based on sound. To develop this font, a computer application was implemented in the Processing language, where the program captures and analyzes sound to obtain the average power and frequency spectrum parameters, which are then used to generate the typography.

The vectorized text is divided in a rectangular grid, and then the audio power is used to distort the columns of the grid while the spectrum is used to distort the rows, resulting in a typography that reacts to sound in different ways. Finally, functions were added for exporting the animated text in GIF format, and individual frames as JPG bitmaps or PDF vector graphics.

For the development of this project, the following Processing libraries were used:
- Beads  (real-time audio acquisition and analysis)
- Geomerative (text vectorization)
- GifAnimation (exporting frames in GIF format)

![image](https://github.com/bluetypo/Sonotipo/blob/main/011_sonotipo.jpg)
![image](https://github.com/bluetypo/Sonotipo/blob/main/sonotipo.gif)

Credits:
Afonso Alba (code & UI)
Manuel Guerrero (graphics, UI and typography)
