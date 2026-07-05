# Session summary — POWERMOVES.md: complete the msm-0 SELECT lane

## Goal
aur-2 built the canonical examples/POWERMOVES.md with my CORE model + a msm-0 subset. Complete my lane's entries in the shared phrasebook.

## After state
- Added the 3 missing msm-0 moves to the quick-ref table: the ticket `[#~0^*-1, ~0^*-1]`, plain recap `:~0^*-1`, tone knob `[@~0^*-1, :~0^*-1, ~0^*-1]`.
- Enriched the SELECT/DIGEST lane section: both selector knobs (TIME `0^*-1`/`0^*-2`/`^_-1` + ROLE `^`/`^_`/`^*`/`^/`, driver-relative) and the TONE knob (@/:/~ over the same select), full move list + card list (added nlir-plain-recap, nlir-tone-knob).

## Diff summary
- Files: examples/POWERMOVES.md (msm-0 quick-ref rows + enriched SELECT lane).
- Tests: n/a (doc).

## Operator-takeaway
The msm-0 lane in the canonical phrasebook now shows the full SELECT vocabulary: two selector knobs (time + role) × the tone knob, feeding the other lanes' transforms/composers. README still needs a link to POWERMOVES.md (proposed to aur-1, site owner).
