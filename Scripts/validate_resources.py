#!/usr/bin/env python3
"""Validate native catalog coverage, schema integrity and the bilingual coach library."""
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
# --- Coach library -------------------------------------------------------------------------
LEVELS = ['optimistic', 'normal', 'savage', 'unhinged', 'toxic']
DAY_STATES = ['empty', 'low', 'steady', 'perfect', 'over', 'veryHigh', 'protein']
MEAL_STATES = ['goodFits', 'bigButFits', 'balancedSqueezes', 'unbalancedWithin', 'unbalancedOver', 'incomplete']
TAGS = {'riceChicken', 'chicken', 'bigPortion', 'bigSnack', 'noVeg', 'lowProtein', 'sugaryDrink', 'craving', 'buffet', 'evening', 'thirdSweet', 'repeatTreat', 'repeatOver', 'nightMale', 'nightFemale'}
DAY_TOKENS = {'kcal', 'target', 'over', 'left', 'protein', 'proteinTarget', 'proteinLeft'}
MEAL_TOKENS = {'meal', 'total', 'target', 'left', 'over', 'pct', 'protein'}
MAX_LENGTH = 125
LINES_PER_CELL = 8
# The coach never swears.
profanity = re.compile(r"amk|hassiktir|siktir|\bsik(ik|ti|e)\w*|orospu|\bpiç|\bbok\b|\bgöt\b|\bgötü\b|fuck|shit|damn|\bhell\b|\bass\b|bastard|crap|piss|\blan\b", re.I)
def value(key, lang):
    return catalog[key]['localizations'][lang]['stringUnit']['value']
coach_lines = 0
assert 'coach.title' in catalog
assert not [k for k in catalog if k.startswith(('coach.personality.', 'personality'))], 'characters were removed'
for kind, states, allowed in (('day', DAY_STATES, DAY_TOKENS), ('meal', MEAL_STATES, MEAL_TOKENS)):
    for state in states:
        seen = {'tr': {}, 'en': {}}
        prefix = f'coach.{kind}.{state}.'
        keys = [k for k in catalog if k.startswith(prefix)]
        for level in LEVELS:
            for i in range(LINES_PER_CELL):
                assert f'{prefix}{level}.{i}' in catalog, f'missing coach line {prefix}{level}.{i}'
        for key in keys:
            parts = key[len(prefix):].split('.')
            assert parts[0] in LEVELS, key
            if len(parts) == 2:
                assert parts[1] in {str(i) for i in range(LINES_PER_CELL)}, key
            else:
                assert kind == 'meal' and parts[1] in TAGS and parts[2] in {str(i) for i in range(LINES_PER_CELL)}, key
            coach_lines += 1
            for lang in ['tr', 'en']:
                text = value(key, lang)
                assert len(text) <= MAX_LENGTH, (key, lang, len(text))
                assert not profanity.search(text), (key, lang, text)
                found = set(re.findall(r'\{(\w+)\}', text))
                assert found <= allowed, (key, lang, found)
                assert not re.search(r'\d', re.sub(r'\{\w+\}', '', text)), f'hard-coded number in {key}: {text}'
                assert text not in seen[lang], f'duplicate in {state}: {key} and {seen[lang][text]}'
                seen[lang][text] = key
for state in MEAL_STATES:
    for suffix in ['title', 'note']:
        assert f'reaction.{suffix}.{state}' in catalog, state
assert 'reaction.detail.left' in catalog and 'reaction.detail.over' in catalog
# Product boundary: coach messages mock behaviour and character, never body, weight or looks.
banned = re.compile(r'şişman|göbek|obez|kilolu|tombul|çirkin|domuz|balina|obese|chubby|ugly|flab|belly|\bpig\b|lardy|\bwhale', re.I)
absolutes = re.compile(r'asla çekici|kimse sana bakmaz|sevilmeye|değersiz|never attractive|nobody will (look|love)|unlovable|worthless', re.I)
# Coach copy keeps the numbers in the background and the hard levels free of consolation tails.
planning = re.compile(r'günlük plan|kalori bütçe|disiplin yolculuğu|daily plan|calorie budget|discipline journey', re.I)
consolation = re.compile(r'telafi|dert etme|sorun değil|moralini bozma|aç kalma|make up for it|don.t worry|no big deal|cheer up', re.I)
for key, entry in catalog.items():
    if key.startswith(('coach.day.', 'coach.meal.')):
        for lang in ['tr', 'en']:
            text = entry['localizations'][lang]['stringUnit']['value']
            assert not planning.search(text), (key, lang, text)
            if re.search(r'\.(savage|unhinged|toxic)\.', key):
                assert not consolation.search(text), (key, lang, text)
    if key.startswith(('coach.day.', 'coach.meal.', 'reaction.', 'notif.')):
        for lang in ['tr', 'en']:
            text = entry['localizations'][lang]['stringUnit']['value']
            assert not banned.search(text), (key, lang)
            # Never a verdict on someone's worth or looks, never a push to skip food.
            assert not absolutes.search(text), (key, lang)
            if re.search(r'aç kal|go hungry|starv', text, re.I):
                assert re.search(r'kalma|kalarak|kalınca|çalışma|etme|yok|değil|don.t|no |not |isn.t|never|nothing|without', text, re.I), (key, lang, text)
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
for kind in ['breakfast', 'lunch', 'dinner', 'emptyNoon', 'emptyEvening']:
    for mode in ['optimistic', 'normal', 'savage', 'unhinged', 'toxic']:
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
# Onboarding keys are built dynamically in Swift, so check every combination here.
onboarding_keys = [f'ob.{kind}.{step}' for kind in ['title', 'sub'] for step in ['goal', 'about', 'body', 'lifestyle', 'workouts', 'habits', 'safety', 'result']]
onboarding_keys += [f'{p}.{g}' for g in ['lose', 'muscle', 'gain', 'maintain'] for p in ['goal', 'ob.goal', 'coach.weight']]
onboarding_keys += [f'ob.life.{k}{s}' for k in ['sitting', 'onFeet', 'physical'] for s in ['', '.sub']]
onboarding_keys += [f'ob.workouts.{k}{s}' for k in ['none', 'light', 'regular', 'intense'] for s in ['', '.sub']]
onboarding_keys += [f'{p}.{k}' for k in ['sweets', 'nightSnacking', 'portions', 'eatingOut', 'irregular', 'lowAppetite', 'noIdea', 'notSure'] for p in ['ob.challenge', 'ob.tip']]
onboarding_keys += ['ob.tip.maintain', 'ob.calculate', 'ob.loading.title'] + [f'ob.loading.{i}' for i in range(1, 5)]
for key in onboarding_keys:
    assert key in catalog, key
print(f'PASS: {len(catalog)} bilingual strings, {coach_lines} coach lines per language, {len(foods)} foods.')

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
