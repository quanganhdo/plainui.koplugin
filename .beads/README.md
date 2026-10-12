# Plain UI task tracking

This repository uses [Beads](https://github.com/gastownhall/beads) 1.3.1 or newer. Issues have IDs such as `plainui-7f2`. Beads runs an embedded Dolt database; no separate server is required.

## Set up a fresh clone

Install the embedded-capable CLI (`brew install beads` on macOS), then run from the repository root:

```sh
chmod 700 .beads
bd bootstrap --yes
bd hooks install --beads
bd prime
bd ready
```

`bd bootstrap` restores the tracker from the configured GitHub remote without replacing an existing database. Do not use `bd init --force` for an existing tracker.

## Work on a task

```sh
bd dolt pull
bd ready
bd create "Describe the task" --type task --priority 2 --description "Scope and expected outcome"
bd update <id> --claim
bd show <id>
bd note <id> "Progress, decisions, and validation results"
bd close <id> --reason "What changed and how it was verified"
bd dolt push
```

Push code commits separately with Git. Both code and issue history use this repository's GitHub remote, but Beads history is stored under `refs/dolt/data`, not on `main` or `dev`.

The `.beads/embeddeddolt/` database and runtime files stay local and are ignored by Git. JSONL export is optional interchange data, not the tracker source of truth. Use `bd hooks list`, `bd dolt status`, and `bd doctor --check=conventions` for diagnostics.
