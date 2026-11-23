# whats-new-skill

A [Claude Code](https://claude.com/claude-code) skill that keeps a "What's New" page in your app
current: every feature a user would notice gets an entry, written by the agent in the same PR as
the feature. Each entry links straight to the feature (it scrolls into view and pulses) and
carries the best screenshots from the PR.

## The idea

- **The entry ships with the feature.** Entries live in one YAML file in the repo. The agent adds
  one in the same PR as the feature, so the page never falls behind and nobody has to remember to
  write release notes.
- **"Show me" goes straight to it.** Each entry names the page (`href`) and a key (`highlight`).
  The new thing is tagged `data-whats-new="<key>"`, and the link carries `?whats_new=<key>`. A
  small hook on every page finds the tag, scrolls to it, pulses an outline for a few seconds, and
  drops the param so a reload doesn't replay it. For a feature on every record (every invoice,
  every project), the app swaps in a real record the reader can see, never a hardcoded id.
- **Screenshots from the PR.** The agent picks the best one to three from the PR's screenshots
  (pairs well with [pr-screenshot-skill](https://github.com/kylefritz/pr-screenshot-skill)),
  converts them to WebP and checks each against the entry's audience. They are served by a
  controller behind the entry's own check, never from `public/`.
- **As private as the feature.** Every entry has an audience copied from the feature's own gate.
  An unknown audience fails to load instead of defaulting open, and filtering is on the server.
- **Tests keep it honest.** Every `highlight` must be tagged somewhere in the frontend, every
  `href` must be a real route, and the screenshots folder and the YAML must match both ways. A
  broken "Show me" link fails CI, not the page.
- **A standing rule in CLAUDE.md.** Setup adds a short rule to the project's CLAUDE.md, so every
  later session adds entries without being asked.

## Install

```bash
git clone https://github.com/kylefritz/whats-new-skill ~/code/whats-new-skill
ln -s ~/code/whats-new-skill ~/.claude/skills/whats-new
```

Then, in an app: "set up a What's New page", or just finish a feature and Claude adds the entry.
You can also ask "what's new?" or "write the What's New entry for this PR".

## What's in here

| File | What it does |
|---|---|
| `SKILL.md` | The instructions Claude follows: when an entry is due, how to write it, link it, pick screenshots and check them, and how to set the page up |
| `references/claude-md-rule.md` | The rule setup adds to the project's CLAUDE.md |
| `references/rails/` | Reference implementation (Rails, Minitest): model, controller, routes, starter YAML, tests |
| `references/react/` | The highlight hook and the page (Inertia + React + Tailwind) |
| `references/js/whats-new-highlight.js` | The same highlighter without a framework |
| `references/css/whats-new.css` | The pulsing outline |

The reference code is Rails and React because that's what it came from; the skill tells the agent
to port it, behavior and tests included, for other stacks.

## License

MIT. See [LICENSE](LICENSE).
