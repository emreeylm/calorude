# Food catalog update — 7 September 2026

The original 33 records remain starter estimates. New branded drinks use the listed manufacturer values per 100 ml, retrieved 7 September 2026. Packaging takes precedence when formulations change. Generic prepared meals are approximate calculations from the listed ingredients and assumed final cooked yields, not laboratory measurements or universal recipes. The app displays an estimate notice.

TürKomp, Ulusal Gıda Kompozisyon Veri Tabanı, versiyon 1.0, https://turkomp.tarimorman.gov.tr/ — tomato and cucumber averages per edible 100 g.

Legacy Swift/JSON nutrient fields retain their `Per100g` names for backwards compatibility; the explicit `amountUnit` determines whether the denominator is 100 g or 100 ml. Existing cola and ayran numeric amounts/totals are preserved; their previously mislabeled volume entries now display ml. There is no general grams-to-ml conversion.

## Sources

- `tomato`: https://turkomp.tarimorman.gov.tr/food-domates-sofralik-168
- `cucumber`: https://turkomp.tarimorman.gov.tr/food-salatalik-203
- `milk`: https://www.icim.com.tr/urunler/sut/organik/
- `lactosefree`: https://www.icim.com.tr/urunler/sut/laktozsuz-sut/
- `kefir`: https://www.pinar.com.tr/urunler/detay-sut/Kefir/3642/4906/0
- `strawberrykefir`: https://www.pinar.com.tr/urunler/detay-sut/Kefir/3642/4906/0
- `orangejuice`: https://www.dimes.com.tr/dimes-100/dimes-100-portakal-suyu
- `applejuice`: https://www.dimes.com.tr/dimes-100/dimes-100-elma-suyu
- `fanta`: https://www.coca-cola.com/tr/tr/brands/fanta
- `sprite`: https://www.coca-cola.com/tr/tr/brands/sprite
- `spritezero`: https://www.coca-cola.com/tr/tr/brands/sprite
- `water`: Plain unsweetened water; no energy-bearing ingredients.
- `mineralwater`: Plain unsweetened mineral water; no energy-bearing ingredients.
- `blackcoffee`: USDA FDC 171890, brewed coffee; approximate density 1 g/ml for this water-based drink only: https://fdc.nal.usda.gov/food-details/171890/nutrients

## Recipe estimates

Ingredient amounts use grams for foods and ml for drinks; final yields use the indicated unit. Final yields include assumed cooking water loss or addition. Existing starter values propagate their uncertainty.

```json
{
  "omelette": {
    "ingredients": {
      "egg": 100,
      "oliveoil": 5
    },
    "finalYield": 100,
    "unit": "g"
  },
  "cheeseomelette": {
    "ingredients": {
      "egg": 100,
      "feta": 30,
      "oliveoil": 5
    },
    "finalYield": 130,
    "unit": "g"
  },
  "menemen": {
    "ingredients": {
      "egg": 100,
      "tomato": 200,
      "oliveoil": 10
    },
    "finalYield": 270,
    "unit": "g"
  },
  "cheesetoast": {
    "ingredients": {
      "bread": 80,
      "kasar": 40
    },
    "finalYield": 115,
    "unit": "g"
  },
  "chickensandwich": {
    "ingredients": {
      "bread": 80,
      "chicken": 100,
      "tomato": 40
    },
    "finalYield": 220,
    "unit": "g"
  },
  "cheesesandwich": {
    "ingredients": {
      "bread": 80,
      "feta": 40,
      "tomato": 40,
      "cucumber": 30
    },
    "finalYield": 190,
    "unit": "g"
  },
  "chickenrice": {
    "ingredients": {
      "rice": 180,
      "chicken": 100
    },
    "finalYield": 280,
    "unit": "g"
  },
  "chickpearice": {
    "ingredients": {
      "rice": 180,
      "chickpea": 80
    },
    "finalYield": 260,
    "unit": "g"
  },
  "chickensote": {
    "ingredients": {
      "chicken": 150,
      "tomato": 100,
      "oliveoil": 8
    },
    "finalYield": 240,
    "unit": "g"
  },
  "beefsote": {
    "ingredients": {
      "beef": 150,
      "tomato": 100,
      "oliveoil": 5
    },
    "finalYield": 240,
    "unit": "g"
  },
  "meatbeans": {
    "ingredients": {
      "beans": 180,
      "beef": 60
    },
    "finalYield": 240,
    "unit": "g"
  },
  "tomatopasta": {
    "ingredients": {
      "pasta": 200,
      "tomato": 100,
      "oliveoil": 8
    },
    "finalYield": 280,
    "unit": "g"
  },
  "yogurtpasta": {
    "ingredients": {
      "pasta": 200,
      "yogurt": 100
    },
    "finalYield": 300,
    "unit": "g"
  },
  "cheesepasta": {
    "ingredients": {
      "pasta": 200,
      "feta": 40,
      "oliveoil": 5
    },
    "finalYield": 245,
    "unit": "g"
  },
  "cacik": {
    "ingredients": {
      "yogurt": 200,
      "cucumber": 100,
      "water": 100
    },
    "finalYield": 400,
    "unit": "g"
  },
  "tomatocucumbersalad": {
    "ingredients": {
      "tomato": 150,
      "cucumber": 100,
      "oliveoil": 10
    },
    "finalYield": 260,
    "unit": "g"
  },
  "chickensalad": {
    "ingredients": {
      "chicken": 100,
      "tomato": 100,
      "cucumber": 100,
      "oliveoil": 5
    },
    "finalYield": 305,
    "unit": "g"
  },
  "potatoyogurt": {
    "ingredients": {
      "potato": 200,
      "yogurt": 100,
      "oliveoil": 5
    },
    "finalYield": 305,
    "unit": "g"
  },
  "bananaoatbowl": {
    "ingredients": {
      "oats": 40,
      "yogurt": 150,
      "banana": 100
    },
    "finalYield": 290,
    "unit": "g"
  },
  "latte": {
    "ingredients": {
      "milk": 150,
      "blackcoffee": 50
    },
    "finalYield": 200,
    "unit": "ml"
  }
}
```

