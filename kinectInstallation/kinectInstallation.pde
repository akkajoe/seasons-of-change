
import KinectPV2.*;
import processing.video.*;
import processing.data.*;

KinectPV2 kinect;
PImage currentRGBFrame;  
PImage previousRGBFrame; 
PImage motionFrame;     
int lastDetectionTime = 0; // Time of the last motion detection
int detectionCooldown = 1000; // cooldown in milliseconds
boolean motionDetected = false;

Movie video;
boolean showVideo = true;
PImage currentFrame, processedFrame, previousFrame, previousProcessedFrame;

JSONArray colorsArray;
color[][] fallColorsArray; // Array to hold multiple color clusters for each image
int currentColorIndex = 0;
int nextColorIndex = 1;
float transitionProgress = 0; // Progress between 0 (currentColor) and 1 (nextColor)
int currentImageIndex = 0; // Track which image's colors we are using
int stepsBetweenColors = 50; // Decreased steps for faster transitions

color[] transitionColors; // Precomputed intermediate colors for smoother blending
int transitionStep = 0; // Current step in the transition process

float noiseOffsetX = 0.0; // Offset for Perlin noise along the X-axis
float noiseOffsetY = 0.0; // Offset for Perlin noise along the Y-axis
float noiseIncrement = 0.005; // Finer Perlin noise for slight smoothing

int[][] targetColors = {
  {51, 55, 27},   // #33371b
  {123, 125, 120}, // #7b7d78
  {148, 140, 111}, // #948c6f
  {123, 127, 123}, // #7b7f7b
  {70, 80, 54},    // #465036
  {217, 173, 146}, // #d9ad92
  {170, 169, 116}  // #aaa974
};

int colorTolerance = 15; // Tolerance for detecting similar colors
float motionThreshold = 600; // Threshold for motion detection (pixel intensity difference)

void setup() {
  fullScreen();
  // Initialize Kinect
  kinect = new KinectPV2(this);
  kinect.enableColorImg(true);
  kinect.init();

  // Initialize frames
  currentRGBFrame = createImage(1920, 1080, RGB);
  motionFrame = createImage(1920, 1080, ARGB); 

  // Initialize motionFrame with full transparency
  motionFrame.loadPixels();
  for (int i = 0; i < motionFrame.pixels.length; i++) {
    motionFrame.pixels[i] = color(0, 0, 0, 0); // Fully transparent
  }
  motionFrame.updatePixels();

  // Initialize video
  video = new Movie(this, "C:/Users/anush/OneDrive/Documents/PSU/DART/Independent Study 205/code_fallsim/MVI_7956.MP4");
  video.loop();

  // Load fall colors from JSON
  colorsArray = loadJSONArray("C:/Users/anush/OneDrive/Documents/PSU/DART/Independent Study 205/fall_colors_by_image.json");
  fallColorsArray = new color[colorsArray.size()][];

  for (int i = 0; i < colorsArray.size(); i++) {
    JSONObject imageObject = colorsArray.getJSONObject(i);
    JSONArray dominantColors = imageObject.getJSONArray("dominant_colors");

    fallColorsArray[i] = new color[dominantColors.size()];
    for (int j = 0; j < dominantColors.size(); j++) {
      JSONObject colorObject = dominantColors.getJSONObject(j);
      int r = colorObject.getInt("R");
      int g = colorObject.getInt("G");
      int b = colorObject.getInt("B");
      fallColorsArray[i][j] = color(r, g, b);
    }
  }

  initializeTransitionColors();
}

color lastColor = -1; // Use -1 to indicate "uninitialized" instead of null

