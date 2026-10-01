#!/usr/bin/env python3
"""Validate native catalog coverage, schema integrity and bilingual roast uniqueness."""
import json, pathlib, re
root = pathlib.Path(__file__).resolve().parents[1] / 'Calorude'
catalog = json.loads((root / 'Localization/Localizable.xcstrings').read_text())['strings']
assert set(catalog['brand.name']['localizations']) == {'tr', 'en'}
for key, entry in catalog.items():
    assert set(entry['localizations']) == {'tr', 'en'}, key
    for lang in ['tr', 'en']:
        assert entry['localizations'][lang]['stringUnit']['value'].strip(), (key, lang)
for file in root.rglob('*.swift'):
    for key in re.findall(r'l\.text\("([^"\\]+)"\)', file.read_text()):
        assert key in catalog, (file, key)
roasts = json.loads((root / 'Resources/roasts.json').read_text())
assert len(roasts) >= 100
assert len({r['id'] for r in roasts}) == len(roasts)
for lang in ['tr', 'en']:
    assert len({catalog[r['messageKey']]['localizations'][lang]['stringUnit']['value'] for r in roasts}) == len(roasts)
for rule in {r['rule'] for r in roasts}:
    for intensity in ['optimistic', 'normal', 'savage', 'unhinged', 'nuclear']:
        assert any(r['rule'] == rule and r['intensity'] == intensity for r in roasts)
    assert sum(r['rule'] == rule and r['intensity'] == 'normal' and not r['pro'] for r in roasts) >= 3
assert all(r['pro'] == (r['intensity'] != 'normal') for r in roasts), 'only normal is free'
# Product boundary: coach messages mock behaviour and character, never body, weight or looks.
banned = re.compile(r'şişman|göbek|obez|kilolu|tombul|çirkin|domuz|balina|obese|chubby|ugly|flab|belly|\bpig\b|lardy|\bwhale', re.I)
for key, entry in catalog.items():
    if key.startswith(('roast.', 'reaction.', 'notif.')):
        for lang in ['tr', 'en']:
            assert not banned.search(entry['localizations'][lang]['stringUnit']['value']), (key, lang)
foods = json.loads((root / 'Resources/foods.json').read_text())
assert len(foods) == 108, 'Expanded catalog must contain 108 entries'
assert sum(f['amountUnit'] == 'g' for f in foods) == 88
assert sum(f['amountUnit'] == 'ml' for f in foods) == 20
assert len({f['id'] for f in foods}) == len(foods)
for lang in ['TR', 'EN']:
    assert len({f['localizedName' + lang].casefold() for f in foods}) == len(foods)
for food in foods:
    assert 'category.' + food['category'] in catalog
    for portion in food.get('portions', []):
        assert portion['amount'] > 0
        assert portion['titleKey'] in catalog
    for variant in food.get('preparations', []):
        assert variant['titleKey'] in catalog
        assert all(variant[k] >= 0 for k in ['calories', 'protein', 'carbs', 'fat'])
    if food.get('preparations'):
        assert food['selectedPreparation'] in [v['id'] for v in food['preparations']]
    assert food['servingAmount'] > 0
    assert food['amountUnit'] in ['g', 'ml']
    assert food['localizedNameTR'] and food['localizedNameEN']
    assert all(food[key] >= 0 for key in ['caloriesPer100g', 'proteinPer100g', 'carbsPer100g', 'fatPer100g'])
for key, entry in catalog.items():
    if key.startswith(('roast.', 'reaction.')):
        for lang in ['tr', 'en']:
            found = set(re.findall(r'\{(\w+)\}', entry['localizations'][lang]['stringUnit']['value']))
            assert found <= {'kcal', 'target', 'over', 'left', 'protein', 'proteinTarget', 'proteinLeft', 'streak', 'days', 'weekDays', 'trend', 'carbs', 'fat'}, (key, lang, found)
for kind in ['breakfast', 'lunch', 'dinner', 'emptyNoon', 'emptyEvening']:
    for mode in ['optimistic', 'normal', 'savage', 'unhinged', 'nuclear']:
        for i in range(3):
            entry = catalog[f'notif.{kind}.{mode}.{i}']['localizations']
            for lang in ['tr', 'en']:
                assert '{' not in entry[lang]['stringUnit']['value'], (kind, mode, i, lang)
# Notifications speak in the coach's voice; they never tell the user to log a meal.
cta = re.compile(r'\b(gir|girin|girmeyi|girmeye|girmen|kaydet|kaydedip|kaydı|kayıt|yaz|yazmaya|yazmadın)\b|\blog(ged|ging|s)?\b|\bentry\b|\bentries\b', re.I)
for key, entry in catalog.items():
    if key.startswith('notif.'):
        for lang in ['tr', 'en']:
            assert not cta.search(entry['localizations'][lang]['stringUnit']['value']), (key, lang)
print(f'PASS: {len(catalog)} bilingual strings, {len(roasts)} unique roasts per language, {len(foods)} foods.')

# Every bundled food has its own offline thumbnail.
import hashlib
photo_hashes = set()
photo_bytes = 0
for food in foods:
    folder = root / 'Resources/Assets.xcassets' / ('food-' + food['id'] + '.imageset')
    asset = json.loads((folder / 'Contents.json').read_text())
    image = folder / asset['images'][0]['filename']
    data = image.read_bytes()
    assert data.startswith(bytes.fromhex('ffd8')), image
    assert 1000 < len(data) < 100000, image
    photo_hashes.add(hashlib.sha256(data).hexdigest())
    photo_bytes += len(data)
assert len(photo_hashes) == len(foods), 'Each food must have a distinct photo'
print(f'PASS: {len(photo_hashes)} unique bundled food photos, {photo_bytes / 1024 / 1024:.2f} MiB total.')
