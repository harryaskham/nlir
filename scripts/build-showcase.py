#!/usr/bin/env python3
"""Render nlir "expression -> rich language" showcase cards as shareable PNGs.

Crisp, accurate code-cards (not LLM image-gen): each card shows a terse nlir
expression and the fluent English it expands to. HTML/CSS -> PNG via headless
chromium, so the exact expressions/outputs stay razor-sharp. Deterministic
outputs are exact; LLM outputs are real captures (claude-sonnet-5) documented in
examples/*.sh headers and contributed by the swarm (aur-1's expr->language set).

Two card kinds:
  - simple  (1200x630, social/OG): expr -> one English output (+ optional source).
  - grid    (1200xN):  one claim + expr -> a labelled grid of lens outputs.

Usage:  python3 scripts/build-showcase.py [--out showcase] [--only NAME]
Requires: chromium (headless); ImageMagick montage (optional) for a contact sheet.
"""
from __future__ import annotations
import argparse
import html
import re
import shutil
import subprocess
import sys
from pathlib import Path

# --- simple cards: expr -> output (det exact; llm = real claude-sonnet-5) ------
SIMPLE = [
    dict(name="formalize", expr="@'lmk if any Qs'", pill="llm · claude-sonnet-5",
         out="Please let me know if you have any questions.",
         cap="@ formalise — texting shorthand becomes professional"),
    dict(name="understood", expr="@'k'", pill="llm · 1 char → a sentence",
         out="Understood.",
         cap="the formalise floor — a single character of shorthand becomes a complete, courteous reply"),
    dict(name="simplify", expr=":'idempotent'", pill="llm · claude-sonnet-5",
         out="Doing it again doesn't change anything after the first time.",
         cap=": simplify — 13 characters become a plain-English definition"),
    dict(name="expand", expr="~>'the main benefits of regular exercise'", pill="llm · claude-sonnet-5",
         out="Regular physical activity delivers lasting benefits to physical health, "
             "mental wellbeing, and overall quality of life.",
         cap="~> expand then distil — a few keywords become one rich line"),
    dict(name="tip", expr="'sixty'+'sixty'*'a fifth'", pill="llm coercion · exact", out="72",
         cap="words become math — a $60 bill plus a 20% tip, with precedence"),
    dict(name="collective", expr="'half a dozen'+'a pair'+'a trio'", pill="llm coercion · exact", out="11",
         cap="collective-noun calculator — 6 + 2 + 3, read from words"),
    dict(name="pow", expr="2**3**2", pill="det · exact", out="512",
         cap="right-associative exponentiation — 2^(3^2), matching normal math"),
    dict(name="negate", expr="!(a&b)", pill="det · exact", out="not (a and b)",
         cap="! negate over & and — grouping parentheses preserved"),
    dict(name="subject", expr="#^-1", pill="llm · reads your chat",
         out="the primary subject of the last assistant message",
         cap="# subject · ^-1 last message — one glance at the conversation"),
    # aur-1 contributions (real captures)
    dict(name="exec-summary", expr="@~x", pill="llm · claude-sonnet-5",
         src="hey so the mobile team is blocked on us, the api change we promised for "
             "tuesday slipped because the migration was gnarlier than expected, realistically it's thursday now",
         out="The API change originally scheduled for Tuesday has been postponed to Thursday "
             "due to a more complex migration process, which is currently blocking the mobile team's progress.",
         cap="@~ the executive summary — a rambling update becomes one crisp line"),
    dict(name="escalation", expr="@~^_-1", pill="llm · reads your chat",
         src="this is the THIRD time the deploy has broken prod this week and honestly "
             "i'm losing my mind … someone needs to actually own this",
         out="Recurring deployment failures have caused three production outages this week, "
             "and no resolution has yet been implemented. This ongoing issue has affected team morale "
             "and is now impacting customers. It is essential that an owner be assigned to address this "
             "pipeline issue promptly.",
         cap="@~^_-1 — a heated rant becomes a clean, forwardable escalation"),
    dict(name="considered-reply", expr="@(^-1 & 'phase it over two quarters, aligned to our Q3 roadmap')",
         pill="llm · reads your chat",
         src="I'd rewrite the auth service in Rust for the memory-safety guarantees and to kill the class of bugs we keep hitting.",
         out="Yes. I would recommend rewriting the authentication service in Rust to leverage its "
             "memory-safety guarantees and eliminate the recurring bugs \u2014 phased over two quarters, "
             "in alignment with our Q3 security-first roadmap.",
         cap="the considered reply \u2014 take an agent's suggestion (^-1), fold in your amendment (& ...), "
             "make it formal (@). one move: reply to any proposal with your own twist."),
    dict(name="decisive-close", expr="@(~0^*-1 & 'decision: start with Auth0, reassess at 50k MAU')",
         pill="llm · reads the whole thread",
         src="a 4-turn debate \u2014 build our own auth vs use Auth0 (control & in-house expertise vs speed, compliance, recurring cost & lock-in)",
         out="After weighing building our own auth against adopting Auth0 \u2014 control and in-house expertise "
             "versus speed, compliance, and recurring cost \u2014 the decision is to start with Auth0 and "
             "reassess upon reaching 50,000 monthly active users, keeping the option to move in-house if "
             "costs later justify it.",
         cap="the decisive close \u2014 read the WHOLE thread (~0^*-1), fold in your decision (& 'decision: ...'), "
             "close it formally (@). end any debate in one line, grounded in what was actually said."),
    dict(name="reasoned-no", expr="@(!^-1 & '<your grounds>')",
         pill="llm · reads your chat",
         src="Let's skip writing tests for the prototype so we can move faster and hit the Friday deadline.",
         out="We should not forgo writing tests for the prototype merely to expedite progress and meet the "
             "Friday deadline \u2014 prototypes invariably become the final product.",
         cap="the reasoned no \u2014 decline a proposal (!^-1) on your stated grounds (& '…'), argued and "
             "professional (@). the honest counterpart to the yes: say no, and say why. reusable to push "
             "back on any suggestion."),
    dict(name="grounded-counter",
         expr="@(^-1 & '- but scoped to just the hot 10% of users' & ^_-1)",
         pill="llm · reads your chat",
         src="you: 'infra budget is frozen this quarter'  ·  agent: 'cache the entire user graph in Redis'",
         out="I recommend caching the complete user graph in Redis to address the API latency issue, "
             "scoped specifically to the hottest 10% of users. Please note that our infrastructure "
             "budget is frozen for this quarter.",
         cap="the grounded counter — reply to their suggestion, fold in your amendment, and ground it "
             "in an earlier constraint, made formal: reply + modify + reference + restyle, a whole "
             "considered response in a handful of sigils"),
    dict(name="cited-synthesis",
         expr="@~(^_-1 & ^_-2 & ^_-3)",
         pill="llm · reads your chat",
         src="three scattered asks: 'make it fast' · 'it has to work offline' · 'it's too cluttered'",
         out="The redesign should aim to simplify and declutter the user interface, ensure reliable "
             "functionality in offline conditions, and deliver high-performance analytics, even for "
             "accounts with substantial data volumes.",
         cap="the cited synthesis — weave several things they said across the chat (^_-1, ^_-2, ^_-3) "
             "into one crisp position: distil + formalise scattered asks into 'here's what you're "
             "really asking for'"),
    dict(name="opposition", expr=">@!x", pill="llm · claude-sonnet-5",
         src="we should adopt a four-day work week",
         out="We should not adopt a four-day workweek. While the concept may seem appealing—"
             "promising better work-life balance and higher morale—the practical drawbacks make it "
             "an unwise change. Compressing the same work into fewer days could increase daily pressure, "
             "risk gaps in client availability, and require costly restructuring, with no guarantee that "
             "productivity or satisfaction improve. …",
         cap=">@! the opposition brief — the strongest developed case against your own claim"),
    dict(name="target-reverse", expr="'is it too late to switch frameworks'?", pill="llm · reverse golf",
         out="Is it too late to switch frameworks?",
         cap="the reverse: 37 characters in, a polished question out"),
    # aur-2 contributions (real captures)
    dict(name="gettysburg", expr="'eighteen sixty three'-'four score and seven'", pill="llm coercion · exact",
         out="1776",
         cap="words become history — 1863 minus 'four score and seven' lands on 1776"),
    dict(name="answer", expr="'six'*'seven'", pill="llm coercion · exact", out="42",
         cap="the answer to life, the universe, and everything — from two words"),
    dict(name="reverse-dictionary", expr="#'a program that translates source code into machine code'",
         pill="llm · names the thing", out="Compiler",
         cap="# on a description names the thing — describe what it does, get what it's called"),
    dict(name="mvp", expr=":'MVP'", pill="llm · claude-sonnet-5",
         out="The simplest version of something you build first, just to see if it works, "
             "before you add all the fancy extra parts.",
         cap=": expands an acronym into the whole concept — six characters in"),
    dict(name="opposite", expr="!'hot'", pill="llm · antonym", out="cold",
         cap="! on a lone concept-word gives its opposite, not just 'not hot'"),
    dict(name="three-bases", expr="'0o17'+'0xF'+'0b1'", pill="llm coercion · exact", out="31",
         cap="octal + hex + binary, added as numbers — every base a source file uses"),
    dict(name="composer-reply",
         expr="@&[:'their proposal to rewrite everything in rust','agree in principle','but do it incrementally, hot paths first','mindful of our small team and the release']",
         pill="llm · claude-sonnet-5",
         out="We concur in principle with the proposal to rebuild the system using Rust; however, we "
             "recommend an incremental approach, prioritizing critical paths first, in consideration of "
             "our limited team capacity and the upcoming release schedule.",
         cap="the composer @&[...] — weave several points (acknowledge + agree + modify + caveat) into one "
             "polished reply; each slot is transformable (: plain their point) and the leading op dials "
             "tone (@ formal / : warm)"),
    dict(name="empathetic-redirect",
         expr=":&['acknowledge the team is frustrated the deploy keeps breaking','they are right that the current process is painful','but the real root cause is skipped tests, not the tooling','so from friday every merge runs the test suite first']",
         pill="llm · claude-sonnet-5",
         out="The team feels upset because the program keeps breaking, and they're right — that's been really "
             "annoying. But the real reason isn't the tools. It's that we skipped testing our work before "
             "making changes. So starting Friday, every change will be tested first before it's allowed in.",
         cap="the empathetic redirect — validate + agree + reframe + fix woven into one warm message; the "
             "leading : dials a WARM tone (swap @ for a formal announcement, same slots)"),
    # msm-0 contribution — multi-message digest/select (reads a RANGE of your chat)
    dict(name="catchup", expr="p=~0^*-2;[$p,^_-1]", pill="llm · reads your whole thread",
         src="a 5-turn design chat — event-sourcing? \u2192 simpler ledger \u2192 refunds?",
         out="The team debated event-sourcing versus a simpler append-only ledger for the new "
             "billing service, settling on the ledger approach given team size.  \u2192  and their "
             "live question, verbatim: \u201chow do we handle refunds and corrections in an "
             "append-only model?\u201d",
         cap="catch up in one glance \u2014 bind the thread-so-far as a summary, then emit it + their live question raw"),
    dict(name="exec-brief", expr="@~0^*-1", pill="llm · reads your whole thread",
         src="a 5-turn incident thread — 500s after the 2pm deploy \u2192 2026-expiry bug \u2192 rollback? \u2192 hotfix + 'brief the VP in 10 min'",
         out="The 2:00 PM deployment introduced a defect in the checkout process, causing valid "
             "cards with a 2026 expiration date to be incorrectly rejected. As the deployment also "
             "included a live fraud-rule migration, reverting it was considered too risky. "
             "Consequently, the team will implement an expedited hotfix to the expiration date "
             "validation logic ahead of the upcoming VP briefing.",
         cap="brief the VP in 10 minutes \u2014 a messy incident thread becomes one formal, forwardable paragraph"),
    dict(name="ticket", expr="[#~0^*-1, ~0^*-1]", pill="llm · reads your whole thread",
         src="a 5-turn scoping chat — fuzzy matching? \u2192 latency tradeoff \u2192 fallback idea \u2192 'cap at edit-distance 2'",
         out="\u201cFuzzy matching fallback\u201d  \u2014  The team decided to add fuzzy matching only "
             "as a fallback when exact search returns no results, capped at edit-distance 2.",
         cap="turn a messy chat into a titled ticket \u2014 subject line (#) + one-line summary (~), ready to file"),
    dict(name="plain-recap", expr=":~0^*-1", pill="llm · reads your whole thread",
         src="a 4-turn debate — freeze the API for stability vs ship the already-announced launch",
         out="Some computers are having big problems, and the people fixing them need extra time. "
             "But another team already told everyone a big launch would be ready by a certain day. "
             "So now there's a hard choice: fix the problems first and be a little late, or keep the "
             "promise and launch on time.",
         cap="explain the whole thread like I just walked in \u2014 : gives a plain, jargon-free recap (tone-knob sibling of EXEC BRIEF's @)"),
    dict(name="two-sides", expr="[~0^_-1, ~0^-1]", pill="llm · reads your whole thread",
         src="a 4-turn negotiation — user: ship by Friday · assistant: needs two weeks to test",
         out="\u201cTheir side\u201d \u2014 the team needs the payments feature shipped by Friday, with a "
             "proposal to release a beta Friday and GA two weeks later.    \u201cOur side\u201d \u2014 "
             "engineering wants two weeks for testing and a security review, but a flagged beta could "
             "ship Friday if limited to internal users first.",
         cap="split a debate by ROLE \u2014 ^_ = their side (every user turn), ^ = our side (every assistant turn), each distilled"),
]

