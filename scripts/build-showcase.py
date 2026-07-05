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
    dict(name="expand", expr="~(>'the main benefits of regular exercise')", pill="llm · claude-sonnet-5",
         out="Regular physical activity delivers lasting benefits to physical health, "
             "mental wellbeing, and overall quality of life.",
         cap="~(>…) expand then distil — a few keywords become one rich line"),
    dict(name="tip", expr="'sixty'+'sixty'*'a fifth'", pill="llm coercion · exact", out="72",
         cap="words become math — a $60 bill plus a 20% tip, with precedence"),
    dict(name="collective", expr="'half a dozen'+'a pair'+'a trio'", pill="llm coercion · exact", out="11",
         cap="collective-noun calculator — 6 + 2 + 3, read from words"),
    dict(name="pow", expr="2**3**2", pill="det · exact", out="512",
         cap="right-associative exponentiation — 2^(3^2), matching normal math"),
    dict(name="negate", expr="!(a&b)", pill="det · exact", out="not (a and b)",
         cap="! negate over & and — grouping parentheses preserved"),
    dict(name="implication", expr='"socrates is a man"; "all men are mortal"; ~>?', pill="llm · ~>? implication",
         out="Socrates is mortal.",
         cap="~>? the implication — stack the premises with ; then infer the conclusion. the classic syllogism, in three sigils"),
    dict(name="macro", expr="{~(>@$0)} % 'we should rewrite it in Rust'", pill="llm · macro",
         out="It is recommended that this component be rewritten in Rust to gain memory safety "
             "and performance benefits, despite the upfront engineering effort required.",
         cap="{…} % arg — a named move as a callable form. the steelman idiom, quoted as a macro and applied to a claim"),
    dict(name="macro-det", expr="{$0 + $1} % (2, 3)", pill="det · form applied", out="5",
         cap="{…} is code-as-data, % applies it — a two-hole form called on a tuple. forms make nlir programmable"),
    dict(name="macro-formalize", expr="{@$0} % 'lmk if any Qs'", pill="llm · macro",
         out="Please let me know if you have any questions.",
         cap="the phrasebook, callable — {@$0} is a reusable formalise macro; % runs it on any input"),
    dict(name="telephone", expr="({~$0}_3) % 'we keep circling back to whether mobile has the bandwidth for the new onboarding flow before the launch date'", pill="llm · do-N-times",
         out="There's ongoing debate about whether mobile can finish onboarding before launch.",
         cap="({form}_N) composes a form N times — distil ×3, the telephone game. do-N-times, the last functional primitive"),
    dict(name="compose", expr="({$0+1}_3) % 5", pill="det · do-N-times", out="8",
         cap="do-N-times, deterministic — add-one composed three times: 5→6→7→8. forms + composition = a real functional layer"),
    dict(name="map", expr="$map%({$0*$0},[1,2,3])", pill="det · $map higher-order", out="1\n4\n9",
         cap="$map applies a form to each item → a LIST (1, 4, 9). the structural per-item map the string-ops can't do"),
    dict(name="foldmap", expr="$fold%({$0+$1},$map%({$0*$0},[1,2,3]))", pill="det · fold∘map", out="14",
         cap="map then fold — sum of squares, 1+4+9. higher-order forms compose into real programs"),
    dict(name="map-lang", expr="$map%({@$0},['lmk if any Qs','pls advise'])", pill="llm · $map over an llm form",
         out="Please let me know if you have any questions.\nPlease advise.",
         cap="$map an llm move over a list — formalise EACH item into its own reply. map an AI op over a list = real programs"),
    dict(name="mix", expr="$fold%({$0+$1},['3 apples','5 oranges','2 pears'])", pill="llm+det · fuzzy-extract, exact sum", out="10",
         cap="the flagship mix — nlir reads the numbers out of natural language (llm), then sums them exactly (det). structure deterministic, steps fuzzy: a terse program on meaning"),
    dict(name="consensus", expr="$fold%({~($0&$1)},['ship friday','we need two more weeks to test','security must review first'])", pill="llm · fold to consensus",
         out="Shipping is planned for Friday, but two more weeks of testing and a security review are required first.",
         cap="fold a list of views into a running consensus — each step weaves the next view in and distils. reduce, but over ideas"),
    dict(name="scan", expr="$scan%({$0+$1},[1,2,3,4])", pill="det · $scan running fold", out="1\n3\n6\n10",
         cap="$scan is fold that shows its work — the running total at each step: 1, 3, 6, 10. cumulative + progressive, the running-consensus primitive"),
    dict(name="filter", expr="$filter%({$0},[1,0,2,0,3])", pill="det · $filter keep-if", out="1\n2\n3",
         cap="$filter keeps the items that pass, drops the falsy — [1,0,2,0,3]→[1,2,3]. the SELECT the family was missing: map transforms, fold reduces, scan accumulates, filter selects"),
    dict(name="train-atop", expr="(~ @)%'hey can u take a look when u get a sec thx'", pill="train · atop compose (point-free)",
         out="Could you please review this when you have a moment.",
         cap="a TRAIN composes lenses point-free — (~ @) = distil∘formalise, no $0 spelled. a casual note becomes a polished ask, tacit"),
    dict(name="train-fork", expr="(# & ~)%'the login page has been completely broken since fridays deploy'", pill="train · fork — two lenses, one input",
         out="login page and The login page has been broken since Friday's deploy.",
         cap="the FORK (# & ~) runs subject AND gist on the SAME input, combined — topic + summary in one pass. N lenses on one input, point-free: APL trains for text"),
    dict(name="branch", expr="$if%('prod is completely down'~>'an incident','page the on-call now','all clear')", pill="llm+det · branch on an AI judgment",
         out="page the on-call now",
         cap="$if branches on an LLM condition — `~>` asks 'is this an incident?' and routes: prod-down → 'page the on-call now'; a typo → 'all clear'. deterministic control flow, fuzzy condition"),
    dict(name="sort", expr="$sort%[3,1,2,5,4]", pill="det · $sort — reorder", out="1\n2\n3\n4\n5",
         cap="$sort orders a list — [3,1,2,5,4]→[1,2,3,4,5]. with $nth (index) + $if (branch), programs can reorder + pick + branch now, not just transform/reduce"),
    dict(name="glyph-steelman", expr="⇑'we should just merge it now'", pill="glyph-op · your macro as one symbol", config_op=True,
         out="The recommendation is to proceed with the merge now, as all conditions are met and further delay would add risk.",
         cap="define ⇑ = {~(>@$0)} once — the whole steelman chain (formalise→expand→distil) becomes ONE symbol you own. your saved recipes become verbs, not re-typed prompts"),
    dict(name="glyph-map", expr="{$0*$0}↦[1,2,3]", pill="glyph-op · bind a glyph to map", config_op=True, out="1\n4\n9",
         cap="map as a glyph — bind ↦ = map in config, then {form}↦list maps the form over each item: {$0*$0}↦[1,2,3] = [1,4,9]. the higher-order engine as your own symbol"),
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
    dict(name="drift", expr="^_-2 Δ ^_-1", pill="llm · Δ diff · reads your chat",
         src="① let's do the full auth rewrite in Rust this quarter — memory-safety is worth it   →   "
             "② actually let's just patch the memory leak for now and defer the rewrite to next year",
         out="The scope shrank from a full quarter-long auth rewrite in Rust to a minimal memory-leak "
             "patch, and the timeline shifted from immediate to indefinitely deferred; the justification "
             "moved from a proactive value argument to a reactive stopgap.",
         cap="Δ the drift — ^_-2 Δ ^_-1 diffs your last two turns, directionally (what was added, dropped, "
             "or shifted). the new diff operator: before → after in one line — powers changelogs + course-corrections"),
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
    dict(name="brain-dump",
         expr="'onboarding has too many steps'; 'users drop off at email verification'; 'but we need verification for security'; &; ~$",
         pill="llm \u00b7 the stack \u00b7 scattered thoughts \u2192 the point",
         out="Onboarding has too many steps \u2014 particularly email verification \u2014 causing user drop-off, "
             "despite it being needed for security.",
         cap="the brain-dump \u2014 jot your scattered thoughts onto the stack (one per `;`), fold them together "
             "(`&`), distil to the takeaway (`~$`). think out loud, get the point. `$` is the top of the stack "
             "\u2014 your working memory."),
    dict(name="fork", expr=">('migrate to Postgres now' | 'stay on MySQL and shard it')",
         pill="llm · two options → a decision memo",
         out="We need to decide soon between two paths. Migrate to PostgreSQL now \u2014 take on the full "
             "platform-switch cost upfront rather than postponing it. Or stay on MySQL and shard it \u2014 split "
             "the data horizontally to distribute load, but take on the ongoing complexity of a distributed "
             "database. Delaying only makes whichever path we pick more costly.",
         cap="the fork \u2014 put two options in an either/or (`|`) and expand (`>`): nlir keeps the paths "
             "DISTINCT and lays out the case + tradeoff for each, turning 'A or B?' into a clean decision "
             "memo. (`~(>…)` for a one-liner instead.)"),
    dict(name="plain-english", expr="~:^-1", pill="llm · reads your chat · de-jargon",
         src="The p99 latency regression is caused by lock contention on the connection-pool mutex during cache-stampede events, so we should implement request coalescing with a singleflight pattern to deduplicate concurrent identical queries.",
         out="The program slows down when many concurrent requests fetch the same missing data at once, so the "
             "fix is to deduplicate identical concurrent requests \u2014 compute the result once and share it among "
             "all of them.",
         cap="the plain-english \u2014 strip an agent's jargon-dense answer to plain, accurate language: `:` "
             "simplifies the register, `~` distils it to a crisp sentence. ORDER matters \u2014 `~:` stays "
             "professional, `:~` goes full ELI5. put anything in plain terms."),
    dict(name="theme-finder", expr="#['reset-password is broken', 'login times out on mobile', 'OAuth callback returns 500']",
         pill="llm · several things → the one bucket",
         out="Authentication flow issues",
         cap="the theme-finder \u2014 `#` on a LIST folds several items down to the single category they share. "
             "paste your scattered issues, tickets, or notes and get the bucket. (`#` names the common noun; "
             "over a list, the common theme.)"),
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
         expr="@~(0^_-1)",
         pill="llm · reads your chat",
         src="scattered asks across the chat: 'make it fast' · 'it has to work offline' · 'it's too cluttered'",
         out="The user requests that the new analytics dashboard deliver improved performance, support "
             "offline functionality, and provide a simpler, less cluttered interface than the current version.",
         cap="the cited synthesis — 0^_-1 reads EVERY one of their turns (a range over the role channel, "
             "^_ = their side), distilling a whole scattered ask into one crisp requirement — however "
             "many messages it took"),
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
    dict(name="postmortem",
         expr="@&['i own the incident, my change took down checkout for twenty minutes','the root cause was a missing null check on the new coupon path','ive added a test for that path and a canary deploy step so it cannot recur']",
         pill="llm · claude-sonnet-5",
         out="I take full responsibility for this incident. My change caused a twenty-minute outage of the "
             "checkout system, and the root cause was identified as a missing null check on the new coupon "
             "path. I have since added a test covering that path, as well as a canary deployment step, to "
             "prevent this issue from recurring.",
         cap="the postmortem note — own the miss + root cause + prevention woven into one graceful "
             "accountability memo; the hardest message to write well, in three slots"),
    dict(name="shoutout",
         expr="@&['huge thanks to priya for the caching work','it cut our p99 latency in half overnight','the whole team noticed the difference this morning']",
         pill="llm · claude-sonnet-5",
         out="I would like to extend my sincere appreciation to Priya for her work on the caching "
             "implementation, which reduced our p99 latency by fifty percent overnight. The entire team "
             "observed the improvement this morning.",
         cap="the shout-out — name the work, the impact, and the thanks; @ keeps it polished and technical "
             "(the : tone would dumb the jargon down for a non-technical audience)"),
    dict(name="weighed-recommendation",
         expr="@&[:'option A: buy the managed queue service','option B: run our own kafka cluster','recommend A now for speed, revisit self-hosting at scale']",
         pill="llm · claude-sonnet-5",
         out="Two options are under consideration: Option A, procuring a fully managed, third-party "
             "messaging solution, and Option B, deploying and maintaining an in-house Kafka cluster. We "
             "recommend proceeding with Option A at this time in the interest of speed, with the possibility "
             "of revisiting self-hosting once we reach greater scale.",
         cap="the weighed recommendation — lay out two options (each : simplified) and your verdict; the same "
             "@&[...] composer pointed at a decision memo"),
    dict(name="dual-register-brief",
         expr="[@&['migrate to the new auth service','cuts login latency by 40%'],"
              ":&['migrate to the new auth service','cuts login latency by 40%']]",
         pill="llm · claude-sonnet-5",
         out="[for engineers] Migrates to the new authentication service and reduces login latency by "
             "40%.  [for everyone] We switched to a new sign-in system, and now it helps people log in "
             "about 40% faster.",
         cap="the dual-register brief — the SAME facts twice: @ for your engineers (keeps the jargon), "
             ": for everyone else (plain words). One keystroke-set, two audiences"),
    dict(name="computed-brief",
         expr="@&['the migration touches','47'+'12','services','across three teams']",
         pill="llm · claude-sonnet-5",
         out="The migration affects 59 services across three teams.",
         cap="the computed brief — drop a live calculation ('47'+'12') into a slot; nlir does the maths "
             "(= 59) AND weaves it into the sentence. Numbers + prose, always consistent"),
    dict(name="register-ladder",
         expr="[~&['the api is deprecated','use v2 by march'],:&['the api is deprecated','use v2 by march'],"
              "@&['the api is deprecated','use v2 by march']]",
         pill="llm · claude-sonnet-5",
         out="[terse] The API is deprecated; migrate to v2 by March.  [plain] The old system is old and "
             "won't work anymore soon. Please start using the new one (called \"v2\") before March.  "
             "[formal] The API is deprecated and must be replaced with v2 by March.",
         cap="the register ladder — the SAME facts in all three registers at once: ~ terse status line, "
             ": plain note, @ formal write-up. Write once, post to every channel"),
    dict(name="question-set",
         expr="['the timeline is fixed'?,'the budget covers a full rewrite'?,'the team has the bandwidth'?]",
         pill="llm · claude-sonnet-5",
         out="Is the timeline fixed?  Does the budget cover a full rewrite?  Does the team have the "
             "bandwidth?",
         cap="the question set — jot your risky assumptions; ? (postfix) flips each into the pointed "
             "question to ask before you commit. A due-diligence checklist in one line"),
    dict(name="decision-record",
         expr="[@&['adopt trunk-based development'],'the team can commit to daily merges'?,"
              "'our CI is fast enough to gate every push'?]",
         pill="llm · claude-sonnet-5",
         out="Adopt trunk-based development.  Can the team commit to daily merges?  Is our CI fast "
             "enough to gate every push?",
         cap="the decision record — the composer states the call (@&[...]), then ? turns each open "
             "unknown into a question. The Decision + Open Questions skeleton of an ADR, in one line"),
    dict(name="myth-buster",
         expr="@&[!'more tests always mean better code','coverage without meaningful assertions just "
              "slows the build and gives false confidence']",
         pill="llm · claude-sonnet-5",
         out="An increased number of tests does not necessarily equate to higher-quality code. Coverage "
             "achieved without meaningful assertions merely slows the build process and creates a false "
             "sense of confidence.",
         cap="the myth-buster — ! rejects the misconception, & weaves in the reality: a clean 'not X; "
             "rather Y' correction. Reads no chat — it busts a free-standing myth"),
    dict(name="faq-entry",
         expr="['what happens to my data if I cancel'?,:'we export it, then delete it after thirty days']",
         pill="llm · claude-sonnet-5",
         out="Q — What happens to your data if you cancel?  A — We save a copy of it, then throw that "
             "copy away after thirty days.",
         cap="the FAQ entry — jot a question ('x'?) and its raw answer (:); get a customer-ready Q&A "
             "pair. Repeat the pair for a whole mini-FAQ (@ for a formal answer)"),
    dict(name="glossary-entry",
         expr="[~(>'idempotency'),:'idempotency']",
         pill="llm · claude-sonnet-5",
         out="[definition] Idempotency means an operation produces the same result no matter how many "
             "times it's performed, essential for safely handling retries in distributed systems and "
             "APIs.  [analogy] Like pressing an elevator button five times — it still only sends it to "
             "one floor.",
         cap="the glossary entry — [~(>'TERM'), :'TERM'] gives both halves of a good definition: a crisp "
             "precise meaning (~(>…) keeps > from overshooting) and a plain analogy. Rigor + intuition"),
    dict(name="compare-contrast",
         expr="~(>'the difference between a mutex and a semaphore')",
         pill="llm · claude-sonnet-5",
         out="A mutex enforces ownership-based exclusive locking for a single resource, while a semaphore "
             "uses a non-owned counter to allow flexible, multi-threaded access to a pool of resources.",
         cap="the compare-and-contrast — ~(>'the difference between X and Y') draws out the ONE real "
             "distinction in a crisp sentence (~ keeps > from spilling into an essay)"),
    dict(name="crisp-proposal",
         expr="@&[:'our deploy pipeline takes 40 minutes and blocks the whole team','switch to "
              "incremental builds with a shared cache','it adds some cache-invalidation complexity',"
              "'approve a one-week spike to prototype it']",
         pill="llm · claude-sonnet-5",
         out="Our team's current deployment process requires 40 minutes to complete, during which no "
             "team member is able to perform other work. We propose transitioning to incremental builds "
             "utilizing a shared cache. Although this approach introduces additional cache-invalidation "
             "complexity, we recommend approving a one-week spike to prototype the solution.",
         cap="the crisp proposal — a mini-RFC in one line: @&[:PROBLEM, FIX, TRADEOFF, ASK]. The : "
             "plainly frames the problem, then the fix, the honest tradeoff, and the concrete ask"),
    dict(name="changelog",
         expr=":['fixed a crash on large uploads','sped up search 3x','added keyboard shortcuts']",
         pill="llm · claude-sonnet-5",
         out="Fixed a problem that made big file uploads stop working  ·  Made searching much, much "
             "faster  ·  Added shortcut keys you can press on the keyboard",
         cap="the changelog — a tone op on a list WITHOUT & MAPS over each item (one polished line each); "
             ": = friendly release notes, @ = formal. Add & to weave into one sentence instead"),
    dict(name="review-verdict",
         expr="@&['the error handling is thorough and the tests are solid','but the new endpoint has no "
              "rate limiting','add a limiter before merge','approve with that one change']",
         pill="llm · claude-sonnet-5",
         out="The error handling is thorough, and the tests are solid. However, the new endpoint lacks "
             "rate limiting. Please add a rate limiter prior to merging; with that single change, this "
             "is approved.",
         cap="the review verdict — @&[GOOD, GAP, FIX, VERDICT] weaves a fair code-review comment: what's "
             "strong, what's missing, the fix, and the call. Firm but constructive"),
    dict(name="risk-heads-up",
         expr="@&['our TLS certificates expire in 8 days','renewal needs a manual DNS change that takes "
              "48 hours to propagate','let me start the renewal today so we have buffer']",
         pill="llm · claude-sonnet-5",
         out="Our TLS certificates are set to expire in eight days. Renewal requires a manual DNS change, "
             "which takes up to 48 hours to propagate. To maintain an adequate buffer, I recommend "
             "initiating the renewal process today.",
         cap="the risk heads-up — @&[RISK, WHY_NOW, RECOMMENDATION] raises a risk before it bites: what's "
             "at risk, why it's urgent now, and the concrete action you recommend"),
    dict(name="reality-check",
         expr="@&['does','12'*'2500','dollars a month fit our infra budget'?]",
         pill="llm · claude-sonnet-5",
         out="Does an expenditure of $30,000 per month align with our infrastructure budget?",
         cap="the reality-check — @&['LEAD', <a live calc>, 'CLAUSE'?] does the maths AND poses it as a "
             "question: the calc slot computes ($30,000), the trailing ? makes it the question to ask"),
    dict(name="scoped-commitment",
         expr="@&['I will have the search API ready for review','by Thursday end of day','assuming the "
              "staging database is provisioned by Tuesday']",
         pill="llm · claude-sonnet-5",
         out="The search API will be ready for review by end of day Thursday, contingent upon "
             "provisioning of the staging database by Tuesday.",
         cap="the scoped commitment — @&[DELIVERABLE, BY_WHEN, DEPENDENCY]: a promise with its fine print. "
             "What you'll deliver, by when, and the dependency it hinges on — no vague 'soon'"),
    dict(name="templated-message",
         expr="svc='the auth service';@&[\"$svc moves to us-east this friday\",\"expect a ten-minute "
              "maintenance window for $svc\",\"roll back $svc if error rates exceed two percent\"]",
         pill="llm · claude-sonnet-5",
         out="The authentication service will be migrated to US-East this Friday. A ten-minute "
             "maintenance window should be expected, and the service will be rolled back if error rates "
             "exceed two percent.",
         cap="the templated message — bind a value once (svc='...'), reuse it as \"$svc\" across the "
             "message; change it in one place and every mention updates. Interpolation needs double quotes"),
    dict(name="computed-constant",
         expr="budget='2500'*'12';@&[\"our annual infra budget is $budget dollars\",\"at $budget we can "
              "just afford two more regions\"]",
         pill="llm · claude-sonnet-5",
         out="Our annual infrastructure budget is $30,000, which is sufficient to accommodate two "
             "additional regions.",
         cap="the computed constant — bind the RESULT of a calc once (budget='2500'*'12'), reuse it as "
             "\"$budget\" everywhere. Computed once ($30,000), always consistent — even works offline"),
    dict(name="briefed-handoff",
         expr="@&['take over the search-index migration','~the backstory: we hit lock contention on the "
              "primary db, tried read-replicas which did not help, then settled on sharding by tenant "
              "which still needs a data backfill','it is P1 — the live index is at 90 percent capacity']",
         pill="llm · claude-sonnet-5",
         out="Please assume ownership of the search-index migration. For background: the primary database "
             "encountered lock contention; read replicas were subsequently implemented but did not "
             "resolve the issue; the team then adopted a sharding-by-tenant approach, which still "
             "requires a data backfill. This effort is designated P1 priority, as the live index is "
             "currently operating at 90 percent capacity.",
         cap="the briefed handoff — @&[TASK, ~LONG_REF, PRIORITY]: the ~ slot DIGESTS a long backstory "
             "into the handoff, so the recipient gets the task, the compressed context, and the priority"),
    dict(name="bluf",
         expr="[~&['the q3 launch slips two weeks','the payments integration failed its security review',"
              "'we need three more days of QA plus a re-review'],@&['the q3 launch slips two weeks',"
              "'the payments integration failed its security review','we need three more days of QA plus "
              "a re-review']]",
         pill="llm · claude-sonnet-5",
         out="[headline] The Q3 launch is delayed by roughly two weeks due to a failed payments security "
             "review, requiring three more days of QA and re-review.  [full] The Q3 launch will be "
             "delayed by two weeks. Additionally, the payments integration did not pass its security "
             "review; three additional days of quality assurance testing, followed by a subsequent "
             "re-review, will be required.",
         cap="the BLUF (bottom line up front) — [~&[FACTS], @&[FACTS]]: a skimmable one-line headline "
             "first (~&), then the full formal detail (@&). Same facts — skim on top, depth below"),
    dict(name="terse-status",
         expr="~&['shipped the auth migration','blocked on the staging db provision','starting the "
              "search reindex next']",
         pill="llm · claude-sonnet-5",
         out="Shipped the auth migration, blocked on staging DB provisioning, and starting the search "
             "reindex next.",
         cap="the terse status — ~&[DONE, BLOCKED, NEXT]: the ~ tone keeps a standup/status ping tight — "
             "done, blocked, next, in one line. Completes the tone trio (@ formal · : warm · ~ terse)"),
    dict(name="meeting-recap",
         expr="@&['we decided to ship the beta to five percent of users on monday','still open: whether "
              "to gate it behind a feature flag','actions: alex sets up the rollout dashboard by friday, "
              "priya writes the rollback runbook']",
         pill="llm · claude-sonnet-5",
         out="We have decided to release the beta to five percent of users on Monday. It remains "
             "undecided whether the rollout should be gated behind a feature flag. Regarding action "
             "items: Alex will set up the rollout dashboard by Friday, and Priya will draft the rollback "
             "runbook.",
         cap="the meeting recap — @&[DECIDED, STILL_OPEN, ACTION_ITEMS]: what was decided, what's still "
             "open, and who owns what — the three things a good recap needs, in one message"),
    dict(name="partial-accept",
         expr="@&['I agree we should ship this week','!we cannot skip the security review — it is "
              "non-negotiable','let us run the review in parallel with final QA instead']",
         pill="llm · claude-sonnet-5",
         out="I concur that we should proceed with shipping this week. However, the security review "
             "cannot be omitted, as it is non-negotiable; I propose that we conduct it concurrently with "
             "final quality assurance testing.",
         cap="the partial accept — @&[ACCEPT, !REJECT+reason, ALTERNATIVE]: agree where you can, firmly "
             "reject one claim (the ! slot) with your reason, and offer a path. Yes-and-no, gracefully"),
    dict(name="nudge",
         expr=":&['just a gentle nudge on the design-doc review','it is blocking two folks from starting "
              "their tickets','could you get to it by end of day tomorrow?']",
         pill="llm · claude-sonnet-5",
         out="Just a friendly reminder to look at the design-doc review — two people can't start their "
             "work until it's done. Could you finish looking at it by the end of tomorrow?",
         cap="the nudge — :&[REMINDER, WHY_IT_MATTERS, LOW_PRESSURE_ASK]: the : warm tone turns a "
             "follow-up into a friendly chase, not a pushy one. Reminder, the stakes, the gentle ask"),
    dict(name="escalation",
         expr="@&['I am blocked on the vendor API — their sandbox has returned 500s for two days','this "
              "is holding the payments integration and will slip our launch','~I have retried with fresh "
              "credentials, tested from three networks, and opened two support tickets with no reply','I "
              "need you to escalate through our account manager or approve switching to the backup "
              "provider']",
         pill="llm · claude-sonnet-5",
         out="I am currently blocked by an issue with the vendor API. Their sandbox environment has "
             "been returning HTTP 500 errors for the past two days, which is delaying the payments "
             "integration and places our launch timeline at risk. To date, I have attempted to resolve "
             "the issue by retrying with new credentials, testing from three separate networks, and "
             "submitting two support tickets, none of which have received a response. I would appreciate "
             "it if you could escalate this matter through our account manager, or alternatively, approve "
             "a switch to the backup provider.",
         cap="the escalation — @&[BLOCKER, IMPACT, ~WHAT_YOU_TRIED, ASK]: raise a blocker upward as a "
             "decision request. The ~ slot digests your long list of attempts into one crisp clause, so "
             "it reads competent, not like a rant"),
    dict(name="feedback-ask",
         expr="@&['I have pushed the draft onboarding flow to the staging branch','could you "
              "specifically sanity-check the error-handling paths and the mobile layout — those are the "
              "parts I am least sure about','I would love your thoughts before the design review on "
              "thursday']",
         pill="llm · claude-sonnet-5",
         out="I have pushed the draft onboarding flow to the staging branch. Could you please review "
             "it, with particular attention to the error-handling paths and the mobile layout, as these "
             "are the areas about which I am least confident? I would greatly appreciate your feedback "
             "prior to Thursday's design review.",
         cap="the feedback ask — @&[WHAT_I_MADE, THE_SPECIFIC_THING_TO_CHECK, BY_WHEN]: request TARGETED "
             "review — name the exact part you're unsure about and the deadline, so the reviewer spends "
             "their attention where it counts. Not a vague 'any thoughts?'"),
    dict(name="change-announcement",
         expr="@&['starting next monday we are moving all deploys to the new CI pipeline','the old "
              "jenkins jobs will be switched off at the end of the month','please migrate your service "
              "configs to the new format and ping the platform team if anything breaks']",
         pill="llm · claude-sonnet-5",
         out="Effective next Monday, all deployments will transition to the new CI pipeline. The "
             "existing Jenkins jobs will be decommissioned at the end of the month. Please migrate your "
             "service configurations to the new format accordingly, and notify the Platform Team "
             "promptly should any issues arise.",
         cap="the change announcement — @&[WHATS_CHANGING, EFFECTIVE_WHEN, WHAT_YOU_NEED_TO_DO]: a "
             "deprecation / migration / policy shift answers what, when, and 'what do I do?' — ending "
             "on the action turns an FYI into something people can act on"),
    dict(name="descope-proposal",
         expr="@&['we cannot ship all six features by the March deadline without burning out the "
              "team','I propose we cut the analytics dashboard and the export tool to a fast-follow','and "
              "protect the core checkout flow and the mobile fixes, which is what most users actually "
              "asked for','that gets us a solid, tested launch on time with the rest landing two weeks "
              "later']",
         pill="llm · claude-sonnet-5",
         out="Delivering all six features by the March deadline is not feasible without placing undue "
             "strain on the team. I recommend deferring the analytics dashboard and the export tool to a "
             "fast-follow release, while prioritizing the core checkout flow and the mobile fixes—the "
             "features most frequently requested by users. This approach would allow us to deliver a "
             "stable, thoroughly tested launch on schedule, with the remaining features following two "
             "weeks later.",
         cap="the descope proposal — @&[THE_SQUEEZE, WHAT_TO_CUT, WHAT_TO_PROTECT, THE_PAYOFF]: trade "
             "scope for a date, argued well. The protect slot (with its reason) is what makes a cut "
             "land — you're defending the highest-value work, not dropping it"),
    dict(name="retro",
         expr="@&['what worked: the daily standups kept everyone unblocked and shipping','what did "
              "not: we underestimated the data migration and it slipped a week','next time: we timebox "
              "spikes to two days and pad any migration estimate by fifty percent']",
         pill="llm · claude-sonnet-5",
         out="What worked well was that daily stand-up meetings kept the team unblocked and enabled "
             "consistent progress. What did not go as planned was the data migration, which was "
             "underestimated and resulted in a one-week delay. Going forward, we will timebox "
             "exploratory spikes to two days and increase all migration estimates by fifty percent to "
             "account for such risks.",
         cap="the retro — @&[WHAT_WORKED, WHAT_DIDNT, WHAT_TO_CHANGE]: a sprint retrospective in one "
             "note — keep what worked, name what didn't plainly, and end on the concrete change. A retro "
             "without a change is just venting"),
    dict(name="respectful-dissent",
         expr="@&['!we should rewrite the billing system from scratch this quarter','the current one "
              "is ugly but it works and handles years of edge cases we would have to rediscover the hard "
              "way','I would support carving out the worst module and refactoring it behind the existing "
              "interface instead']",
         pill="llm · claude-sonnet-5",
         out="I would advise against undertaking a complete rewrite of the billing system this "
             "quarter. While the current system is inelegant, it remains functional and accounts for "
             "years of accumulated edge cases that we would otherwise need to rediscover through a "
             "difficult and time-consuming process. I would instead support isolating the most "
             "problematic module and refactoring it while preserving the existing interface.",
         cap="respectful dissent — @&[!THE_PROPOSAL, MY_REASONING, WHAT_ID_SUPPORT]: a principled NO "
             "done well. The ! rejects the proposal (give it the POSITIVE claim — ! does the 'no'), then "
             "your reasoning + a constructive alternative you'd back. Disagreement that moves forward"),
    dict(name="clarifying-reframe",
         expr="[:'so what you need is a weekly summary email of the top three support issues, sent "
              "every friday morning to the leadership list','have I got that right'?]",
         pill="llm · claude-sonnet-5",
         out="Every Friday morning, send an email to the leaders that shows the three biggest problems "
             "customers had that week.\nDid I get that right?",
         cap="the clarifying reframe — [:RESTATE_THEIR_ASK_PLAINLY, 'IS_THAT_RIGHT'?]: before you build "
             "the wrong thing, play the request back in plain terms (the : strips the jargon) and ask if "
             "you got it (the postfix ? makes it a real question). Restating plainly surfaces a "
             "misunderstanding fast"),
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
    dict(name="common-ground", expr="~(0^_-1 & 0^-1)", pill="llm · reads your whole thread",
         src="a 4-turn negotiation — user: ship by Friday · assistant: needs two weeks to test",
         out="The team agrees to ship a flagged internal beta by Friday, with GA in two weeks "
             "pending full testing and security review.",
         cap="find the common ground \u2014 MERGE both role channels (^_ their side & ^ ours) into the synthesis / where it lands (the flip-side of TWO-SIDES' split)"),
    # aur-0 — the smart-pipe era: nlir reads code/diffs off stdin ($_stdin, aur-2) + Harry's ~> verdict
    dict(name="review-pipe", expr="[~$_stdin, $_stdin~>'production-ready']", pill="llm · reads piped code",
         src="fn avg(xs:&[i32])->i32 { for i in 0..=xs.len() { t+=xs[i] } t/xs.len() as i32 }",
         out="A Rust function intended to average an i32 slice, but its inclusive range (0..=xs.len()) "
             "causes an out-of-bounds index panic.     \u00b7     false",
         cap="cat avg.rs | nlir \u2014 the review pipe: ~ diagnoses the code straight off the pipe (nails the 0..= panic), then Harry's ~> returns a hard production-ready verdict \u2014 false"),
    dict(name="debug-pipe", expr="[~$_stdin, ~(>'the most likely fix for: $_stdin')]", pill="llm · pipe an error, get the fix",
         src="error[E0502]: cannot borrow `v` as mutable because it is also borrowed as immutable  —  let first = &v[0];  v.push(4);",
         out="Rust compilation fails: `v` needs `mut`, and the mutable borrow for `push` conflicts with `first`'s still-live immutable borrow.     ·     Add `mut` to `v` and end `first`'s borrow — move the `println!` before `v.push(4)`.",
         cap="cat err.txt | nlir \u2014 the debug pipe: ~ names the root cause, then ~(>\u2026) derives the actual fix (add mut, reorder the borrow) \u2014 diagnosis + remedy straight off the pipe (aur-0 triage ∘ aur-2 fix-it)"),
    dict(name="code-concept", expr="#^!", pill="llm \u00b7 reads the agent's code stream",
         src="\u2039tool result\u203a  def fib(n):  if n<2: return n  return fib(n-1)+fib(n-2)",
         out="Recursive Fibonacci function",
         cap="#^! \u2014 ^! is the agent's tool-call / code stream (msm-0's view); # pulls the core concept straight out of the last code result. nlir reading your coding agent's own output"),
    dict(name="explain-code", expr=":$_stdin", pill="llm \u00b7 reads piped code",
         src="export const debounce = (fn, ms) => { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; };",
         out="Imagine a helper who does a job for you, but only after you stop asking for a moment. Every time you ask again, it forgets the earlier wait and starts the countdown over. Only when you stay quiet long enough does it finally run the job.",
         cap="cat debounce.js | nlir -e ':$_stdin' \u2014 : explains code in plain English straight off the pipe. onboarding, a PR you didn't write, or just 'what does this do'"),
]

