# Plain UI development

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision. Keep the local index out of commits.
<!-- CODEGRAPH_END -->

## Task tracking

Use Beads (`bd`, version 1.3.1 or newer) for development tasks. Run `bd prime` at the start of a session and after context compaction.

- Run `bd ready --json` and review the relevant issue with `bd show <id>`.
- Create an issue for new work with a clear description and acceptance criteria, then claim it with `bd update <id> --claim`.
- Record decisions, remaining work, and validation results on the issue. Use dependencies for blocked work.
- Close completed work with `bd close <id> --reason "..."`.

Issues use the `plainui-` prefix. The embedded Dolt database is local; synchronize issue history separately from code with `bd dolt pull` and `bd dolt push`. The remote is the same GitHub repository, under `refs/dolt/data`.

For a fresh clone, run `chmod 700 .beads`, `bd bootstrap --yes`, then `bd hooks install --beads`. Do not reinitialize an existing tracker or commit its database files. See `.beads/README.md` for the command sequence.

Commit and push within the user's authorized scope. When publishing development work, push both the code branch and the Beads history; report any sync failure rather than claiming the work is fully published.

## Validation

Run `lua tests/run.lua` for Lua behavior changes. For packaging changes, build and verify a ZIP:

```sh
python3 scripts/build_release.py /private/tmp/plainui.koplugin-check.zip
python3 tests/check_release.py /private/tmp/plainui.koplugin-check.zip
```

Test UI changes in the native KOReader emulator with a separate demo library. Use Standard Ebooks titles for documentation screenshots and sample statistics instead of personal reading data.

Run shell commands directly using the underlying tools.