## 100-entry catalog

The latest curated list contains exactly 80 foods/meals and 20 drinks. Selection targets practical Turkish fitness/diet tracking, including occasional takeaway and snacks; it is not an empirically ranked top-100 consumption survey. TÜBER informs broad food-group coverage, not a popularity claim: https://hsgm.saglik.gov.tr/depo/birimler/saglikli-beslenme-ve-hareketli-hayat-db/Dokumanlar/Rehberler/Turkiye_Beslenme_Rehber_TUBER_2022_min.pdf

New basic-food values come from USDA SR28, revised May 2016. Official source and schema: https://www.ars.usda.gov/northeast-area/beltsville-md-bhnrc/beltsville-human-nutrition-research-center/methods-and-application-of-food-composition-laboratory/mafcl-site-pages/sr11-sr28/ . Download: https://www.ars.usda.gov/ARSUserFiles/80400525/Data/SR/SR28/dnload/sr28abbr.zip . Extracted fields are energy, protein, carbohydrate-by-difference and total lipid per edible 100 g. NDB IDs and original descriptions are in CATALOG100_SOURCES.json. These are generic references, not current branded-product labels.

Plain black/green tea uses an explicit approximate density of 1 g/ml. Prepared Turkish coffee is a rounded estimate excluding settled grounds, not the powder's per-100-g label. New protein milk and zero cola use manufacturer values per 100 ml. The full review list is FOOD_CATALOG_100.md. Existing IDs, diary records and saved-meal snapshots are retained.

## Preparation and portion update

The latest catalog contains 88 foods/meals and 20 drinks (108 total), retaining all earlier IDs and adding eight requested coverage options. Preparation variants and the new entries are documented in PREPARATION_SOURCES.json. USDA NDB identifiers refer to the same SR28 data source above. Default historical nutrient values were retained. Generic beef cuts, pilaf recipes and preparation yields remain estimates. Raw/dry numbers describe food weighed before cooking, not a recommendation to consume raw food. Switching preparation does not convert the amount entered between states.

Anchovy cooked values use a no-added-oil preparation estimate: raw NDB 15001 nutrients divided by an assumed 0.8 cooked weight yield, with no modeled nutrient loss. Meatballs use cooked ingredient equivalents and an explicitly assumed 100 g final yield; neither is a measured universal recipe. A package label or measured recipe takes precedence.

Named portions are approximate editable-entry aids, not density conversions: egg 50 g, egg white 33 g, bread/cheese slice 30 g, bowl soup 250 g, bowl yogurt 200 g, water glass 200 ml, tea glass 100 ml, Turkish coffee cup 60 ml, oil tablespoon 10 g, other spreads tablespoon 15 g, handful nuts 30 g. Generic serving amounts use each food's existing servingAmount. Unsupported raw/dry household measures are hidden. User-entered quantities convert to a canonical gram/ml amount, so subsequent editing remains possible even when opened in gram/ml mode.
