import processing.data.*;

JSONArray colorsArray;

void setup() {
  size(800, 400); // Adjust window size as needed
  background(255);

  // Load the JSON file
  colorsArray = loadJSONArray("C:/Users/anush/OneDrive/Documents/PSU/DART/Independent Study 205/fall_colors_by_image.json");

  // Calculate rectangle dimensions
  float rectWidth = width / colorsArray.size();
  float rectHeight;

  // Extract colors from each image's dominant_colors array
  for (int i = 0; i < colorsArray.size(); i++) {
    JSONObject imageObject = colorsArray.getJSONObject(i);
    JSONArray dominantColors = imageObject.getJSONArray("dominant_colors");

    // Divide vertical space for each image
    rectHeight = height / dominantColors.size();

    for (int j = 0; j < dominantColors.size(); j++) {
      JSONObject colorObject = dominantColors.getJSONObject(j);
      int r = colorObject.getInt("R");
      int g = colorObject.getInt("G");
      int b = colorObject.getInt("B");

      // Draw each color as a rectangle
      fill(r, g, b);
      rect(i * rectWidth, j * rectHeight, rectWidth, rectHeight);
    }
  }
}

void draw() {
  // Nothing needed in draw, colors are displayed in setup
}