# --- grid cards: one claim + expr -> labelled lens outputs ---------------------
GRID = [
    dict(name="perspective-wheel", expr="[#x, ~x, >x, !x, @x, x?]", pill="llm · 6 lenses",
         claim="we should sunset the legacy API",
         cap="one claim, refracted along every axis of meaning — topic · length · polarity · register · mode",
         cols=2, cells=[
             ("#x  topic", "Sunsetting the legacy API"),
             ("~x  gist", "We should retire the legacy API."),
             ("!x  negate", "We should not sunset the legacy API."),
             ("@x  formal", "It is recommended that the legacy API be decommissioned."),
             ("x?  question", "Should we sunset the legacy API?"),
             (">x  expand", "We should formally deprecate and eventually decommission the legacy API, "
                            "with a clear timeline for phasing it out of production."),
         ]),
    dict(name="deliberation", expr="[>@x, >@!x, ~(>@x & >@!x)]", pill="llm · for / against / verdict",
         claim="should we migrate our REST API to GraphQL",
         cap="the case for, the case against, and an impartial synthesis — reasoning in one line",
         cols=1, cells=[
             (">@x  FOR", "A serious case that migrating REST to GraphQL is worthwhile: it can reduce "
                          "over- and under-fetching, add strong typing, and give clients precise queries."),
             (">@!x  AGAINST", "The developed counter-case: migration effort, a learning curve, and added "
                               "caching complexity may outweigh the benefits for the team right now."),
             ("~(…&…)  VERDICT", "Weighs migrating from REST to GraphQL — reduced over/under-fetching and "
                                 "strong typing against migration effort, learning curve, and caching complexity."),
         ]),
    dict(name="ladder", expr="[:x, x, @x]", pill="llm · one thought, three registers",
         claim="we really need to ship this by friday",
         cap="one message flexed up and down the formality scale — pick your register at a glance",
         cols=1, cells=[
             (":x  plain", "We really need to finish this by Friday."),
             ("x   as-is", "we really need to ship this by friday"),
             ("@x  formal", "This deliverable must be completed and shipped by Friday."),
         ]),
    dict(name="self-summarizing-memo",
         expr="k=>@'sunset the legacy billing API before Q3';[$k,~$k]",
         pill="llm · writes, then reflects on itself",
         claim="we should sunset the legacy billing API before Q3",
         cap="the self-summarizing memo — write a formal memo, bind it with =, then emit it AND a "
             "reflection on its own gist. no new operator: the = binding IS the self-reference "
             "(Harry's 'addendum a reflection on the summary of what we just wrote').",
         cols=1, cells=[
             ("$k  the memo you wrote", "The legacy billing API—superseded by newer infrastructure—must be "
              "fully retired from production before Q3 begins, with all dependent services and client "
              "integrations migrated to its replacement well ahead of the deadline…"),
             ("~$k  a reflection on its own gist", "The legacy billing API must be fully decommissioned "
              "and all dependent consumers migrated before Q3 begins."),
         ]),
    dict(name="self-red-team",
         expr="k=@>'freeze all hiring until Q3';[$k, >!~$k]",
         pill="llm · drafts, then argues against itself",
         claim="we should freeze all hiring until Q3",
         cap="the self-red-team — write your proposal, then have nlir build the strongest DEVELOPED case "
             "against its own gist. pressure-test your thinking before you send. >!~$k = expand · negate · "
             "summarise your own draft — the steelmanned rebuttal, in three sigils.",
         cols=1, cells=[
             ("$k  your proposal", "It is recommended that the organization institute an immediate and "
              "complete suspension of all hiring until Q3 — no new requisitions, no further offers, and "
              "existing vacancies (including backfills) held in abeyance, uniformly across all departments…"),
             (">!~$k  its own strongest rebuttal", "The organization should refrain from a complete, blanket "
              "freeze. Rather than halting all recruitment company-wide, hold off until the Q3 review — "
              "avoiding a premature, overly broad action that could disrupt hiring, stall growth, or leave "
              "critical positions unfilled…"),
         ]),
    dict(name="full-layered-reply",
         expr="k=@(^-1 & 'start with just the payment step' & ^_-1 & 'only if it wont slip launch');[$k,~$k]",
         pill="llm · reads your chat · the whole act, one line",
         claim="add end-to-end tests for the whole checkout flow before launch",
         cap="the full layered reply — a whole considered response in ONE expression: reply to the agent "
             "(^-1), fold in your modification, reference an earlier point (^_-1: 'we're short on QA'), add "
             "a caveat, make it formal (@) — then addendum a reflection on your own summary (~$k). six moves.",
         cols=1, cells=[
             ("$k  your layered reply", "It is recommended that end-to-end tests be implemented for the entire "
              "checkout flow prior to launch, beginning with the payment step. Please be advised that QA capacity "
              "is significantly constrained this quarter; accordingly, this effort should proceed only if it does "
              "not jeopardize the launch timeline."),
             ("~$k  its own one-line gist", "End-to-end checkout testing (starting with payment) is recommended "
              "before launch, but only if it doesn't risk the timeline, given limited QA capacity this quarter."),
         ]),
    dict(name="honest-yes", expr="[@(^-1 & '<your amendment>'), ~>!^-1]", pill="llm · reply, then red-teams it",
         claim="[agent] we should rewrite the auth service in Rust — for the memory-safety guarantees, to kill the class of bugs we keep hitting",
         cap="the honest yes \u2014 accept + amend their proposal (@(^-1 & '…')), then auto-surface the strongest "
             "case AGAINST it (~>!^-1). one move that replies AND red-teams itself \u2014 say yes without fooling "
             "yourself. reusable after any tempting proposal.",
         cols=1, cells=[
             ("@(^-1 & '…')  your reply", "I would recommend rewriting the authentication service in Rust to obtain "
              "its memory-safety guarantees and eliminate the recurring class of bugs we continue to encounter \u2014 "
              "implemented over two quarters, in alignment with our Q3 roadmap."),
             ("~>!^-1  the catch", "The strongest case against: most of the service's bugs are logic errors rather "
              "than memory-safety issues, so hardening the existing code is likely more cost-effective than a risky, "
              "time-consuming full rewrite."),
         ]),
]

