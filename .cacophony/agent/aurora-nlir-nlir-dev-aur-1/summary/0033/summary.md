# Session summary — golf #20 (red-team the answer) + target #18 (yes/no confirmation)

## What landed
- examples/golf-aur1-20-redteam.sh — `!^-1`: point negation at the assistant's last answer
  → the opposite recommendation ("yes cache in Redis..." → "no, don't cache..."). `!^-1?` frames
  the counter as a challenge question. A one-key stress-test of advice before acting. Cf. #14
  follow-up ^-1? (ASKS about the answer); this DISAGREES with it.
- examples/target-aur1-18-confirm.sh — 9th `?` shape: 'the deploy succeeded'? (24c) → "Did the
  deploy succeed?" A past-tense statement steers ? to the yes/no "Did…?" frame.

## Operator-takeaway
Negation composes with message reads: !^-1 = instant devil's advocate on the last answer.
And ? now has 9 shapes — the polar yes/no ("Did…?") joins the wh-palette, all from seed phrasing.