void draw() {
  
  // Get the current RGB frame from Kinect
  currentRGBFrame = kinect.getColorImage();

  if (currentRGBFrame != null && previousRGBFrame != null) {
    motionFrame.loadPixels();
    currentRGBFrame.loadPixels();
    previousRGBFrame.loadPixels();

    int motionCount = 0; // Counter for motion pixels

    for (int i = 0; i < currentRGBFrame.pixels.length; i++) {
      color curr = currentRGBFrame.pixels[i];
      color prev = previousRGBFrame.pixels[i];

      // Calculate the difference in RGB channels
      float diffR = abs(red(curr) - red(prev));
      float diffG = abs(green(curr) - green(prev));
      float diffB = abs(blue(curr) - blue(prev));
      float diff = diffR + diffG + diffB;

      if (diff > 100) { // Threshold for motion
        motionFrame.pixels[i] = color(255, 0, 0, 255); // Mark as red with full opacity
        motionCount++;
      } else {
        motionFrame.pixels[i] = color(0, 0, 0, 0); // Fully transparent
      }
    }
    motionFrame.updatePixels();

    if (motionCount > 5000 && millis() - lastDetectionTime > detectionCooldown) {
      motionDetected = true;
      lastDetectionTime = millis();
      println("Motion Detected! Motion pixel count: " + motionCount);

      updateTransitionColors();
      lastColor = transitionColors[transitionStep]; // Save the current color
    }
  }

  if (currentRGBFrame != null) {
    previousRGBFrame = currentRGBFrame.copy();
  }

  if (video.available()) {
    video.read();
    currentFrame = video.get();

    if (previousFrame != null) {
      PImage motionMask = motionDetected ? calculateMotionMask(currentFrame, previousFrame) : null;
      processedFrame = isolateTreeEdges(currentFrame, motionMask);
    } else {
      processedFrame = isolateTreeEdges(currentFrame, null);
    }

    if (currentFrame != null && processedFrame != null) {
      // Apply overlay only if motion was detected
      if (motionDetected) {
        overlayLeavesOnOriginalImage(currentFrame, processedFrame, lastColor);
        motionDetected = false; // Reset motion flag after applying new color
      } else if (lastColor != -1) { // Check for valid color
        overlayLeavesOnOriginalImage(currentFrame, processedFrame, lastColor);
      } else {
        image(currentFrame, 0, 0, width, height); // Display unaltered frame
      }
    }

    previousFrame = currentFrame.copy();
  } else {
    background(0);
  }
}

void overlayLeavesOnOriginalImage(PImage original, PImage edges, color overlayColor) {
  edges.loadPixels();
  original.loadPixels();

  for (int i = 0; i < edges.pixels.length; i++) {
    // Check if the edge pixel has any brightness (part of the mask)
    if (brightness(edges.pixels[i]) > 0) {
      original.pixels[i] = lerpColor(original.pixels[i], overlayColor, 0.8); // Blend color
    }
  }

  original.updatePixels();
  image(original, 0, 0, width, height);
}

void initializeTransitionColors() {
  color currentColor = fallColorsArray[currentImageIndex][currentColorIndex];
  color nextColor = fallColorsArray[currentImageIndex][nextColorIndex];

  transitionColors = new color[stepsBetweenColors];
  for (int i = 0; i < stepsBetweenColors; i++) {
    float t = map(i, 0, stepsBetweenColors - 1, 0, 1);
    transitionColors[i] = lerpColor(currentColor, nextColor, t);
  }
}

void updateTransitionColors() {
  currentColorIndex = nextColorIndex;
  nextColorIndex = (nextColorIndex + 1) % fallColorsArray[currentImageIndex].length;
  initializeTransitionColors();

  if (currentColorIndex == 0) {
    currentImageIndex = (currentImageIndex + 1) % fallColorsArray.length;
  }
}

PImage isolateTreeEdges(PImage img, PImage motionMask) {
  img.loadPixels();

  // Step 1: Create a mask for tree colors
  PImage mask = createImage(img.width, img.height, ALPHA);
  mask.loadPixels();

  // Define the split point for ground and sky
  float splitY = img.height / 1.6;

  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      color pixel = img.pixels[x + y * img.width];
      float r = red(pixel);
      float g = green(pixel);
      float b = blue(pixel);

      if (
        // Ground region logic
        (y < splitY && ((r > 100 && g > 50 && b < 80) || 
                        (g > 60 && g > r && g > b && g < 120))) ||
        // Sky region logic
        (y >= splitY && ((g > 60 && g > r && g > b && g < 120) || 
                         (g > r && g > b && g > 80))) ||
        // Target colors
        isColorInRange(r, g, b)
      ) {
        mask.pixels[x + y * img.width] = color(255); // Include in the mask
      } else {
        mask.pixels[x + y * img.width] = color(0); // Exclude from the mask
      }
    }
  }
  mask.updatePixels();

  // Combine with motion mask if available
  if (motionMask != null) {
    mask = applyMotionMask(mask, motionMask);
  }

  return removeOutliersByDistance(applyPerlinNoise(mask));
}


