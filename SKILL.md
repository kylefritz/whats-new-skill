---
name: whats-new
description: Use when finishing or opening a PR for anything a user of the app would notice (a new page, menu item, panel, email, setting, or a fix that visibly changes what people see), when writing or fixing a What's New entry or its "Show me" highlight, when asked what's new or what shipped, or when setting up a What's New page in an app that doesn't have one yet.
---

# What's New

A What's New page tells users what shipped, in plain words, newest first. Three ideas make it worth
reading:

1. **The entry ships with the feature.** Entries live in one YAML file in the repo and land in the
   same PR as the feature, so the page is never a chore someone forgets later.
2. **Every entry links straight to the feature.** "Show me" lands on the page with the new thing
   scrolled into view and pulsing, not on a home page with a "look around".
3. **Every entry can carry screenshots**, the best one to three from the feature's PR, served only
   to readers allowed to see the entry.

## First: does this app have a What's New page?

Look for `config/whats_new.yml` (or the project's equivalent; the project's CLAUDE.md names it).

- **It exists:** skip to "Does this work get an entry?".
- **It doesn't:** set it up with "Setting it up" at the bottom, then come back.

## Does this work get an entry?

Give it an entry if a user would notice it or want to be told: a new page or menu item, a new
section or panel, a new email, a new setting, a fix that visibly changes the data people see.

No entry for refactors, internal tooling, dependency bumps, CI, or bugs nobody saw. When unsure,
ask: "would a user be glad someone told them?"

## Write the entry

```yaml
entries:
  - date: 2026-11-02
    title: Export any table to CSV
    body: >-
      Every table now has an Export button in its bottom bar. You get the rows you filtered,
      in the order you sorted them.
    audience: everyone
    href: /reports
    highlight: csv-export
    prs: [ 606 ]
    screenshots:
      - file: export-button.webp
        alt: "The Export button in the table's bottom bar"
```

1. **Audience: copy the feature's gate.** An entry describes the feature, so it is exactly as
   private as the feature. Read the controller or route guard and match it. A feature behind an
   admin check gets `audience: admins`; one any signed-in user can open gets `everyone`. The
   audiences are the app's roles, defined in one place (`AUDIENCES_BY_ROLE` in the reference
   model). A missing or unknown audience must fail to load, never default to everyone.

2. **Target: tag the new thing on the page the link lands on.** Add `data-whats-new="<key>"` to
   the root element of the new thing, and set `highlight: <key>`. Keys are lowercase with hyphens
   (`csv-export`); the highlighter ignores any other shape. Tag the thing itself, not the whole
   page: a button, a panel, a column header, a menu item. One element can hold one key; several
   elements can share a key and all pulse.

3. **Link: the page where the feature lives.** `href` is a path in the app. The link the page
   renders is `href` plus `?whats_new=<highlight>`, which is what triggers the pulse.

   | Feature lives | Link |
   |---|---|
   | On its own page | `href: /the-page` |
   | On every record's page (every invoice, every project) | `href` to the index, plus `example:` so the app swaps in a real record (see below) |
   | Nowhere visible (an email, a background change) | Where it surfaces: the settings page that controls it, an admin list of sent emails, a sample |

   **Examples beat ids.** Don't hardcode `/invoices/42` in the YAML: record 42 may be deleted, or
   belong to someone the reader can't see. Instead name a kind (`example: overdue_invoice`) and
   let the app resolve it per reader to a record that both exists and actually shows the feature,
   falling back to `href` when nothing qualifies. The reference controller has the hook for this
   (`example_href_for`).

4. **Copy: one to three sentences on what you can now do.** Lead with the user's action, not the
   implementation. Use only facts from the PR. No marketing words, no "we're excited".

5. **Date and order.** `date` is the ship date. New entries go at the top. Within one date the
   file's order stands, so put the biggest news first.

6. **PRs.** The number exists once the PR is open: open it, add `prs: [ N ]`, push again. Show PR
   links only to people who can open the repo (admins, if the repo is private).

7. **Screenshots: the best few from the PR.** See the next section.

## Screenshots

Pick one to three images that show the feature most clearly. Look at every candidate yourself
before choosing; don't choose by filename or order.

**Where they come from.** If the PR already has screenshots (the `pr-screenshots` skill puts them
in the description), reuse those. With hidden-ref hosting, fetch them with git, which works in
private repos where curl won't:

