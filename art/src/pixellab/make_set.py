"""PixelLab test: writes data/art2d/pixellab.json = route B's set plus the PixelLab pieces.
Run after build_pixellab.gd: python3 art/src/pixellab/make_set.py <wang.json from the build>."""
import json, sys

art = json.load(open("data/art2d/custom.json"))
wang = json.load(open(sys.argv[1]))["wang"]
art["name"] = "Route B + PixelLab test"
art["sheets"]["pl_terrain"] = "res://art/export/pixellab/terrain.png"
for base in ("base_a", "base_b", "base_c"):
    import os
    if os.path.exists("art/export/pixellab/%s.png" % base):
        art["sheets"]["pl_" + base] = "res://art/export/pixellab/%s.png" % base
        art["sheets"]["pl_" + base + "_mask"] = "res://art/export/pixellab/%s_mask.png" % base
for pair in wang:
    pair["sheet"] = "pl_terrain"
    for side, key in (("lower", "0000"), ("upper", "1111")):
        if pair[side] not in [p[side2] for p in wang[:wang.index(pair)] for side2 in ("lower", "upper")]:
            art["terrain"][pair[side]] = {"sheet": "pl_terrain", "cell": pair["tiles"][key], "variants": 1}
art["wang"] = wang
art["sheets"]["pl_objects"] = "res://art/export/pixellab/objects.png"
art["objects"]["bench"] = {"sheet": "pl_objects", "rect": [0, 0, 32, 24]}
art["people"] = {"bases": {b[3:]: [b, b + "_mask"] for b in art["sheets"] if b.startswith("pl_base_") and not b.endswith("_mask")},
                 "frame": [44, 44], "feet": [22, 38], "walk": 4, "idle": 4}
json.dump(art, open("data/art2d/pixellab.json", "w"), indent="\t")
print("wrote data/art2d/pixellab.json")

# The owner's pick (D35): route B's ground with PixelLab people and the bench.
b = json.load(open("data/art2d/custom.json"))
mix = dict(b)
mix["name"] = "Route B + PixelLab people and bench"
mix["sheets"] = dict(b["sheets"])
for key in art["sheets"]:
    if key.startswith("pl_base_") or key == "pl_objects":
        mix["sheets"][key] = art["sheets"][key]
mix["objects"] = dict(b["objects"])
mix["objects"]["bench"] = art["objects"]["bench"]
mix["people"] = art["people"]
json.dump(mix, open("data/art2d/pixellab_mix.json", "w"), indent="\t")
print("wrote data/art2d/pixellab_mix.json")
