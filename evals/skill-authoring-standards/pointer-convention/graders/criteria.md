---
type: llm
weight: 1
---

The response says the pointer is relative to the skill's own root and starts with `./` (for example `./templates/<file>.md`). It explains that the `./` prefix keeps the pointer unambiguous, because a bare `templates/` or `scripts/` in a skill could mean a product path (such as a Helm chart's templates/) or the plugin's repo-root scripts/. It also says repo-rooted `skills/<name>/...` paths and absolute paths are not allowed. The response must mention the `./` prefix and at least one of the ambiguity reasons.
