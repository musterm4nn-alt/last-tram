class_name ClothingDef
extends RefCounted
## One wearable item (a t-shirt, a parka...). Defined in data/clothing/items/*.json.

## Slots an item can be worn in.
const SLOTS: PackedStringArray = ["head", "face", "neck", "top", "outer", "bottom", "feet", "hands", "bag"]
## Slots a person always wears something in (the game has no nudity).
const REQUIRED_SLOTS: PackedStringArray = ["top", "bottom", "feet"]

var id: String = ""
var name: String = ""
## One of SLOTS.
var slot: String = ""
## Style tags: "casual", "formal", "sporty", "street", "workwear".
var styles: PackedStringArray = PackedStringArray()
## Colour ids from data/clothing/colours.json.
var colours: PackedStringArray = PackedStringArray()
## Price in euro cents.
var price: int = 0
## -2 (very casual) .. 3 (very formal).
var formality: int = 0
## 0..3: how much of the body the item covers.
var concealment: int = 0
## 0..3: how warm the item is.
var warmth: int = 0
## Offered in the character creator's starting wardrobe.
var starter: bool = false