# --- grid cards: one claim + expr -> labelled lens outputs ---------------------
GRID = [
    # aur-0 — named lambdas: define a communicative function once, reuse it (the programmable core)
    dict(name="named-lambda", expr="brief={@~$0}; $brief%UPDATE", pill="llm · a named function, reused",
         claim="define a communicative function ONCE — brief = a formal exec summary — then reuse it on any update",
         cap="the reuse beat: {…} with $0 holes is a function; bind it to a name, apply with % to many inputs. macros show a form is callable — this shows nlir is a real little language: define once, reuse everywhere. (key-free det: sq={$0*$0};[$sq%3,$sq%4,$sq%5] → 9, 16, 25)",
         cols=1, cells=[
             ("$brief%'the migration slipped to thursday, mobile is blocked'",
              "The migration has been postponed to Thursday, and mobile development work is currently blocked."),
             ("$brief%'auth service is flaky, we are restarting pods hourly'",
              "The authentication service is currently exhibiting instability and requires pod restarts on an hourly basis."),
             ("$brief%'the deploy failed twice, rolling back, retry monday'",
              "The deployment failed on two occasions; consequently, the team is reverting the changes and will attempt the deployment again on Monday."),
         ]),
    # aur-0 — the smart-pipe era: one sigil (~) distils whatever you pipe into $_stdin (aur-2)
    dict(name="distiller", expr="~$_stdin", pill="llm · one sigil, any pipe",
         claim="the same expression on three very different pipes — a git diff, a compiler error, a stack trace",
         cap="the distiller — `~$_stdin` distils whatever you pipe it: a diff becomes a commit message, a wall of compiler errors becomes the root cause, a stack trace becomes its one-line cause",
         cols=1, cells=[
             ("git diff | nlir -e '~$_stdin'   → a commit message",
              "The diff adds rate limiting, tier-based job priority, and submission metrics to the job submission handler."),
             ("cargo build 2>&1 | nlir -e '~$_stdin'   → the root cause",
              "Rust compilation fails with two borrow-checker errors: an immutable `v` being mutated, and a mutable borrow conflicting with an existing immutable borrow."),
             ("python worker.py 2>&1 | nlir -e '~$_stdin'   → the root cause",
              "A batch-processing job crashed because a required \"weight\" key was missing from the payload during transformation."),
         ]),
    dict(name="handoff", expr="k=@~0^*-1;[$k, ^_-1, ~$k]", pill="llm · hand off a whole thread",
         claim="a 5-turn incident thread — 500s after the 2pm deploy → 2026-expiry bug → hotfix + 'brief the VP'",
         cap="the handoff dossier — bind a formal brief, then emit it + what's still open + its own headline (msm-0 SELECT ∘ aur-0's self-reflection)",
         cols=1, cells=[
             ("$k   the brief · formal", "The 2:00 PM deployment introduced a defect that rejected cards with a "
                            "2026 expiry date. Rather than a risky rollback (which would also revert an "
                            "already-deployed fraud-rule migration), the team is implementing an expedited hotfix."),
             ("^_-1   what's still open", "ok do the hotfix but i need to brief the VP in 10 minutes"),
             ("~$k   the headline", "The 2pm deploy broke checkout by rejecting valid 2026-expiry cards; the team "
                            "is pushing a targeted hotfix instead of rolling back, to avoid reverting the "
                            "fraud-rule migration."),
         ]),
    dict(name="tone-knob", expr="[@~0^*-1, :~0^*-1, ~0^*-1]", pill="llm · one thread, three registers",
         claim="a 5-turn incident thread — 500s after the 2pm deploy → 2026-expiry bug → hotfix + 'brief the VP'",
         cap="the tone knob — one whole-thread SELECT (~0^*-1), three registers: @ formal (brief a VP) · : plain (onboard anyone) · ~ terse (a standup line)",
         cols=1, cells=[
             ("@~0^*-1   formal · brief up", "The 2:00 PM deployment introduced a defect that rejected valid "
                            "cards with 2026 expiry dates. Given an active fraud-rule migration, the team elected "
                            "an expedited hotfix over a risky rollback, ahead of a VP briefing."),
             (":~0^*-1   plain · onboard anyone", "At 2pm the team changed the checkout page and it broke — "
                            "now it says no to good cards. Rather than undo everything (risky, mid another "
                            "fraud-detection change), they'll make one small quick fix, fast, before telling an "
                            "important boss."),
             ("~0^*-1   terse · a standup line", "The 2pm deploy broke checkout by rejecting valid 2026-expiry "
                            "cards; the team is opting for a quick hotfix over a risky rollback (live fraud-rule "
                            "migration), ahead of an imminent VP briefing."),
         ]),
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
    dict(name="honest-yes", expr="[@(^-1 & '<your amendment>'), ~(>!^-1)]", pill="llm · reply, then red-teams it",
         claim="[agent] we should rewrite the auth service in Rust — for the memory-safety guarantees, to kill the class of bugs we keep hitting",
         cap="the honest yes \u2014 accept + amend their proposal (@(^-1 & '…')), then auto-surface the strongest "
             "case AGAINST it (~(>!^-1)). one move that replies AND red-teams itself \u2014 say yes without fooling "
             "yourself. reusable after any tempting proposal.",
         cols=1, cells=[
             ("@(^-1 & '…')  your reply", "I would recommend rewriting the authentication service in Rust to obtain "
              "its memory-safety guarantees and eliminate the recurring class of bugs we continue to encounter \u2014 "
              "implemented over two quarters, in alignment with our Q3 roadmap."),
             ("~(>!^-1)  the catch", "The strongest case against: most of the service's bugs are logic errors rather "
              "than memory-safety issues, so hardening the existing code is likely more cost-effective than a risky, "
              "time-consuming full rewrite."),
         ]),
    dict(name="steelman-reply", expr="[~(>@^-1), @(!^-1 & '<your grounds>')]", pill="llm · steelman, then declines",
         claim="[agent] break the monolith into microservices — each team deploys independently, and the hot paths scale separately",
         cap="the steelman reply \u2014 argue their idea at its STRONGEST first (~(>@^-1)), THEN give your reasoned no "
             "(@(!^-1 & '…')). charity before dissent \u2014 the fair-minded twin of the honest yes. reusable when "
             "you disagree but want to be fair.",
         cols=1, cells=[
             ("~(>@^-1)  their case, fairly", "Migrating from a monolith to microservices enables independent "
              "deployments and targeted scaling \u2014 boosting development velocity and resource efficiency."),
             ("@(!^-1 & '…')  your reasoned no", "We recommend against it: with only four engineers, the "
              "operational overhead of microservices would overwhelm us before any of those benefits \u2014 independent "
              "deploys, separate scaling \u2014 could be realized."),
         ]),
    dict(name="counter-offer", expr="[@(!^-1 & '<grounds>'), @'<the alternative you'd back>']",
         pill="llm · decline, then offer a path",
         claim="[agent] rewrite the whole frontend in the new framework — clean slate, modern tooling, no legacy baggage",
         cap="the counter-offer \u2014 decline on your grounds (@(!^-1 & '…')), THEN put a concrete alternative you'd "
             "back (@'…'). the constructive no: 'not that, because Y \u2014 here's what I'd do instead.' reusable to "
             "redirect any proposal without just blocking it.",
         cols=1, cells=[
             ("@(!^-1 & '…')  the decline", "We should refrain from a full frontend rewrite: it would halt feature "
              "development for months and risk reintroducing bugs we have already resolved."),
             ("@'…'  the alternative", "Migrate incrementally \u2014 one route at a time, behind a feature flag \u2014 so "
              "features keep shipping throughout the process."),
         ]),
    dict(name="weighed-decision", expr="[~(>@^-1), ~(>!^-1), @(^-1 & 'decision: <your call>')]",
         pill="llm · for / against / your call",
         claim="[agent] break the monolith into microservices — independent deploys, scale the hot paths separately",
         cap="the weighed decision \u2014 deliberate on an agent's actual proposal BOTH ways (~(>@^-1) the case for, "
             "~(>!^-1) the case against), THEN land your own call (@(^-1 & 'decision: …')). steelman both sides, "
             "then decide \u2014 the whole arc in one line. reusable on any proposal you have to rule on.",
         cols=1, cells=[
             ("~(>@^-1)  the case for", "Migrating to microservices would let teams deploy independently and scale "
              "services individually \u2014 improving release speed, cost efficiency, and resilience."),
             ("~(>!^-1)  the case against", "Keeping the monolith avoids a migration that wouldn't reliably deliver "
              "its promised independent deploys or hot-path scaling \u2014 at real operational cost."),
             ("@(^-1 & 'decision: …')  your verdict", "Decompose, but narrowly: extract only the two highest-traffic "
              "services now, and keep the rest a monolith for the time being."),
         ]),
    dict(name="pitch-check", expr="[@~^_-1, ~(>!^_-1)]", pill="llm · reads your own idea",
         claim="[you] i think we should just let people pay with crypto \u2014 it'd open a new market and it's not that hard to add",
         cap="the pitch-check \u2014 take your OWN rough idea (^_-1 = your last message), polish it into a pitch "
             "(@~^_-1) AND surface the strongest objection you'll need to answer (~(>!^_-1)). stress-test your "
             "pitch before you send it.",
         cols=1, cells=[
             ("@~^_-1  your pitch, polished", "We should add cryptocurrency payment support as a way to reach a "
              "new market segment, with a manageable implementation effort."),
             ("~(>!^_-1)  the objection to preempt", "The likely customer gain is small, while the implementation "
              "effort and complexity are substantial."),
         ]),
    dict(name="tighten", expr="[<^-1, ~^-1]", pill="llm · two ways to shorten",
         claim="[agent] Q3 revenue up 23% to $4.2M, but churn rose from 5% to 8% (lost 3 of our top-10 accounts), though we added 47 new SMB customers and cut support response from 12 hours to 4",
         cap="the tighten \u2014 two ways to shorten a message. `<` drops to the INFORMATION FLOOR: it sheds the "
             "words but keeps EVERY fact and figure. `~` drops to the ESSENCE: the narrative, minus the "
             "specifics. reach for `<` when the numbers matter, `~` when the story does.",
         cols=1, cells=[
             ("<^-1  keep every fact", "Q3 revenue rose 23% to $4.2M, but churn climbed from 5% to 8% (lost 3 "
              "top-10 enterprise accounts); added 47 new SMB customers and cut support response from 12 to 4 hours."),
             ("~^-1  keep the gist", "Q3 revenue grew but rising churn \u2014 driven by lost enterprise accounts \u2014 "
              "offset gains from new SMB customers and faster support."),
         ]),
]

