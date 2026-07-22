#!/usr/bin/env python3
"""Render and publish the versioned ADR 0020 expert questionnaire.

The questionnaire JSON is the canonical source. Credentials are read from the
process environment or a local .Renviron file and are never written or printed.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
QUESTIONNAIRE = ROOT / "docs/reviews/adr-0020-expert-questionnaire.json"
MARKDOWN = ROOT / "docs/reviews/adr-0020-expert-questionnaire.md"
API_BASE = "https://api.tally.so"
API_VERSION = "2025-02-01"


def load_questionnaire() -> dict:
    questionnaire = json.loads(QUESTIONNAIRE.read_text(encoding="utf-8"))
    validate_questionnaire(questionnaire)
    return questionnaire


def validate_questionnaire(questionnaire: dict) -> None:
    decisions = questionnaire.get("decisions", [])
    if len(decisions) != 6:
        raise RuntimeError("the expert-review instrument must contain exactly six decisions")
    numbers = [decision.get("number") for decision in decisions]
    identifiers = [decision.get("id") for decision in decisions]
    if numbers != list(range(1, 7)) or len(set(identifiers)) != 6 or not all(identifiers):
        raise RuntimeError("decision numbers must be 1–6 and decision IDs must be unique")
    response_options = questionnaire.get("response_options", [])
    if len(response_options) != 4 or not any(
        "outside my expertise" in option.lower() for option in response_options
    ):
        raise RuntimeError("response choices must retain four options including expertise abstention")
    figure = questionnaire.get("orientation", {}).get("figure", {})
    if not all(figure.get(field) for field in ("url", "name", "alt_text", "caption")):
        raise RuntimeError("the external consultation must retain its orientation figure")
    if "attribution" in questionnaire.get("respondent_fields", {}):
        raise RuntimeError("the internal consultation must not request publication permission")
    if not questionnaire.get("overall", {}).get("required"):
        raise RuntimeError("the overall recommendation must remain required")


def render_markdown(questionnaire: dict) -> str:
    orientation = questionnaire["orientation"]
    fields = questionnaire["respondent_fields"]
    figure = orientation["figure"]
    lines = [
        f"# {questionnaire['title']}",
        "",
        "<!-- Generated from adr-0020-expert-questionnaire.json. -->",
        "",
        f"**Questionnaire:** `{questionnaire['questionnaire_id']}`",
        f"**Schema version:** `{questionnaire['schema_version']}`",
        f"**Estimated time:** {questionnaire['estimated_time']}",
        "",
        f"## {orientation['method_heading']}",
        "",
        orientation["method"],
        "",
        f"## {orientation['problem_heading']}",
        "",
        orientation["problem"],
        "",
        orientation["request"],
        "",
        f"## {orientation['figure_heading']}",
        "",
        orientation["figure_intro"],
        "",
        f"![{figure['alt_text']}]({figure['url']})",
        "",
        f"*{figure['caption']}*",
        "",
        "## About the reviewer",
        "",
        f"- **{fields['name']['label']}** — required",
        f"- **{fields['affiliation']['label']}** — optional",
        "",
    ]

    for decision in questionnaire["decisions"]:
        lines.extend(
            [
                f"## Decision {decision['number']} — {decision['title']}",
                "",
                decision["summary"],
                "",
                f"**Question:** {decision['question']}",
                "",
                "Response options:",
            ]
        )
        lines.extend(f"- {option}" for option in questionnaire["response_options"])
        lines.extend(["", f"**Optional comment:** {decision['comment_prompt']}", ""])

    lines.extend(
        [
            "## Overall recommendation",
            "",
            questionnaire["overall"]["label"],
        ]
    )
    lines.extend(f"- {option}" for option in questionnaire["overall"]["options"])
    lines.extend(
        [
            "",
            f"**Optional comment:** {questionnaire['overall']['comment_prompt']}",
            "",
            "## Response handling",
            "",
            questionnaire["data_handling"],
            "",
            questionnaire["response_fallback"],
            "",
            questionnaire["closing"],
            "",
        ]
    )
    return "\n".join(lines)


def stable_id(namespace: uuid.UUID, label: str) -> str:
    return str(uuid.uuid5(namespace, label))


def build_blocks(questionnaire: dict) -> list[dict]:
    namespace = uuid.uuid5(uuid.NAMESPACE_URL, questionnaire["questionnaire_id"])
    blocks: list[dict] = []

    def block(label: str, block_type: str, group_type: str, payload: dict,
              group_label: str | None = None) -> None:
        blocks.append(
            {
                "uuid": stable_id(namespace, f"block:{label}"),
                "type": block_type,
                "groupUuid": stable_id(namespace, f"group:{group_label or label}"),
                "groupType": group_type,
                "payload": payload,
            }
        )

    def text(label: str, content: str) -> None:
        block(label, "TEXT", "TEXT", {"html": html.escape(content)})

    def heading(label: str, content: str) -> None:
        block(label, "HEADING_2", "HEADING_2", {"html": html.escape(content)})

    def title(label: str, content: str) -> None:
        block(label, "TITLE", "QUESTION", {"html": html.escape(content)})

    def short_answer(label: str, prompt: str, placeholder: str, required: bool) -> None:
        title(f"{label}:title", prompt)
        block(
            f"{label}:input",
            "INPUT_TEXT",
            "INPUT_TEXT",
            {"isRequired": required, "placeholder": placeholder, "name": label},
        )

    def long_answer(label: str, prompt: str, required: bool = False) -> None:
        title(f"{label}:title", prompt)
        block(
            f"{label}:input",
            "TEXTAREA",
            "TEXTAREA",
            {"isRequired": required, "placeholder": "", "name": label},
        )

    def single_choice(label: str, prompt: str, options: list[str], required: bool) -> None:
        title(f"{label}:title", prompt)
        group_label = f"{label}:options"
        for index, option in enumerate(options):
            payload = {
                "index": index,
                "isFirst": index == 0,
                "isLast": index == len(options) - 1,
                "allowMultiple": False,
                "text": option,
                "name": label,
            }
            if index == 0:
                payload["isRequired"] = required
            block(
                f"{label}:option:{index}",
                "MULTIPLE_CHOICE_OPTION",
                "MULTIPLE_CHOICE",
                payload,
                group_label,
            )

    def image(label: str, figure: dict) -> None:
        block(
            label,
            "IMAGE",
            "IMAGE",
            {
                "images": [{"name": figure["name"], "url": figure["url"]}],
                "hasCaption": True,
                "caption": figure["caption"],
                "hasAltText": True,
                "altText": figure["alt_text"],
            },
        )

    def divider(label: str) -> None:
        block(label, "DIVIDER", "DIVIDER", {})

    orientation = questionnaire["orientation"]
    fields = questionnaire["respondent_fields"]
    block(
        "form-title",
        "FORM_TITLE",
        "TEXT",
        {"html": html.escape(questionnaire["title"]), "title": questionnaire["title"]},
    )
    text("estimated-time", f"Estimated time: {questionnaire['estimated_time']}")
    heading("method-heading", orientation["method_heading"])
    text("method", orientation["method"])
    heading("problem-heading", orientation["problem_heading"])
    text("problem", orientation["problem"])
    text("request", orientation["request"])
    heading("figure-heading", orientation["figure_heading"])
    text("figure-intro", orientation["figure_intro"])
    image("orientation-figure", orientation["figure"])

    heading("respondent-heading", "About you")
    short_answer(
        "respondent_name",
        fields["name"]["label"],
        fields["name"]["placeholder"],
        fields["name"]["required"],
    )
    short_answer(
        "respondent_affiliation",
        fields["affiliation"]["label"],
        fields["affiliation"]["placeholder"],
        fields["affiliation"]["required"],
    )

    divider("decisions:divider")
    heading("decisions:heading", "Six scientific choices for review")
    text(
        "decisions:instructions",
        "For each choice, select the closest assessment. Comments are optional, but they are the most useful place to identify assumptions, failure modes, diagnostics, or alternatives.",
    )
    for decision in questionnaire["decisions"]:
        label = f"decision_{decision['number']}"
        divider(f"{label}:divider")
        heading(f"{label}:heading", f"Decision {decision['number']} — {decision['title']}")
        text(f"{label}:summary", decision["summary"])
        single_choice(
            f"{label}_support",
            decision["question"],
            questionnaire["response_options"],
            True,
        )
        long_answer(f"{label}_comment", decision["comment_prompt"])

    divider("overall:divider")
    heading("overall:heading", "Overall recommendation")
    single_choice(
        "overall_recommendation",
        questionnaire["overall"]["label"],
        questionnaire["overall"]["options"],
        questionnaire["overall"]["required"],
    )
    long_answer("overall_comment", questionnaire["overall"]["comment_prompt"])

    heading("response-handling-heading", "Response handling")
    text("data-handling", questionnaire["data_handling"])
    text("fallback", questionnaire["response_fallback"])
    text("closing", questionnaire["closing"])
    return blocks


def load_api_key(env_file: Path) -> str:
    key = os.environ.get("TALLY_API_KEY", "").strip()
    if key:
        return key
    if env_file.exists():
        for raw_line in env_file.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[7:].lstrip()
            name, separator, value = line.partition("=")
            if separator and name.strip() == "TALLY_API_KEY":
                value = value.strip()
                if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                    value = value[1:-1]
                if value:
                    return value
    raise RuntimeError("TALLY_API_KEY was not found in the environment or local env file")


def api_request(method: str, path: str, key: str, payload: dict) -> dict:
    request = urllib.request.Request(
        API_BASE + path,
        data=json.dumps(payload).encode("utf-8"),
        method=method,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "User-Agent": "landscapeR-expert-review/1.0 (+https://github.com/drejom/landscapeR)",
            "tally-version": API_VERSION,
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Tally API returned HTTP {error.code}: {detail}") from error


def write_manifest(path: Path, response: dict, questionnaire: dict, blocks: list[dict]) -> None:
    canonical = json.dumps(
        {"questionnaire": questionnaire, "blocks": blocks},
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    form_id = response["id"]
    manifest = {
        "questionnaire_id": questionnaire["questionnaire_id"],
        "questionnaire_schema_version": questionnaire["schema_version"],
        "questionnaire_and_blocks_sha256": hashlib.sha256(canonical).hexdigest(),
        "block_count": len(blocks),
        "form_id": form_id,
        "public_url": f"https://tally.so/r/{form_id}",
        "status": response.get("status"),
        "updated_at": response.get("updatedAt"),
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("render", help="render the canonical questionnaire to Markdown")

    publish = subparsers.add_parser("publish", help="create or replace the hosted Tally form")
    publish.add_argument("--form-id", help="existing form ID to replace; omit to create")
    publish.add_argument("--status", choices=("DRAFT", "PUBLISHED"), default="DRAFT")
    publish.add_argument("--env-file", type=Path, default=ROOT / ".Renviron")
    publish.add_argument("--manifest", type=Path)

    args = parser.parse_args()
    questionnaire = load_questionnaire()
    rendered = render_markdown(questionnaire)
    MARKDOWN.parent.mkdir(parents=True, exist_ok=True)
    MARKDOWN.write_text(rendered, encoding="utf-8")

    if args.command == "render":
        print(MARKDOWN.relative_to(ROOT))
        return 0

    blocks = build_blocks(questionnaire)
    payload = {"status": args.status, "blocks": blocks}
    key = load_api_key(args.env_file)
    if args.form_id:
        payload["name"] = questionnaire["title"]
        response = api_request("PATCH", f"/forms/{args.form_id}", key, payload)
    else:
        response = api_request("POST", "/forms", key, payload)

    if args.manifest:
        write_manifest(args.manifest, response, questionnaire, blocks)
    print(f"form_id={response['id']} status={response.get('status')} url=https://tally.so/r/{response['id']}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
