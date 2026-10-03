"""PixelLab test: writes data/art2d/pixellab.json = route B's set plus the PixelLab pieces.
Run after build_pixellab.gd: python3 art/src/pixellab/make_set.py <wang.json from the build>."""
import json, sys

art = json.load(open("data/art2d/custom.json"))
wang = json.load(open(sys.argv[1]))["wang"]
art["name"] = "Route B + PixelLab test"
art["sheets"]["pl_terrain"] = "res://art/export/pixellab/terrain.png"
art["sheets"]["pl_people"] = "res://art/export/pixellab/resident.png"
for pair in wang:
    pair["sheet"] = "pl_terrain"
    for side, key in (("lower", "0000"), ("upper", "1111")):
        if pair[side] not in [p[side2] for p in wang[:wang.index(pair)] for side2 in ("lower", "upper")]:
            art["terrain"][pair[side]] = {"sheet": "pl_terrain", "cell": pair["tiles"][key], "variants": 1}
art["wang"] = wang
art["sheets"]["pl_objects"] = "res://art/export/pixellab/objects.png"
art["objects"]["bench"] = {"sheet": "pl_objects", "rect": [0, 0, 32, 24]}
art["people"] = {"sheet": "pl_people", "frame": [44, 44], "feet": [22, 38], "walk": 4, "idle": 4}
json.dump(art, open("data/art2d/pixellab.json", "w"), indent="\t")
print("wrote data/art2d/pixellab.json")