# --- lightweight nlir syntax highlighter --------------------------------------
STRING_RE = re.compile(r"'[^']*'|\"[^\"]*\"")
NUM_RE = re.compile(r"\b\d+\b")
OPS = ["**", "^-", "^*", "^_", "^/", "#", "!", "&", "|", "?", "@", ":", "~",
       ">", "<", "+", "-", "*", "/", "^", ";", "=", "$", "[", "]", "(", ")", ",", "%"]


def highlight(expr: str) -> str:
    out, i, n = [], 0, len(expr)
    while i < n:
        m = STRING_RE.match(expr, i)
        if m:
            out.append(f'<span class="s">{html.escape(m.group())}</span>'); i = m.end(); continue
        m = NUM_RE.match(expr, i)
        if m:
            out.append(f'<span class="n">{html.escape(m.group())}</span>'); i = m.end(); continue
        for op in OPS:
            if expr.startswith(op, i):
                out.append(f'<span class="o">{html.escape(op)}</span>'); i += len(op); break
        else:
            out.append(html.escape(expr[i])); i += 1
    return "".join(out)


CSS = """
* { margin:0; padding:0; box-sizing:border-box; font-variant-ligatures:none; font-feature-settings:"liga" 0, "calt" 0; }
body {
  font-family:'Fira Sans','DejaVu Sans',sans-serif;
  background:
    radial-gradient(900px 520px at 14% 6%, rgba(168,85,247,.30), transparent 60%),
    radial-gradient(760px 520px at 96% 104%, rgba(34,211,238,.16), transparent 55%),
    linear-gradient(140deg,#160e2e 0%,#1d1140 46%,#241056 100%);
  color:#efeaff; overflow:hidden; padding:56px 66px; display:flex; flex-direction:column;
}
.head { display:flex; align-items:baseline; justify-content:space-between; }
.brand { font-family:'Fira Code',monospace; font-weight:700; font-size:32px; color:#fff; }
.brand .dot { color:#c084fc; }
.brand .sub { font-family:'Fira Sans',sans-serif; font-weight:400; font-size:18px; color:#b9a8e6; margin-left:13px; }
.pill { font-family:'Fira Code',monospace; font-size:15px; color:#a7f3d0;
  border:1px solid rgba(52,211,153,.4); background:rgba(16,185,129,.10);
  padding:7px 15px; border-radius:999px; white-space:nowrap; }
.expr { font-family:'Fira Code',monospace; font-weight:500; color:#efeaff; background:#100a24;
  border:1px solid rgba(168,85,247,.32); border-radius:16px; box-shadow:0 16px 46px rgba(0,0,0,.40);
  word-break:break-word; }
.expr .o { color:#e879f9; } .expr .s { color:#7dd3fc; } .expr .n { color:#fca5a5; }
.src { font-size:19px; color:#b9a8e6; font-style:italic; }
.src b { color:#8778ad; font-style:normal; font-family:'Fira Code',monospace; font-size:14px; }
.foot { display:flex; align-items:center; justify-content:space-between; margin-top:8px; }
.cap { font-size:17px; color:#c3b6ea; max-width:900px; }
.gh { font-family:'Fira Code',monospace; font-size:15px; color:#8778ad; }
"""

