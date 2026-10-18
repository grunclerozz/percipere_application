/// How the offline description groups ML Kit's image labels, so the spoken
/// sentence lists related things together and doesn't repeat itself.
/// Keys are lowercase English labels (the same keys as `imageLabelsFil`);
/// labels not listed are [LabelGroup.other].
enum LabelGroup {
  /// People and body parts.
  people,

  /// Animals.
  animals,

  /// Food and drink.
  food,

  /// Plates, cups and cutlery.
  tableware,

  /// Furniture and the home.
  home,

  /// Clothes and things worn or carried.
  clothing,

  /// Plants, landscape, places and weather.
  nature,

  /// Cars, boats and other vehicles.
  vehicles,

  /// Books, gadgets and other objects.
  objects,

  /// Medicine and money (these add a reminder).
  healthMoney,

  /// Anything else.
  other,
}

/// The labels of each group. The groups are spoken in the order of
/// [LabelGroup.values].
const Map<LabelGroup, Set<String>> imageLabelGroups = {
  LabelGroup.people: {
    'person', 'people', 'face', 'head', 'hair', 'smile', 'hand', 'finger', //
    'arm', 'leg', 'foot', 'child', 'baby', 'toddler', 'man', 'woman', //
    'crowd', 'team', 'selfie', 'eye', 'skin', 'beard',
  },
  LabelGroup.animals: {
    'animal', 'dog', 'cat', 'bird', 'pet', 'horse', 'cow', 'pig', 'goat', //
    'carabao', 'duck', 'rabbit', 'insect', 'butterfly', 'mouse',
  },
  LabelGroup.food: {
    'food', 'dish', 'cuisine', 'meal', 'fruit', 'vegetable', 'meat', 'rice', //
    'bread', 'cake', 'egg', 'fish', 'seafood', 'soup', 'salad', 'snack', //
    'dessert', 'drink', 'beverage', 'coffee', 'tea', 'juice', 'water', //
    'banana', 'mango', 'apple', 'orange', 'coconut', 'tomato', 'onion', //
    'potato', 'carrot', 'pizza', 'noodle', 'chicken',
  },
  LabelGroup.tableware: {
    'plate', 'tableware', 'dishware', 'bowl', 'cup', 'mug', 'glass', //
    'bottle', 'spoon', 'fork', 'knife', 'kitchen', 'cookware and bakeware',
  },
  LabelGroup.home: {
    'table', 'furniture', 'chair', 'desk', 'bed', 'sofa', 'couch', 'shelf', //
    'door', 'window', 'room', 'house', 'home', 'building', 'roof', 'floor', //
    'wall', 'lamp', 'clock', 'mirror', 'curtain', 'pillow', 'carpet', //
    'television',
  },
  LabelGroup.clothing: {
    'clothing', 'shirt', 'dress', 'pants', 'jeans', 'shoe', 'footwear', //
    'hat', 'cap', 'bag', 'backpack', 'glasses', 'sunglasses', 'jewellery', //
    'jewelry', 'umbrella',
  },
  LabelGroup.nature: {
    'plant', 'flower', 'tree', 'leaf', 'grass', 'garden', 'sky', 'cloud', //
    'sun', 'sunset', 'sea', 'ocean', 'beach', 'river', 'lake', 'mountain', //
    'hill', 'forest', 'field', 'rock', 'sand', 'snow', 'road', 'street', //
    'bridge', 'city', 'church', 'tower',
  },
  LabelGroup.vehicles: {
    'car', 'vehicle', 'bus', 'truck', 'motorcycle', 'bicycle', 'tricycle', //
    'boat', 'ship', 'airplane', 'wheel', 'tire',
  },
  LabelGroup.objects: {
    'book', 'paper', 'text', 'font', 'document', 'newspaper', 'pen', //
    'pencil', 'box', 'package', 'toy', 'ball', 'phone', 'mobile phone', //
    'gadget', 'computer', 'laptop', 'camera', 'key', 'tool', 'electronics', //
    'screen', 'sign', 'flag', 'candle', 'fire', 'smoke', //
    'musical instrument', 'guitar',
  },
  LabelGroup.healthMoney: {
    'medicine', 'pill', 'drug', 'capsule', 'syringe', 'bandage', 'money', //
    'cash', 'currency', 'banknote', 'coin', 'wallet', 'tablet', //
    'prescription', 'vitamin',
  },
};

/// Broad labels that add nothing when a more specific label of the same
/// group is also there ("food" next to "rice"; "tableware" next to
/// "plate"). They are dropped then, and kept when they stand alone.
const Set<String> genericImageLabels = {
  'food', 'cuisine', 'meal', 'dish', 'drink', 'beverage', 'seafood', //
  'tableware', 'dishware', 'kitchen', 'cookware and bakeware', //
  'furniture', 'room', 'building', 'home', 'house', //
  'clothing', 'footwear', 'electronics', 'gadget', 'musical instrument', //
  'vehicle', 'animal', 'pet', 'plant', 'people', 'crowd', 'team', //
  'text', 'font', 'paper', 'tool', 'package',
};

/// The group of [label] (any capitalization).
LabelGroup labelGroupOf(String label) {
  final key = label.trim().toLowerCase();
  for (final entry in imageLabelGroups.entries) {
    if (entry.value.contains(key)) return entry.key;
  }
  return LabelGroup.other;
}
