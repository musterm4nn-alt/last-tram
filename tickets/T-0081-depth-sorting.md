---
id: T-0081
title: Objects and people sort by depth
status: todo
milestone: Art
size: S
owner: builder
depends_on: [T-0080]
builder:
review_rounds: 0
---

## Goal
In a 3/4 view, things lower on the screen are nearer. A person standing north of a tall
wardrobe is hidden behind it; a person south of it stands in front. Today objects always draw
under people.

## Read first
`game/view2d/objects_view_2d.gd`, `object_view_2d.gd`, `people_view_2d.gd`, `game/main.gd`
(`_ready`).

## Scope
- Change: `main.gd` (one y-sorted parent node), `objects_view_2d.gd`, `object_view_2d.gd`
  (position at the footprint, draw relative to it), `tests/game/test_objects_view_2d.gd`.
- **Out of scope:** tall terrain (trees and wall fronts stay flat tiles for now), sorting
  between floors.

## Specification
- In `main.gd`, add a `Node2D` named `Depth` with `y_sort_enabled = true`, and put
  `ObjectsView2D` and `PeopleView2D` under it (both `y_sort_enabled = true`, so their
  children sort together). `PathMarker2D` stays under the terrain.
- `ObjectView2D.position` = the bottom edge of the footprint, in pixels:
  `Vector2(rect.position.x, rect.end.y)` of `footprint_rect`, set when the view is added.
  `_draw` subtracts it, so placeholders and sprites look the same as before.
- A person's position is already their feet, so a person whose feet are south of an
  object's bottom edge draws in front of it.

## Acceptance criteria
- [ ] An object view's position is the bottom-left of its footprint →
  `test_objects_view_2d.gd: test_object_view_sits_on_footprint_bottom`
- [ ] Objects and people share one y-sorted parent → `test_depth_parent_sorts_objects_and_people`
  (build the node tree as `main.gd` does, or check `main.gd`'s structure with a helper that
  `main.gd` calls)
- [ ] Nothing looks different with placeholders → screenshot `out/t0081.png` in the flat
  (default start), compared with `main`

## Implementation notes

## Questions

## Review feedback