SIMPLE_HTML = """<!doctype html><html><head><meta charset="utf-8"><style>
html,body {{ width:1200px; height:630px; }} {css}
.body {{ flex:1; display:flex; flex-direction:column; justify-content:center; gap:20px; }}
.expr {{ font-size:{esz}px; padding:24px 32px; line-height:1.3; }}
.arrow {{ display:flex; align-items:center; gap:16px; color:#8b7bbf; font-size:16px;
  font-family:'Fira Code',monospace; letter-spacing:3px; text-transform:uppercase; }}
.arrow .line {{ height:1px; background:linear-gradient(90deg,#a855f7,transparent); flex:1; }}
.out {{ font-size:{osz}px; line-height:1.32; color:#fff; border-left:4px solid #c084fc; padding:2px 0 2px 24px; }}
</style></head><body>
  <div class="head"><div class="brand">nlir<span class="dot">·</span><span class="sub">natural-language IR</span></div><div class="pill">{pill}</div></div>
  <div class="body">
    {src}
    <div class="expr">{expr}</div>
    <div class="arrow"><span>becomes</span><span class="line"></span></div>
    <div class="out">{out}</div>
  </div>
  <div class="foot"><div class="cap">{cap}</div><div class="gh">github.com/harryaskham/nlir</div></div>
</body></html>"""

