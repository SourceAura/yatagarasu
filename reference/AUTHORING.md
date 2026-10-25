# Authoring a notification design

A notification design is the card Ryoku shows when an app sends a notification.
Ryoku ships its own design; this catalogue holds the ones the community builds.
A user installs yours from **RyoStore -> Notifications**, picks it in **Settings
-> Overlays**, and sees it on the next notification. Installing never switches
anyone's design by itself, and removing the one in use puts the user back on
Ryoku's own design.

Start from [`template/`](template/): it is a complete, working card in one small
file.

## The folder

```
notifications/<id>/
  Card.qml              the popup card (required)
  *.qml, lib/*.js       anything else it needs, all inside this folder
  README.md             what it is and how to use it
  LICENSE               a licence you can honour
  PROVENANCE.txt        where it comes from (optional)
  assets/preview.webp   a real screenshot of the card (store art, not installed)
  manifest.json         written by tools/pack-product.py, never by hand
```

`<id>` is lowercase letters, digits and dashes. `ryoku` is reserved for the
design Ryoku ships.

The whole folder installs as one piece and runs from its own copy, so a relative
import may reach files inside the folder and nothing outside it. The security
screen blocks a relative import that leaves the folder.

## The contract

Ryoku's notification host creates one `Card.qml` for each live popup and sets
its width to the popup column. The root is an `Item` and receives:

| Property | What the host sets |
| --- | --- |
| `required property var notification` | the Quickshell notification: `id`, `appName`, `appIcon`, `image`, `summary`, `body`, `urgency`, `actions`, `expireTimeout` and `hints` |
| `property real us` | this output's UI scale |
| `property int lifespanMs` | how long the popup remains; 0 means it stays until dismissed |
| `property string position` | `"Left"`, `"Right"` or `"Center"`, the corner holding the column |
| `property bool showImages` | the user's notification image choice; draw `notification.image` only when true |

Your card may define these members:

| Member | What it means |
| --- | --- |
| `implicitHeight` | the card height; the host gives it the full 400 px times `us` column width |
| Any local presentation state | expansion or pressed state may live on the card, but it ends when the card is destroyed |

The shell keeps the rest:

| The host keeps | What that means for a design |
| --- | --- |
| The popup window and column | never create a window; the host owns position, spacing and the corner gap |
| Arrival, dismiss and reorder transitions | do not move sibling cards or run a second popup lifetime |
| Timers, DND, sounds and history | `lifespanMs` is presentation data only; never keep a timer alive after destruction |
| Input focus | the popup column does not take keyboard focus |
| Ownership gates | a bar style that owns banners, and the nacre exclusion, can hide every notification design |
| Failure recovery | a card that does not load is replaced by Ryoku's own card |

`notification.body` may contain simple markup. `notification.urgency` is a
`NotificationUrgency.Low`, `Normal` or `Critical` value when you need a visual
cue.

`notification.image` and `notification.appIcon` are strings. Keep local values
used to test them as strings too: a `url` property never strictly equals `""`,
even when it is empty.

## Actions and dismissal

Each entry in `notification.actions` has `identifier`, `text` and `invoke()`.
The action with `identifier === "default"` is the body click. Run an action with
`action.invoke()`, then call `Notifs.dismiss(notification)`. A close button only
calls `Notifs.dismiss(notification)`. Do not spawn an action command yourself.

`Notifs.timeLabel(notification)` gives the user's formatted arrival time, and
`Icons.path(name, true)` resolves a themed icon as a file URL.

## What you may import

- `QtQuick`, `QtQuick.Layouts`, `QtQuick.Shapes`, `QtQuick.Effects`, `QtQml`
- `Qt5Compat.GraphicalEffects`
- `Quickshell`, `Quickshell.Widgets`
- `Quickshell.Services.Notifications` for `NotificationUrgency`
- `shell.services`: `Notifs`, `Theme`, `Icons` and the shell's other services
- `Ryoku.Ui.Singletons`: `Tokens`, `Motion`, `I18n`

Use `Tokens` or `Theme` for colour, type, spacing and durations, and multiply
surface geometry by `us`. The card follows the user's colour scheme, interface
scale and reduced-motion setting that way. It never creates windows or starts
processes.

## Traps that blank a notification

- Never name a property after an `Item` anchor line (`left`, `right`, `top`,
  `bottom`, `horizontalCenter`, `verticalCenter`, `baseline`). QML refuses it
  with "Cannot override FINAL property" and the whole design fails to load.
- Inside a `Repeater` delegate, `action: action` or `foo: foo` binds the
  delegate's property to itself. Use `modelData` or give the outer id another
  name.
- A singleton of your own needs a `qmldir` beside it naming it.
- When `Card.qml` fails to load, Ryoku draws its own card instead. The reason is
  in `~/.local/state/ryoku/surfaces/shell.log`.

## The registry entry

Add one entry to `notifications/registry.json` with the fields every catalogue
uses: `id`, `name`, `version`, `path`, `author`, `upstream`, `summary`,
`description`, `tags`, `accent`, `surface`, `preview`, `screenshots`, `manifest`
(`"manifest.json"`), `manifestSha256`, `lastUpdated`, `official: false`, and
`license`. An optional `discord` invite offers author contact. Then:

```sh
python3 tools/pack-product.py notifications/<id>
```

writes `manifest.json` and its hash in the registry. Run it again after every
change, and bump `version` in the registry first: installed copies are offered
an update only when the version moves.

## Test it live

1. Point the store at your checkout (see [`../DEVELOP.md`](../DEVELOP.md)):
   `echo "file://$HOME/Work/ryostore" > ~/.config/ryoku/ryostore-base`.
2. Install it: RyoStore -> Notifications, or
   `ryostore install notifications <id>`.
3. Settings -> Overlays: pick it, then send notifications with and without a
   body, image, default action and labelled actions.
4. After a change, bump the version, repack and install the update. The shell
   swaps the new copy in without a restart.

## Checklist

- [ ] App name, summary and body wrap without clipping at every UI scale.
- [ ] Labelled actions invoke once and then dismiss; the body runs the default action.
- [ ] The close button dismisses without invoking an action.
- [ ] Images obey the user's show-images choice, and an absent image leaves no hole.
- [ ] Persistent popups do not draw a false countdown.
- [ ] Left, right and centre columns look intentional on two outputs.
- [ ] It follows a colour scheme change and reduced motion.
- [ ] A deliberately broken copy falls back to Ryoku's card and logs the reason.
- [ ] `tests/validate-catalogue.sh` and `python3 tools/security-screen.py --root .` pass.