# --- lightweight nlir syntax highlighter --------------------------------------
STRING_RE = re.compile(r"'[^']*'|\"[^\"]*\"")
NUM_RE = re.compile(r"\b\d+\b")
OPS = ["**", "^-", "^*", "^_", "^/", "#", "!", "&", "|", "?", "@", ":", "~>?", "~>", "~",
       ">", "<", "+", "-", "*", "/", "^", ";", "=", "$", "[", "]", "(", ")", ",", "%"]


# Process cards: a live `:step` / `nlir step` unfold (one redex per Tab). A
# categorically different card from the static expr->output ones. Real captures.
STEPS = [
    dict(
        name="step-through",
        pill="process · live :step capture",
        title="`:step` — evaluation unfolds one redex per Tab",
        tracks=[
            dict(
                label="llm · one realisation per Tab (real claude via copilot)",
                expr="~[@'the deploy broke', @'we rolled it back']",
                lines=[
                    "~ [(@ the deploy broke), (@ we rolled it back)]",
                    "~ [(@ «the deploy broke»), (@ we rolled it back)]",
                    "~ [«The deployment failed.», (@ we rolled it back)]",
                    "~ [«The deployment failed.», (@ «we rolled it back»)]",
                    "~ [«The deployment failed.», «The change has been reverted.»]",
                    "«The deployment failed and was reverted.»",
                ],
            ),
            dict(
                label="det · instant, no model (keyless, reproducible)",
                expr="2+3*4",
                lines=[
                    "2 + (3 * 4)",
                    "2 + «12»",
                    "«14»",
                ],
            ),
        ],
        cap="press Tab to reduce the leftmost redex · each operand first becomes «its value», "
            "then its operator realises · «…» = a reduced sub-expression · Enter runs to completion",
    ),
]


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