GRID_HTML = """<!doctype html><html><head><meta charset="utf-8"><style>
html,body {{ width:1200px; height:{h}px; }} {css}
.claim {{ font-size:21px; color:#e9e2ff; margin:2px 0 2px 0; }}
.claim b {{ color:#8778ad; font-style:normal; font-family:'Fira Code',monospace; font-size:14px; font-weight:500; }}
.expr {{ font-size:34px; padding:16px 26px; line-height:1.25; margin:14px 0 20px 0; display:inline-block; }}
.grid {{ display:grid; grid-template-columns:repeat({cols},1fr); gap:16px; flex:1; }}
.cell {{ background:rgba(255,255,255,.035); border:1px solid rgba(168,85,247,.20); border-radius:14px; padding:16px 20px; }}
.cell .lbl {{ font-family:'Fira Code',monospace; font-size:16px; color:#e879f9; margin-bottom:7px; }}
.cell .txt {{ font-size:{tsz}px; line-height:1.34; color:#f3efff; }}
</style></head><body>
  <div class="head"><div class="brand">nlir<span class="dot">·</span><span class="sub">natural-language IR</span></div><div class="pill">{pill}</div></div>
  <div class="claim"><b>one claim ·</b> &ldquo;{claim}&rdquo;</div>
  <div class="expr">{expr}</div>
  <div class="grid">{cells}</div>
  <div class="foot"><div class="cap">{cap}</div><div class="gh">github.com/harryaskham/nlir</div></div>
</body></html>"""


