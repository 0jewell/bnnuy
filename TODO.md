# TODO

- [x] Add `import` CLI command to import existing assets from a Roblox experience;
- [x] Add `--output` support for import to write to a custom manifest file;
- [x] Add `--force` support for import to fully rewrite manifest + state;
- [x] Add incremental import behavior (without `--force`) that fills only missing assets;
- [x] Add import support for badges, game passes, and developer products;
- [x] Add placeholder icon generation under `.bnnuy-icons/` with item-based filenames;
- [x] Add support for downloading and storing real remote icons during import;
- [x] Improve manifest validation and sync-time normalization for common type mismatches;
- [ ] Add dry-run mode for `sync` and `import` to show planned changes without writing;
- [ ] Add proper alpha-bleeding support for generated/imported icon images;
- [ ] Add a `rename` command to rename entries in both manifest and state;
- [ ] Add optional `.luau` output generation, with nested/non-nested output options;