boolean isColorInRange(float r, float g, float b) {
  for (int[] target : targetColors) {
    if (abs(target[0] - r) <= colorTolerance &&
        abs(target[1] - g) <= colorTolerance &&
        abs(target[2] - b) <= colorTolerance) {
      return true;
    }
  }
  return false;
}

PImage applyMotionMask(PImage mask, PImage motionMask) {
  mask.loadPixels();
  motionMask.loadPixels();

  for (int i = 0; i < mask.pixels.length; i++) {
    if (brightness(motionMask.pixels[i]) > 0) {
      mask.pixels[i] = color(0); // Remove moving regions from the mask
    }
  }
  mask.updatePixels();
  return mask;
}

PImage removeOutliersByDistance(PImage mask) {
  PImage filteredMask = createImage(mask.width, mask.height, ALPHA);
  filteredMask.loadPixels();

  int treeCenterX = mask.width / 2;
  int treeCenterY = mask.height / 2;
  float maxDistanceX = mask.width / 2.5;
  float maxDistanceY = mask.height / 2.0;

  for (int y = 0; y < mask.height; y++) {
    for (int x = 0; x < mask.width; x++) {
      int index = x + y * mask.width;

      if (brightness(mask.pixels[index]) > 0) {
        float dx = abs(x - treeCenterX) / maxDistanceX;
        float dy = abs(y - treeCenterY) / maxDistanceY;

        if (dx * dx + dy * dy <= 1.0) {
          filteredMask.pixels[index] = mask.pixels[index];
        } else {
          filteredMask.pixels[index] = color(0); // Discard outliers
        }
      } else {
        filteredMask.pixels[index] = color(0);
      }
    }
  }
  filteredMask.updatePixels();
  return filteredMask;
}

PImage applyPerlinNoise(PImage mask) {
  mask.loadPixels();

  PImage smoothMask = createImage(mask.width, mask.height, ALPHA);
  smoothMask.loadPixels();

  for (int y = 0; y < mask.height; y++) {
    for (int x = 0; x < mask.width; x++) {
      float noiseValue = noise(x * noiseIncrement + noiseOffsetX, y * noiseIncrement + noiseOffsetY);
      int index = x + y * mask.width;

      if (brightness(mask.pixels[index]) > 0) {
        float alpha = map(noiseValue, 0.2, 0.8, 200, 255); // Add smooth transparency
        smoothMask.pixels[index] = color(255, alpha);
      } else {
        smoothMask.pixels[index] = color(0, 0);
      }
    }
  }
  smoothMask.updatePixels();
  return smoothMask;
}


PImage calculateMotionMask(PImage current, PImage previous) {
  current.loadPixels();
  previous.loadPixels();

  PImage motionMask = createImage(current.width, current.height, ALPHA);
  motionMask.loadPixels();

  for (int i = 0; i < current.pixels.length; i++) {
    float diffR = abs(red(current.pixels[i]) - red(previous.pixels[i]));
    float diffG = abs(green(current.pixels[i]) - green(previous.pixels[i]));
    float diffB = abs(blue(current.pixels[i]) - blue(previous.pixels[i]));

    if (diffR + diffG + diffB > motionThreshold) {
      motionMask.pixels[i] = color(255); // Mark as motion
    } else {
      motionMask.pixels[i] = color(0); // No motion
    }
  }
  motionMask.updatePixels();
  return motionMask;
}

void keyPressed() {
  if (showVideo) {
    video.pause();
  } else {
    video.play();
  }
  showVideo = !showVideo;
}