def esz(expr):
    n = len(expr)
    return 62 if n <= 12 else 52 if n <= 20 else 42 if n <= 32 else 34 if n <= 46 else 28


def osz(out):
    n = len(out)
    return 92 if n <= 3 else 38 if n <= 40 else 31 if n <= 110 else 25 if n <= 240 else 21


def chromium():
    for c in ("chromium", "chromium-browser", "google-chrome", "google-chrome-stable"):
        if shutil.which(c):
            return shutil.which(c)
    sys.exit("no chromium found")


SCALE = 1.0


def shot(chrome, htmlp, pngp, w, h):
    url = f"file://{Path(htmlp).resolve()}"
    subprocess.run([chrome, "--headless", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                    f"--force-device-scale-factor={SCALE}", f"--window-size={w},{h}",
                    f"--screenshot={pngp}", url], check=True, capture_output=True)


def render_simple(card, outdir, chrome):
    src = ""
    if card.get("src"):
        src = f'<div class="src"><b>from &nbsp;</b>&ldquo;{html.escape(card["src"])}&rdquo;</div>'
    doc = SIMPLE_HTML.format(css=CSS, expr=highlight(card["expr"]), out=html.escape(card["out"]),
                             pill=html.escape(card["pill"]), cap=html.escape(card["cap"]),
                             esz=esz(card["expr"]), osz=osz(card["out"]), src=src)
    return _emit(card["name"], doc, outdir, chrome, 1200, 630)


