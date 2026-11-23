# CLAUDE.md rule

Paste this into the project's CLAUDE.md (or AGENTS.md). Change the paths, audiences and test
command to match the app.

```markdown
- **What's New** (skill `whats-new` has the how-to): every feature a user would notice gets an
  entry on `/whats-new`, added to `config/whats_new.yml` in the same PR as the feature. That means
  a new page or menu item, a new section or panel, a new email or setting, or a fix that visibly
  changes what people see. Refactors, tooling and invisible fixes don't get one.
  - **Direct link:** every entry has `href` (the page) and `highlight` (a `data-whats-new="<key>"`
    tag on the new thing), so "Show me" lands on the feature with it pulsing. For something on
    every record's page, use `example:`, never a hardcoded record id.
  - **Audience no wider than the feature:** copy the feature's own gate (`everyone`, `admins`, ...).
  - **Screenshots:** the best 1-3 from the PR's screenshots, as WebP under
    `config/whats_new/screenshots/<key>/`, checked against the audience (no admin pages, other
    people's data or secrets on a wide entry). Served by the controller, never from `public/`.
  - `bin/rails test test/models/whats_new_test.rb` checks the file, the tags and the folder.
```
