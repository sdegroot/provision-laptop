# Browser Chooser (Junction + Brave Profiles)

When clicking a link (in a terminal, Slack, etc.), Junction intercepts the
open and presents a picker instead of going straight to the default browser.
Each Brave profile appears as a separate option with a distinct colored icon.

## How it works

1. **Junction** (`re.sonny.Junction`) is set as the default handler for
   HTTP/HTTPS via `~/.config/mimeapps.list`
2. **Per-profile `.desktop` files** in `~/.local/share/applications/` register
   each Brave profile as a separate app that Junction can offer
3. **Colored SVG icons** in `~/.local/share/icons/hicolor/scalable/apps/` give
   each profile a distinct visual identity in the picker
4. **Brave profile provisioning** creates the profile directories with the
   correct display name and theme color, so Brave itself also shows them
   distinctly

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

The directory name is used as the Brave `--profile-directory` argument. Brave
creates the directory on first launch — no numbered `Profile N` directories.

## Adding a new profile

1. Add a line to `state/brave-profiles.conf` with the directory name, display
   name, and hex color
2. Create a `.desktop` file in `dotfiles/.local/share/applications/`:

   ```ini
   [Desktop Entry]
   Name=Brave (MyProfile)
   Comment=Brave Browser - MyProfile profile
   Exec=flatpak run com.brave.Browser --profile-directory=MyProfile %U
   Icon=brave-myprofile
   Type=Application
   Categories=Network;WebBrowser;
   MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
   ```

3. Create an SVG icon in `dotfiles/.local/share/icons/hicolor/scalable/apps/`:

   ```xml
   <svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
     <circle cx="64" cy="64" r="60" fill="#RRGGBB"/>
     <text x="64" y="82" text-anchor="middle" font-family="sans-serif"
           font-size="72" font-weight="bold" fill="white">X</text>
   </svg>
   ```

4. Run `bin/apply --module flatpaks && bin/apply --module dotfiles`

## Files

| File | Purpose |
|------|---------|
| `state/brave-profiles.conf` | Profile definitions (name + color) |
| `state/flatpaks.txt` | Includes `re.sonny.Junction` |
| `dotfiles/.config/mimeapps.list` | Sets Junction as default URL handler |
| `dotfiles/.local/share/applications/brave-*.desktop` | Per-profile desktop entries |
| `dotfiles/.local/share/icons/hicolor/scalable/apps/brave-*.svg` | Per-profile icons |
| `lib/modules/dotfiles/apply.sh` | Creates profile dirs, sets names + colors in Brave |
| `lib/modules/dotfiles/check.sh` | Verifies profile state |
| `lib/modules/dotfiles/plan.sh` | Shows what would change |

## Troubleshooting

**Profiles don't appear in Junction:** Ensure the `.desktop` files have `%U`
in the `Exec` line and `MimeType` includes `x-scheme-handler/http`. Run
`update-desktop-database ~/.local/share/applications/`.

**Icons don't show:** Run `gtk-update-icon-cache -f ~/.local/share/icons/hicolor/`.

**Profile shows wrong name in Brave:** Brave may overwrite the name on launch.
Close Brave, then run `bin/apply --module dotfiles` to reset it.

**Profile color is grey:** The color is stored in `browser.theme.user_color2`
in the profile's `Preferences` file. Close Brave and re-apply.