def render_grid(card, outdir, chrome):
    cells = card["cells"]
    rows = (len(cells) + card["cols"] - 1) // card["cols"]
    h = 300 + rows * 150
    tsz = 22 if max(len(t) for _, t in cells) <= 130 else 19
    cellhtml = "".join(
        f'<div class="cell"><div class="lbl">{html.escape(lbl)}</div>'
        f'<div class="txt">{html.escape(txt)}</div></div>' for lbl, txt in cells)
    doc = GRID_HTML.format(css=CSS, h=h, cols=card["cols"], expr=highlight(card["expr"]),
                           claim=html.escape(card["claim"]), pill=html.escape(card["pill"]),
                           cap=html.escape(card["cap"]), cells=cellhtml, tsz=tsz)
    return _emit(card["name"], doc, outdir, chrome, 1200, h)


def _emit(name, doc, outdir, chrome, w, h):
    htmlp = outdir / f"{name}.html"
    pngp = outdir / f"nlir-{name}.png"
    htmlp.write_text(doc)
    shot(chrome, htmlp, pngp, w, h)
    htmlp.unlink()
    print("rendered", pngp)
    return pngp


def main():
    global SCALE
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="showcase")
    ap.add_argument("--only", default=None)
    ap.add_argument("--scale", type=float, default=1.0,
                    help="device scale factor; 1 = 1200x630 social size (default), 2 = retina")
    args = ap.parse_args()
    SCALE = args.scale
    outdir = Path(args.out); outdir.mkdir(parents=True, exist_ok=True)
    chrome = chromium()
    for c in SIMPLE:
        if not args.only or c["name"] == args.only:
            render_simple(c, outdir, chrome)
    for c in GRID:
        if not args.only or c["name"] == args.only:
            render_grid(c, outdir, chrome)
    if not args.only:
        render_contact_sheet(outdir, chrome)