```bash
git fetch origin "+refs/pr-screenshots/*:refs/pr-screenshots/*"
git show <sha>:<file> > tmp/shot.png     # for each github.com/<owner>/<repo>/raw/<sha>/<file> link
```

Otherwise take fresh ones (Playwright at desktop width, plus phone width at 390px if the feature
matters on a phone).

**Choose:** an "after" over a "before"; the feature in context over a tight crop nobody can place;
a desktop shot plus a phone shot when both exist.

**Privacy check, per image, against the entry's audience.** A picture can say more than the
entry does. Reject the image (pick another, or use none) if it shows:

- anything the audience can't see in the app: admin menus or admin pages on an `everyone` entry,
  another user's or another account's records, internal notes;
- real customer or personal data on an entry for a wide audience (use demo or seed data instead);
- secrets: tokens, API keys, emails or phone numbers in a corner of the frame.

**Store them:**

```bash
cwebp -q 80 -m 6 -resize 1600 0 shot.png -o config/whats_new/screenshots/<key>/<name>.webp
```

`<key>` is the entry's title with apostrophes dropped, parameterized (`Export any table to CSV`
becomes `export-any-table-to-csv`). Name files in lowercase with hyphens. Give each an `alt` that
says what it shows. Keep each under 250 KB.

**Never put them in `public/`** or the asset pipeline: anyone could fetch them by URL, whatever
the entry's audience. The app serves them through a controller action that runs the entry's own
audience check and returns 404 to anyone else.

Say in the PR description which screenshots you picked, and which you rejected for privacy.

## Confirm it works

Tests prove the key is tagged somewhere and the files exist, not that it lights up. Run the What's
New tests, start the app, and in a browser:

1. As a user in the audience, open What's New and click "Show me". It should land on the feature,
   scrolled to it, with the outline pulsing, and the `?whats_new=` param gone from the URL.
2. As a user outside the audience, confirm the entry is absent and its screenshot URLs return 404.
3. Check phone width. A target that's hidden on phones won't light up; say so in the PR if that's
   the case.
4. The entry's screenshots load and look right in both light and dark themes, if the app has both.

## Setting it up

When the app has no What's New page yet, build it from `references/`. The reference code is Rails
(Minitest) with Inertia + React; port it if the stack differs, keeping the same behavior and the
same tests.

| File | Goes to | What it does |
|---|---|---|
| `references/rails/whats_new.rb` | `app/models/whats_new.rb` | Loads and validates the YAML, filters by audience, builds links and screenshot URLs |
| `references/rails/whats_new_controller.rb` | `app/controllers/` | The page, and the screenshot action behind the entry's check |
| `references/rails/routes.rb` | merge into `config/routes.rb` | Two routes |
| `references/rails/whats_new.yml` | `config/whats_new.yml` | A starter file with one entry |
| `references/rails/whats_new_test.rb` | `test/models/` | The checks that keep links and screenshots from rotting |
| `references/react/useWhatsNewHighlight.ts` | your hooks folder | Finds the tagged element, scrolls, pulses, strips the param |
| `references/react/WhatsNewPage.tsx` | your pages folder | The list page |
| `references/js/whats-new-highlight.js` | anywhere | The same highlighter without React, for server-rendered apps |
| `references/css/whats-new.css` | your main stylesheet | The pulsing outline |

Then:

1. **Map roles to audiences.** Edit `AUDIENCES_BY_ROLE` to the app's real roles. Keep the rule
   that an unknown audience raises.
2. **Call the highlighter on every page**, once, in the shared layout, keyed on the page URL so it
   re-runs on client-side navigation.
3. **Add a menu entry** for `/whats-new`. Optionally light a dot on it when `WhatsNew.latest_date`
   for this reader is newer than the last time they opened the page.
4. **Point the frontend glob in the test** at where the app's components live, so "every highlight
   is tagged" searches the right files.
5. **Write the first entry**: the What's New page itself, highlighting the menu item.
6. **Add the standing rule to the project's CLAUDE.md** (next section).

## Add the rule to the project's CLAUDE.md

So every future session adds entries without being asked, add the block in
`references/claude-md-rule.md` to the project's CLAUDE.md (or AGENTS.md), under its conventions or
architecture section. Adjust the paths and audiences to the app. If the file already has a What's
New rule, update it rather than adding a second one.
