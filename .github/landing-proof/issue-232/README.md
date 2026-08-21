# Issue #232 contact-sheet tile-isolation proof

The before image is the issue #226 contact sheet whose full plot subtitles
collided across tile boundaries at reduced reading size.

The after image uses concise tile-local labels and suppresses only the
underlying plot subtitles in the audit sheet. Full scientific captions remain
in the issue #226 inventory and separate caption files.

The reduced after image is the required smaller-dimension QA render. Inspect
both after images for tile isolation, label legibility, clipping, and legend
collisions.

Reproduce with:

Rscript scripts/render-issue-232-proof.R

Claim status: implementation proof; no biological claim.
