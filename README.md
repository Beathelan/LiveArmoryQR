# Live Armory QR

An indispensable companion addon for the [WoW Classic Live Armory Twitch extension](https://github.com/Beathelan/LiveArmoryTwitchExtension).

Automatically generates a QR code on-screen which contains information about your WoW Classic character for use by the extension via computer vision.

The following data about your character is captured live as you play and stored in the QR code:
* Race
* Class
* Level
* Current and max HP
* Current and max "Power" (one of: Mana, Rage, Energy, Focus)
* Equipped items, including any applied enchants (but not including SOD runes)
* Talent selections
* Gold on hand
* Whether the character is dead or is in ghost form

No other data is collected, such as your character's name, friends, chat log, party members or anything else not explicitly listed above. More data may be collected in the future in order to support additional functionality for the extension, in which case the list provided will be diligently updated.

The QR code is repainted up to 4 times per second, as long as the status of the character changes.

## Usage

On first load, the QR code will appear on the top-left corner of your screen. You can then dragg it to any position convenient to you. In order to ensure the extension can locate and read the QR consistently, please ensure that the QR code does not end up permanently obscured by other elements of your WoW UI (short-term obstructions such as the map or Auction House windows are okay).

The addon will automatically record the last position of the QR code and restore it upon next login, even across multiple characters.

The following commands are available:

`/laqr lock`: prevents the QR code from being dragged around.
`/laqr unlock`: allows the QR code to be dragged around.
`/laqr reset`: resets the position of the QR code to the top-left corner and unlocks it.
`/laqr refresh`: causes the QR code to repaint on the next possible frame (normally, the QR repaints every 250 ms).
`/laqr debug`: toggles DEBUG mode on or off. While on DEBUG mode, the addon will print information to the chat log which probably will look like nonsense to you but it's helpful to the authors.

## Special Thanks

* LiveArmoryQA was inspired by and started as a fork of [qrcode-wow](https://github.com/tg123/qrcode-wow). Thank you [tg123](https://github.com/tg123) for making this possible!
* LiveArmoryQA uses [luaqrcode](https://github.com/speedata/luaqrcode) as its backbone for computing the QR Code, with very minor modifications so that the workload can be distributed between multiple frames in the context of a WoW addon.

## QR code message format

This section is only of interest to developers. Users feel free to skip it!

In order to store as much information as possible in as small a code as possible, this addon uses a custom encoding scheme. Every message contains only numbers, uppercase English alphabet letters and the following special characters: `$`, `-`, `+`, and `%`.

A message will ALWAYS conform to the structure
```
<CLASS>$<RACE>$<LEVEL>$<TALENTS>$<EQUIPMENT>$<CURRENT_HP>$<MAX_HP>$<POWER_TYPE>$<CURRENT_POWER>$<MAX_POWER>$<GOLD>$<DEAD_OR_GHOST><PADDING>
```
where
* `<CLASS>` is an integer in the range `[0-9]`, representing the character's class
* `<RACE>` is an integer in the range `[0-8]`, representing the character's race
* `<LEVEL>` is a [base32hex](https://en.wikipedia.org/wiki/Base32#Base_32_Encoding_with_Extended_Hex_Alphabet_per_%C2%A77)-encoded integer in the range `[1-60]`, containing the character's level
* `<TALENTS>` is a string containing the character's talents in the format expected by the [Wowhead Talent Calculator](https://www.wowhead.com/classic/talent-calc/)
* `<EQUIPMENT>` is a string containing the character's equipment in a special format which includes the item IDs, random enchantments (e.g. "of the Eagle") and permanent enchants for every slot (more details on the format TBD).
* `<CURRENT_HP>` is a base32hex-encoded integer in the range `[0-32767]` containing the character's current HP
* `<MAX_HP>` is a base32hex-encoded integer in the range `[0-32767]` containing the character's max HP
* `<POWER_TYPE>` is an integer in the range `[0-3]`, representing the character's currently active power type (i.e. Mana, Rage, Focus, Energy)
* `<CURRENT_POWER>` is a base32hex-encoded integer in the range `[0-32767]` containing the character's current power
* `<MAX_POWER>` is a base32hex-encoded integer in the range `[0-32767]` containing the character's max power
* `<GOLD>` is a base32hex-encoded integer in the range `[0,1048575]` containing the character's gold on hand
* `<DEAD_OR_GHOST>` is set to `1` if the character is currently dead or in ghost form; `0` otherwise
* `<PADDING>` is a string repeating the `%` character as many times as necessary to make the message's length long enough to require [QR Version 8](https://www.qrcode.com/en/about/version.html) to fit it. This keeps the size of the QR code consistent