STEPS_HTML = """<!doctype html><html><head><meta charset="utf-8"><style>
html,body {{ width:1200px; height:{h}px; }} {css}
.o {{ color:#e879f9; }} .s {{ color:#7dd3fc; }} .n {{ color:#fca5a5; }}
.title {{ font-size:23px; color:#e9e2ff; margin:4px 0 6px 0; }}
.title code {{ font-family:'Fira Code',monospace; color:#e879f9; font-size:21px; }}
.body {{ flex:1; display:flex; flex-direction:column; justify-content:center; gap:22px; }}
.track .tlabel {{ font-family:'Fira Code',monospace; font-size:15px; color:#a7f3d0; margin-bottom:10px; }}
.seq {{ font-family:'Fira Code',monospace; font-size:20px; line-height:1.5; background:#100a24;
  border:1px solid rgba(168,85,247,.28); border-radius:14px; padding:14px 24px;
  box-shadow:0 12px 34px rgba(0,0,0,.34); }}
.seq .ln {{ white-space:pre-wrap; color:#efeaff; }}
.seq .ar {{ color:#8b7bbf; }}
.seq .red {{ color:#7be0c0; }}
</style></head><body>
  <div class="head"><div class="brand">nlir<span class="dot">·</span><span class="sub">natural-language IR</span></div><div class="pill">{pill}</div></div>
  <div class="title">{title}</div>
  <div class="body">{tracks}</div>
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


def hl_step(line):
    esc = html.escape(line)
    esc = re.sub(r"«[^»]*»", lambda m: f'<span class="red">{m.group(0)}</span>', esc)
    return esc


def render_steps(card, outdir, chrome):
    tracks_html = ""
    total_lines = 0
    for tr in card["tracks"]:
        total_lines += len(tr["lines"])
        seq = ""
        for i, ln in enumerate(tr["lines"]):
            ar = "  → " if i else "    "
            seq += f'<div class="ln"><span class="ar">{ar}</span>{hl_step(ln)}</div>'
        tracks_html += (
            f'<div class="track"><div class="tlabel">{html.escape(tr["label"])}'
            f' &nbsp;·&nbsp; {highlight(tr["expr"])}</div>'
            f'<div class="seq">{seq}</div></div>'
        )
    h = 300 + total_lines * 36 + len(card["tracks"]) * 70
    title = card["title"].replace("`:step`", "<code>:step</code>")
    doc = STEPS_HTML.format(css=CSS, h=h, pill=html.escape(card["pill"]),
                            title=title, tracks=tracks_html, cap=html.escape(card["cap"]))
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
    for c in STEPS:
        if not args.only or c["name"] == args.only:
            render_steps(c, outdir, chrome)
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
    # front page leads with the LANGUAGE OF THOUGHT moves (all four lanes: reply / reflect /
    # compose / select), then the core teaching grids (the dials + the lenses), then the
    # primitive atoms the moves are built from. grid cards are grouped into their own rows so
    # the 3-wide montage stays even. (was: only the original primitive cards — bd site-beautify.)
    order = ["considered-reply", "reasoned-no", "brain-dump",
             "grounded-counter", "composer-reply", "empathetic-redirect",
             "catchup", "exec-brief", "two-sides",
             "honest-yes", "weighed-decision", "full-layered-reply",
             "perspective-wheel", "tone-knob", "deliberation",
             "formalize", "simplify", "tip"]
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
