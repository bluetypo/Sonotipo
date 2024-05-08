
class GenSen {
  String[] farticulos;
  String[] marticulos;
  String[] fsustantivos;
  String[] msustantivos;
  String[] fadjetivos;
  String[] madjetivos;
  String[] verbos;
  String[] adverbios;
  String[] conjunciones;
  
  GenSen() {
    farticulos = loadStrings("data/farticulos.txt");
    fsustantivos = loadStrings("data/fsustantivos.txt");
    fadjetivos = loadStrings("data/fadjetivos.txt");
    marticulos = loadStrings("data/marticulos.txt");
    msustantivos = loadStrings("data/msustantivos.txt");
    madjetivos = loadStrings("data/madjetivos.txt");
    verbos = loadStrings("data/verbos.txt");
    adverbios = loadStrings("data/adverbios.txt");
    conjunciones = loadStrings("data/conjunciones.txt");
  }
  
  String articulo(int g, int idx) {
    return (g % 2 == 0) ? farticulos[idx % farticulos.length] : marticulos[idx % marticulos.length];
  }
  
  String sustantivo(int g, int idx) {
    return (g % 2 == 0) ? fsustantivos[idx % fsustantivos.length] : msustantivos[idx % msustantivos.length];
  }
  
  String adjetivo(int g, int idx) {
    return (g % 2 == 0) ? fadjetivos[idx % fadjetivos.length] : madjetivos[idx % madjetivos.length];
  }
  
  String verbo(int idx) { return verbos[idx % verbos.length]; }
  
  String adverbio(int idx) { return adverbios[idx % adverbios.length]; }
  
  String conjuncion(int idx) { return conjunciones[idx % conjunciones.length]; }
  
  String[] SVACS(int[] p) {
    String s[] = new String[3];
    s[0] = articulo(p[0], p[1]) + " ";
    s[0] += adjetivo(p[0], p[2]).toLowerCase() + " ";
    s[0] += sustantivo(p[0], p[3]).toLowerCase();
    s[1] = verbo(p[4]).toLowerCase() + " ";
    s[1] += adverbio(p[5]).toLowerCase();
    s[2] = articulo(p[6], p[7]).toLowerCase() + " ";
    s[2] += sustantivo(p[6], p[8]).toLowerCase() + " ";
    s[2] += adjetivo(p[6], p[9]).toLowerCase();
    return s;
  }
}