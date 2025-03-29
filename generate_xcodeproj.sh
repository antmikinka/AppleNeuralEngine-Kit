#!/bin/bash

# Generate Xcode project for AppleNeuralEngine-Kit
echo "Generating Xcode project for AppleNeuralEngine-Kit..."

# Make sure script is executable
chmod +x $0

# Create an Assets.xcassets directory if it doesn't exist
mkdir -p Assets.xcassets/AppIcon.appiconset

# Create a basic Contents.json for the App Icon
cat > Assets.xcassets/AppIcon.appiconset/Contents.json << EOL
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOL

# Create Contents.json for Assets.xcassets
cat > Assets.xcassets/Contents.json << EOL
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOL

# Generate the Xcode project from the Swift package using Xcode
echo "Opening Package.swift in Xcode..."
open Package.swift

# Apply modifications to the generated project
xcodeproj="AppleNeuralEngine-Kit.xcodeproj"

if [ -d "$xcodeproj" ]; then
    echo "Xcode project generated successfully."
    echo "Opening Xcode project..."
    open "$xcodeproj"
else
    echo "Project generation failed. Please check for errors and try again."
fi

echo "Done."