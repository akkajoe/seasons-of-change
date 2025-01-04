import os
import numpy as np
from sklearn.cluster import KMeans
from PIL import Image
import json

# Folder containing the images
image_folder = "colors"  # Replace with your folder path
num_clusters = 2  # Number of clusters per image
results = []  # Store results for all images

# Load each image, process, and find the dominant colors
for file_name in os.listdir(image_folder):
    if file_name.lower().endswith(".jpeg") or file_name.lower().endswith(".jpg"):
        print(f"Processing file: {file_name}")  # Debugging print
        image_path = os.path.join(image_folder, file_name)
        with Image.open(image_path) as img:
            img = img.convert("RGB")  # Convert image to RGB
            pixels = np.array(img).reshape(-1, 3)  # Flatten image into RGB pixel data
            
            # Run KMeans clustering to determine the top colors
            kmeans = KMeans(n_clusters=num_clusters, random_state=42)
            kmeans.fit(pixels)
            
            # Get the cluster centers (dominant colors)
            cluster_centers = kmeans.cluster_centers_.astype(int)
            
            # Prepare the list of colors
            dominant_colors = [
                {"R": int(center[0]), "G": int(center[1]), "B": int(center[2])}
                for center in cluster_centers
            ]
            
            # Add result to the list with the image file name
            results.append({
                "image": file_name,
                "dominant_colors": dominant_colors  # List of all cluster centers
            })

# Save results to JSON file
json_path = "fall_colors_by_image.json"
with open(json_path, "w") as json_file:
    json.dump(results, json_file, indent=4)

print(f"Colors exported to JSON: {json_path}")
