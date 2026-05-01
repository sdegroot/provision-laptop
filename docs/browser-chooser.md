# Browser Chooser (Chowser + Brave Profiles)

When clicking a link (in a terminal, Slack, etc.), [Chowser](https://github.com/sreerams/Chowser) intercepts the open and presents a picker so you can choose which browser — or which Brave profile — handles it. Each Brave profile is a distinct option.

## How it works

1. **Chowser.app** is registered as the macOS default handler for HTTP/HTTPS in
   System Settings → Apps → Default web browser
2. Chowser is configured (via its menu-bar settings UI) with one entry per
   browser/profile you want to choose between
3. **Per-profile Brave launches** are configured by passing
   `--profile-directory=<dir>` so each appears as a separate Chowser entry
4. **Brave profile provisioning** creates the profile directories with the
   correct display name and theme color, so Brave itself shows them distinctly

## Profiles

Profiles are declared in `state/brave-profiles.conf`:

```
# Format: directory-name display-name color(hex)
Utrecht        Utrecht        #E53935
Epistola       Epistola       #1E88E5
Sittard-Geleen Sittard-Geleen #43A047
Fluxzero       Fluxzero       #8E24AA
Personal       Personal       #FB8C00
Company        Company        #00ACC1
```

The directory name is used as Brave's `--profile-directory` argument. Brave
creates the directory on first launch — no numbered `Profile N` directories.

## Adding a new profile

1. Add a line to `state/brave-profiles.conf` with the directory name, display
   name, and hex color
2. Run `bin/apply --module dotfiles` to create the profile dir and set
   the name/theme color in Brave's `Preferences`
3. Open Chowser → Settings → Browsers → **Add Browser** and point it at:

   ```
   /Applications/Brave Browser.app/Contents/MacOS/Brave Browser
   ```

   Add `--profile-directory=<directory-name>` as a launch argument.

## Files

| File | Purpose |
|------|---------|
| `state/brave-profiles.conf` | Profile definitions (name + color) |
| `lib/modules/dotfiles/apply.sh` | Creates profile dirs, sets names + colors in Brave |
| `lib/modules/dotfiles/check.sh` | Verifies profile state |
| `lib/modules/dotfiles/plan.sh` | Shows what would change |

Chowser is installed via Homebrew Cask (`state/casks.txt`) but its browser
list is configured manually through its menu-bar UI — there's no machine-readable
config provisioning for that yet.

## Bookmarks

Each Brave profile's bookmarks are tracked in this repo. See
[bookmark-sync.md](bookmark-sync.md) for `bin/sync-bookmarks pull` / `push`
and the apply-time seeding behavior.

## Troubleshooting

**Profile shows wrong name in Brave:** Brave may overwrite the name on launch.
Close Brave, then run `bin/apply --module dotfiles` to reset it.

**Profile color is grey:** The color is stored in `browser.theme.user_color2`
in the profile's `Preferences` file. Close Brave and re-apply.

**Chowser doesn't open links:** Verify Chowser is the default browser in
System Settings → Apps → Default web browser.
