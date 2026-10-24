import os
import sys
import json
import re
import subprocess
import urllib.request
import urllib.error
from datetime import datetime, timedelta, timezone

token = os.environ.get("GH_TOKEN")
org_name = os.environ.get("ORG_NAME")
repo_name = os.environ.get("REPO_NAME")
discussion_num = int(os.environ.get("DISCUSSION_NUMBER", "1"))
event_name = os.environ.get("GITHUB_EVENT_NAME", "")

if not token or not org_name or not repo_name:
    print("::error::Missing required environment variables (GH_TOKEN, ORG_NAME, REPO_NAME).")
    sys.exit(1)

def send_graphql(query, variables):
    payload = json.dumps({"query": query, "variables": variables}).encode("utf-8")
    req = urllib.request.Request(
        "https://api.github.com/graphql",
        data=payload,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "GitHub-Action-Script"
        }
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"::error::HTTP {e.code}: {e.read().decode('utf-8', errors='ignore')}")
        sys.exit(1)

fetch_query = """
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    discussion(number: $number) {
      id
      body
    }
  }
}
"""
res = send_graphql(fetch_query, {"owner": org_name, "name": repo_name, "number": discussion_num})
repo_obj = res.get("data", {}).get("repository")
if not repo_obj or not repo_obj.get("discussion"):
    print(f"::error::Could not find Discussion #{discussion_num} in {org_name}/{repo_name}.")
    sys.exit(1)

discussion_id = repo_obj["discussion"]["id"]
current_body = repo_obj["discussion"].get("body", "")

changed_files = []
if event_name in ("push", "workflow_dispatch"):
    for cmd in [
        ["git", "diff", "--name-only", "HEAD~1", "HEAD"],
        ["git", "log", "-1", "--name-only", "--pretty="]
    ]:
        try:
            out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
            lines = [l.strip() for l in out.decode("utf-8", errors="ignore").splitlines() if l.strip()]
            if lines:
                changed_files = lines
                break
        except Exception:
            continue

target_roots = ("modules/", "server script/", "local script/")
matched_changes = []
detected_components = set()

for path in changed_files:
    normalized = path.replace("\\", "/").lower()
    for root in target_roots:
        if normalized.startswith(root):
            matched_changes.append(path)
            parts = path.replace("\\", "/").split("/")
            if len(parts) > 1 and parts[1].strip():
                detected_components.add(parts[1].strip())
            break

has_qualifying_push = (len(matched_changes) > 0)

if event_name == "push" and not has_qualifying_push:
    print("Push detected, but no changes in Modules, Server script, or local script. Skipping.")
    sys.exit(0)

manila_tz = timezone(timedelta(hours=8))
now = datetime.now(manila_tz)
today = now.date()

date_pattern = r"Target Dates:.*?\*?([A-Za-z]+\s+\d{1,2})\*?\s*[–—\-]\s*\*?([A-Za-z]+\s+\d{1,2}(?:,\s*\d{4})?)\*?"
date_match = re.search(date_pattern, current_body)

parsed_start = None
parsed_end = None
is_expired = False
is_early = False

if date_match:
    raw_start = date_match.group(1).strip()
    raw_end = date_match.group(2).strip()

    year = now.year
    year_match = re.search(r"\d{4}", raw_end)
    if year_match:
        year = int(year_match.group(0))
    else:
        raw_end += f", {year}"

    raw_start += f", {year}"

    for fmt in ("%B %d, %Y", "%b %d, %Y"):
        try:
            if not parsed_start:
                parsed_start = datetime.strptime(raw_start, fmt).date()
        except ValueError:
            pass
        try:
            if not parsed_end:
                parsed_end = datetime.strptime(raw_end, fmt).date()
        except ValueError:
            pass

    if parsed_end and today > parsed_end:
        is_expired = True

    if parsed_start and has_qualifying_push and today < parsed_start:
        is_early = True

# If scheduled run and release deadline hasn't passed, do nothing
if event_name == "schedule" and not is_expired:
    print("Scheduled check: Current release window is still active. No update required.")
    sys.exit(0)

needs_delay = (is_expired and not has_qualifying_push)

start_date = now + timedelta(days=5)
end_date = now + timedelta(days=7)

title_window = f"{start_date.strftime('%b')} {start_date.day} – {end_date.strftime('%b')} {end_date.day}"
body_window = f"{start_date.strftime('%B')} {start_date.day} – {end_date.strftime('%B')} {end_date.day}, {end_date.year}"

if detected_components:
    comp_list = ", ".join(sorted(detected_components))
    focus_text = f"Active changes recently touched: {comp_list}. Finalizing unit tests and client/server validation."
else:
    focus_text = "Polishing core data handlers, network wrappers, and gameplay/state loops before release."

notice_block = ""
if is_early:
    notice_block = (
        "> [!TIP]\n"
        "> ### ⚡ Early Release Notice\n"
        "> Due to unexpected circumstances—rapid development progress, smooth integration passes, and early system validation—we were able to complete and ship this batch ahead of schedule!\n"
        ">\n"
        "> The latest modular updates are live on `main`. Below is the next upcoming release window.\n\n"
    )
elif needs_delay:
    notice_block = (
        "> [!WARNING]\n"
        "> ### ⏳ Schedule Adjustment & Status Update\n"
        "> Due to active debugging, technical constraints, or bandwidth adjustments, the previous milestone window has been adjusted. Development remains active, and modules will land once stability checks pass.\n\n"
    )

new_title = f"📢 Project Roadmap & Modular Releases (Target: {title_window})"
new_body = (
    f"{notice_block}Hey everyone! 👋\n\n"
    f"Welcome to **studious-spoon**. As part of building out the foundation for **GlzzLexi Studios**, I’ll be periodically rolling out open-source, modular Luau tools and starter systems straight from our development pipeline.\n\n"
    f"### 📦 Release Cadence\n"
    f"Because I’m balancing production and independent development, updates will ship incrementally:\n"
    f"- **Scope:** Expect **1 to 2 focused, production-ready modules** per release batch (e.g., custom state managers, network wrappers, or gameplay controller templates).\n"
    f"- **Philosophy:** Clean, plug-and-play code that you can drop into `ReplicatedStorage` or `ServerScriptService` with zero bloat.\n\n"
    f"### 🗓️ Next Release Window\n"
    f"- **Target Dates:** **{body_window}** *(subject to active development bandwidth)*\n"
    f"- **Focus:** {focus_text}\n\n"
    f"Drop your suggestions or feedback below on what types of modular tools or game systems you’d like to see prioritized next! 🚀"
)

mutation_query = """
mutation($id: ID!, $title: String!, $body: String!) {
  updateDiscussion(input: {
    discussionId: $id,
    title: $title,
    body: $body
  }) {
    discussion {
      url
    }
  }
}
"""
mutate_res = send_graphql(mutation_query, {"id": discussion_id, "title": new_title, "body": new_body})
url = mutate_res.get("data", {}).get("updateDiscussion", {}).get("discussion", {}).get("url")
print(f"Discussion #{discussion_num} successfully updated: {url}")
