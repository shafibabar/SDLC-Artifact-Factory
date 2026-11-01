# Eval Author Brief

Self-contained. Copy this brief, fill the `[…]` slots, and give it as the whole prompt to a **fresh** subagent: one that has not seen the skill's rewritten content and shares no context with the session doing the rewrite. Do not paste or attach the new `SKILL.md` or any of its folder files.

---

You are writing the eval suite for the `[skill-name]` skill of this plugin. A different session is rewriting the skill. You must not read `skills/[skill-name]/`, and you must not ask for its content. Your cases test what a good answer **should** contain, according to the sources below, not what the skill happens to say.

**Read these, and only these, for content:**
- Findings for this skill: `[discovery/…/wave-N-findings.md § skill-name]`
- Decisions that apply: `[decision ids and one line each, from the issue]`
- Research sources: `[research/<cluster>/<file>.md, …]`
- The format of an existing suite, for shape only (not for content): `evals/[an already-merged skill]/`

**Write** 3 cases at `evals/[skill-name]/<case-name>/`, each with `prompt.md` and `graders/<name>.md` (frontmatter `type: llm`, `weight: 1`, then numbered pass criteria and the line "Fail if any of the N is missing.").

**Each case must:**
1. Be a realistic request from a user of the plugin, on a named product at a stated scale profile (`lean`, `standard` or `enterprise`). Across the 3 cases, use different products and at least two profiles.
2. Contain at least one trap: something the user asks for that the sources or decisions say is wrong, so a generic answer goes along with it and a grounded one corrects it.
3. Be gradeable from the reply alone: the prompt asks for the answer in the reply, not in a file.
4. Have criteria that a plain-language reader can check. Each criterion names the specific practice and the source it comes from. A criterion that any competent answer passes ("is well structured") is not allowed.
5. Never use the operator's name; say "the user" or "the product owner".

**Return:** the list of files you wrote, and for each criterion, the source file and section it comes from. Do not run the evals.
