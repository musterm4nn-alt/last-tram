# Character and appearance

The player creates their character in detail, and that look keeps changing as they live:
new clothes, a haircut, a scar from a bad night. The depth is inspired by *Degrees of
Lewdity*'s character creation and wardrobe (appearance, layered clothing, a background that
shapes your start, a look that changes with your life), **not** its sexual content. See
"Rules" below.

Everyone in town uses the same model. Residents generated in M2 get random appearances and
outfits from the same data.

## The character creator

New game → main menu → character creator → the town.

| Section | Choices | Since |
|---|---|---|
| Name | first name, last name, optional nickname | M1 |
| Identity | gender (woman / man / non-binary) and pronouns (she / he / they), chosen independently | M1 |
| Age | 18–80. Everyone in the game is an adult. | M1 |
| Body | height (150–205 cm), build (slim, average, athletic, stocky, heavy), skin tone | M1 |
| Face and hair | hair style, hair colour (natural and dyed), eye colour, facial hair, features (freckles, glasses, beauty mark) | M1 |
| Clothes | a starter outfit: one item per slot from the starter set, each in a colour you pick | M1 |
| Personality | your character's traits and personality axes (they steer free will and some outcomes) | M2 |
| Background | where your life starts (see below) | M3 |
| Attraction | who your character is attracted to (for romance) | M6 |

- **Randomise** buttons for each section and for everything.
- A live **preview** shows the top-down figure and a larger front-facing **portrait**
  ("paper doll") that updates with every choice. The same portrait is reused in the wardrobe
  and the person inspector.
- The first version (T-0020) is only a name screen; the full creator follows (T-0021).

## Identity and appearance (sim state)

Appearance is **saved sim state**, not view state: it's what the character looks like, and
people react to parts of it.

| Field | Values (ids from `data/appearance/appearance.json`) |
|---|---|
| `first_name`, `last_name`, `nickname` | letters, spaces, hyphens, apostrophes; 1–24 characters (nickname 0–16) |
| `gender`, `pronouns` | ids; pronoun sets carry subject/object/possessive/reflexive forms for generated text |
| `age_years` | 18–80 (validation never allows under 18) |
| `skin_tone`, `hair_colour`, `eye_colour` | colour option ids (each with a colour value) |
| `height_cm` | 150–205 |
| `build`, `hair_style`, `facial_hair` | option ids |
| `features` | a list of feature ids (freckles, glasses, beauty mark...) |

Later additions: hair **length** that grows (so haircuts matter), tan, **tattoos**,
**piercings**, **makeup**, **scars** from fights, and a build that shifts with fitness and
food.

## Clothes and outfits

- **Slots:** head, face, neck, top, outer, bottom, feet, hands, bag. One item per slot, or
  empty. **Top, bottom and feet are always worn** (validation), so there's no nudity.
- **Clothing items** (`data/clothing/items/*.json`): slot, style tags (casual, formal,
  sporty, street, workwear), allowed colours, price, **formality** (−2..+3),
  **concealment** (0..3), **warmth** (0..3, for weather later), and whether it's in the
  starter set.
- **M1:** pick a starter outfit in the creator.
- **M3:** buy clothes (a second-hand shop, a sports shop, a boutique), a **wardrobe** at home
  to change outfits, saved outfits ("work", "going out", "business"), clothes that get
  **dirty** (laundry at the Waschsalon), and a **barber** for cuts and colour.
- **M4:** clothes get damaged in fights. **Concealment** (hood up, cap, sunglasses,
  balaclava) makes witnesses less likely to identify you, and changing clothes after a crime
  helps you shake the police's description. A balaclava in broad daylight is itself
  suspicious.

## Presentation: how others see you

A derived value (not saved) from hygiene, the condition of your clothes, how well your
outfit's formality fits the place (a suit at the Kneipe, a hoodie at a job interview), and
grooming. It feeds first impressions in social interactions, job interviews, bouncers (later),
romance, and police suspicion.

## Backgrounds (M3)

Where your life starts. Each background sets starting money, skills, contacts and sometimes a
record. Numbers live in data and get tuned later.

| Background | Start |
|---|---|
| Newcomer | some savings, knows nobody, clean record |
| Local | grew up here: knows several residents, modest savings |
| Student | university, a cheap room in a shared flat (WG), little money, logic skill |
| Ex-con | just released: a criminal record, underworld contacts, almost no money |
| Burnout | quit a corporate job: savings, stress, office skills |

## Changing your look in-game (M3+)

- **Mirror** (at home): restyle hair within its current length, makeup, glasses.
- **Barber:** cut and colour (costs money).
- **Wardrobe:** change or save outfits. **Shops:** buy new clothes.
- **Tattoo studio and piercings** (later).

## Rules

- **Everyone is an adult.** The age minimum in data can't go below 18 (a content error), and
  a test checks that every person in a new game and every generated character is 18 or
  older. The code enforces it even if data were wrong: `Person.age_years` never stores less
  than 18 (so no spec, save or bug can lower it), random characters never get a younger
  age, and `CharacterSpec.validate()` rejects anything under 18.
- Customisation covers looks, clothes and life, **not sexual content**: there are no body-part
  sliders beyond height and build, and no nudity or exposure mechanics.
