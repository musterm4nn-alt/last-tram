# Fixture saves

One save file per save version, made by the game at that version. `tests/sim/test_save.gd`
loads every file here, so old saves keep working after the save format changes.

When you bump `SaveCodec.SAVE_VERSION`, add a new fixture made with the new version
(for example `v2_basic.json`). Never edit or delete existing fixtures.
