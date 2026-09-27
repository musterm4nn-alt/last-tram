class_name ColorOption
extends RefCounted
## A named colour the character creator offers (skin tone, hair or eye colour).
## Defined in data/appearance/appearance.json and data/clothing/colours.json.

var id: String = ""
var name: String = ""
var color: Color = Color.MAGENTA
## False for dyed hair colours (pink, blue...) that do not grow naturally.
var natural: bool = true
