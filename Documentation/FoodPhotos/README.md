# Food catalog photography

The bundled catalog uses one distinct AI-generated representative photograph per food ID (88 foods and 20 drinks). Images are generated with the built-in image generation tool. Each adjacent `<food-id>.json` records its prompt and original output path. Original PNGs remain in the generated-images directory; the app uses only the optimized copies.

Assets: `Calorude/Resources/Assets.xcassets/food-<id>.imageset/photo.jpg`. Each is a 256 × 256 JPEG, optimized using macOS `sips` at quality 80. Asset-catalog images load offline in food selection, draft entries and portion detail. Custom foods without a matching asset show a neutral food/drink symbol.

Photos illustrate food identity; they do not depict an exact logged weight, recipe or preparation selection. Raw/cooked selection continues to control nutrition independently. Branded drinks use representative unpackaged beverages, not manufacturer product photography. No runtime image service or network request is required.

Validation: `Scripts/validate_resources.py` checks complete catalog coverage, JPEG size limits and distinct file hashes; `CoreTests.testEveryCatalogFoodHasBundledPhoto` checks every image loads from the application bundle at 256 × 256 pixels.
