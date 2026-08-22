# Repository agent instructions

Read this file completely before editing. Plan all changes, then make one
complete edit. If a file has been edited three or more times, stop and reread
the user's requirements.

When the user corrects you, stop and reread their message. Quote back what they
asked for and confirm it before proceeding.

When stuck, summarize what you tried and ask for guidance instead of retrying
the same approach. After two consecutive tool failures, change approach
entirely and explain what failed.

Act sooner. Read no more than three to five files before making a change. Break
work into small, verifiable steps. Confirm the approach before large changes.
Every few turns, reread the original request to ensure the work has not drifted.
Double-check outputs before presenting them and verify that changes address the
request completely.

## Authorized GitHub operations

For GitHub repository work the user has requested, read and write operations on
the scoped repository, its issues, pull requests, reviews, and CI runs are
authorized. The workspace filesystem sandbox is not a reason to withhold those
GitHub operations.

Use the GitHub connector and its managed credential for GitHub mutations when
available. This is the preferred path for updating pull requests, issues, and
review comments. A shell `gh` credential may be read-only even when the managed
connector has the required scope; do not infer that the requested mutation is
unauthorized from that mismatch.

Never print, persist, commit, or disclose token material or internal secret
locations. Do not probe credential paths. If the managed connector is
unavailable and an authorized mutation cannot be completed, report the exact
failed capability and request the approved credential-injection mechanism.

## Web search fallback

If WebSearch or WebFetch fails, use:

```sh
~/.codex/scripts/searx-json.sh "query" [num_results]
```

The command uses the self-hosted SearXNG instance at `search.omeally.com` and
returns one JSON line per result. Do not call that endpoint with bare `curl`.

## Review ratchet standing order

Before substantial work, read [`docs/agents/review-ratchet.md`](docs/agents/review-ratchet.md)
and perform its brief hygiene pass. Maintain it in the same change under the
Add, Correct, Deduplicate, and Graduate duties; report any ratchet change or
deliberate no-change disposition when finishing the work.
At a stopping point after an issue closes, a pull request merges, or work
intentionally pauses, report the
completed issue or PR number and summary, the next roadmap issue number/title,
and a brief summary of the work that follows.
