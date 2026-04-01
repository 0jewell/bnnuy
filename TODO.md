# TODO

- [x] Add `import` CLI command to import existing assets from a Roblox experience;
- [x] Add `--output` support for import to write to a custom manifest file;
- [x] Add `--force` support for import to fully rewrite manifest + state;
- [x] Add incremental import behavior (without `--force`) that fills only missing assets;
- [x] Add import support for badges, game passes, and developer products;
- [x] Add placeholder icon generation under `.bnnuy-icons/` with item-based filenames;
- [x] Add support for downloading and storing real remote icons during import;
- [x] Improve manifest validation and sync-time normalization for common type mismatches;
- [x] Avoid collapsing imported game passes that share the same name (dedupe by id only);
- [x] Show current item/action in progress UI during `sync` and `import`;
- [x] Truncate very long item names in progress status labels;
- [x] Allow additional custom fields directly on product entries (same level as base fields);
- [x] Keep `.bnnuy-state.yml` compact by omitting empty asset tables (`badges`, `passes`, `products`);
- [x] Add a YAML parser/cleaner pass for manifest and state files to normalize formatting and indentation;
- [ ] Add dry-run mode for `sync` and `import` to show planned changes without writing;
- [ ] Add proper alpha-bleeding support for generated/imported icon images;
- [ ] Add a `rename` command to rename entries in both manifest and state;
- [ ] Add optional `.luau` output generation, with nested/non-nested output options;