SHEET_HTML = """<!doctype html><html><head><meta charset="utf-8"><style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:2280px; }}
body {{ font-family:'Fira Sans',sans-serif; padding:56px 60px 64px;
  background:radial-gradient(1100px 700px at 12% 4%, rgba(168,85,247,.28), transparent 60%),
    linear-gradient(140deg,#120a26 0%,#1b0f3c 50%,#210e50 100%); color:#efeaff; }}
.h {{ display:flex; align-items:baseline; gap:16px; margin-bottom:8px; }}
.h .b {{ font-family:'Fira Code',monospace; font-weight:700; font-size:46px; color:#fff; }}
.h .b .d {{ color:#c084fc; }}
.h .t {{ font-size:24px; color:#b9a8e6; }}
.sub {{ font-size:22px; color:#c3b6ea; margin-bottom:26px; }}
.g {{ display:grid; grid-template-columns:repeat(3,1fr); gap:26px; }}
.g img {{ width:100%; border-radius:14px; border:1px solid rgba(168,85,247,.22); box-shadow:0 14px 40px rgba(0,0,0,.4); display:block; }}
</style></head><body>
  <div class="h"><div class="b">nlir<span class="d">·</span></div><div class="t">natural-language IR — terse shorthand becomes fluent English</div></div>
  <div class="sub">github.com/harryaskham/nlir — a config-defined operator language for your prompt window</div>
  <div class="g">{imgs}</div>
</body></html>"""


def render_contact_sheet(outdir, chrome):
    order = ["formalize", "understood", "simplify", "expand", "tip", "collective", "pow",
             "negate", "subject", "gettysburg", "answer", "reverse-dictionary", "mvp",
             "opposite", "three-bases", "exec-summary", "escalation", "opposition", "target-reverse"]
    imgs = "".join(f'<img src="file://{outdir.resolve()}/nlir-{n}.png">'
                   for n in order if (outdir / f"nlir-{n}.png").exists())
    doc = SHEET_HTML.format(imgs=imgs)
    htmlp = outdir / "_sheet.html"
    pngp = outdir / "nlir-showreel.png"
    htmlp.write_text(doc)
    rows = (len(order) + 2) // 3
    shot(chrome, htmlp, pngp, 2280, 200 + rows * 430)
    htmlp.unlink()
    print("contact sheet", pngp)


if __name__ == "__main__":
    main()
