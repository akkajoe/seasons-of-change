# Seasons of Change

Seasons of Change is an interactive installation that uses a Kinect sensor to detect motion and overlay seasonal colors onto a video in real-time. This project leverages the KinectPV2 library and Processing to create an immersive and dynamic visual experience.

## Table of Contents

- [Installation and Setup](#installation-and-setup)
- [Prerequisites](#prerequisites)
- [Libraries](#libraries)
- [Directory Structure](#directory-structure)
- [JSON Format](#json-format)
- [Running the Project](#running-the-project)
- [Code Overview](#code-overview)
  - [Setup](#setup)
  - [Draw](#draw)
  - [Key Components](#key-components)
    - [Motion Detection](#motion-detection)
    - [Color Transition](#color-transition)
    - [Overlaying Colors](#overlaying-colors)
- [Controls](#controls)
- [Future Improvements](#future-improvements)
- [License](#license)

## Installation and Setup

### Prerequisites

- [Processing](https://processing.org/download/)
- Kinect for Windows SDK
- KinectPV2 library for Processing
- Processing Video library

### Libraries

Ensure you have the following libraries installed in Processing:

1. [KinectPV2](https://github.com/ThomasLengeling/KinectPV2)
2. Processing Video Library

### Directory Structure

```
Project Root
│
├── MVI_7956.MP4 (Video file)
├── fall_colors_by_image.json (JSON file with fall colors)
├── sketch.pde (Your Processing sketch)
└── ...
```

### JSON Format

The `fall_colors_by_image.json` should follow this structure:

```json
[
  {
    "dominant_colors": [
      {"R": 123, "G": 45, "B": 67},
      {"R": 89, "G": 23, "B": 45}
    ]
  }
]
```

## Running the Project

1. Load the sketch in Processing.
2. Ensure your Kinect sensor is connected.
3. Click the `Run` button in Processing to start the sketch.

## Code Overview

### Setup

The `setup()` function initializes the Kinect sensor, sets up the video, and loads the fall colors from a JSON file. It also prepares the motion detection frames and initializes the transition colors.

```java
void setup() {
  fullScreen();
  kinect = new KinectPV2(this);
  kinect.enableColorImg(true);
  kinect.init();

  currentRGBFrame = createImage(1920, 1080, RGB);
  motionFrame = createImage(1920, 1080, ARGB);
  initializeMotionFrame();

  video = new Movie(this, "path/to/your/video.mp4");
  video.loop();

  loadFallColors();
  initializeTransitionColors();
}
```

### Draw

The `draw()` function captures the current frame from the Kinect sensor, detects motion, applies color transitions, and overlays colors on the video based on detected motion.

```java
void draw() {
  currentRGBFrame = kinect.getColorImage();

  if (currentRGBFrame != null && previousRGBFrame != null) {
    detectMotion();
    updatePreviousRGBFrame();
  }

  if (video.available()) {
    video.read();
    currentFrame = video.get();
    processCurrentFrame();
  } else {
    background(0);
  }
}
```

### Key Components

#### Motion Detection

Motion is detected by comparing the current frame with the previous frame from the Kinect sensor. If significant motion is detected, a flag is set, and colors are transitioned.

```java
void detectMotion() {
  motionFrame.loadPixels();
  currentRGBFrame.loadPixels();
  previousRGBFrame.loadPixels();

  int motionCount = 0;

  for (int i = 0; i < currentRGBFrame.pixels.length; i++) {
    float diff = calculateDifference(currentRGBFrame.pixels[i], previousRGBFrame.pixels[i]);

    if (diff > 100) {
      motionFrame.pixels[i] = color(255, 0, 0, 255);
      motionCount++;
    } else {
      motionFrame.pixels[i] = color(0, 0, 0, 0);
    }
  }
  motionFrame.updatePixels();

  if (motionCount > 5000 && millis() - lastDetectionTime > detectionCooldown) {
    motionDetected = true;
    lastDetectionTime = millis();
    updateTransitionColors();
    lastColor = transitionColors[transitionStep];
  }
}
```

#### Color Transition

Colors transition smoothly between predefined sets of colors loaded from a JSON file. This is handled by computing intermediate colors for a smooth blend.

```java
void initializeTransitionColors() {
  color currentColor = fallColorsArray[currentImageIndex][currentColorIndex];
  color nextColor = fallColorsArray[currentImageIndex][nextColorIndex];

  transitionColors = new color[stepsBetweenColors];
  for (int i = 0; i < stepsBetweenColors; i++) {
    float t = map(i, 0, stepsBetweenColors - 1, 0, 1);
    transitionColors[i] = lerpColor(currentColor, nextColor, t);
  }
}
```

#### Overlaying Colors

Colors are overlaid on the video based on the detected edges and motion. The overlay is blended with the original video frame.

```java
void overlayLeavesOnOriginalImage(PImage original, PImage edges, color overlayColor) {
  edges.loadPixels();
  original.loadPixels();

  for (int i = 0; i < edges.pixels.length; i++) {
    if (brightness(edges.pixels[i]) > 0) {
      original.pixels[i] = lerpColor(original.pixels[i], overlayColor, 0.8);
    }
  }

  original.updatePixels();
  image(original, 0, 0, width, height);
}
```

## Controls

- **Spacebar**: Pause/resume the video.

## Future Improvements

- Enhance motion detection accuracy.
- Add more color transition effects.
- Optimize performance for real-time processing.
