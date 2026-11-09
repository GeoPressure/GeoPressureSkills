# GeoPressureSkills

Agent skills for the [GeoPressure](https://geopressure.org) tools. They let an AI agent (Claude Code,
or any agent that reads `SKILL.md` skills) help with multi-sensor geolocator data: run an analysis
from raw logger files, answer questions about GeoPressureR and the method, fix errors, and share data
as GeoLocator Data Packages.

| Skill | For |
|---|---|
| `geopressure` | Anyone using the GeoPressure tools: analysis, questions, method, data sharing and reuse |
| `geopressure-dev` | Developers of the GeoPressure repos: the shared standard (`standards.md`, copied into each repo's `AGENTS.md`), release order, carrying a change across repos, and checking the docs against the release |

## Install

Users need only `geopressure`. `geopressure-dev` is for people developing the GeoPressure repos.

**Claude Code** (the CLI, or the Code tab of the Claude desktop app):

```
/plugin marketplace add GeoPressure/GeoPressureSkills
/plugin install geopressure@geopressure
```

Developers add `/plugin install geopressure-dev@geopressure`. Update later with
`/plugin marketplace update geopressure`.

**Claude.ai or the Claude desktop chat:** download `geopressure.zip` from the
[latest release](https://github.com/GeoPressure/GeoPressureSkills/releases/latest), then go to
[claude.ai/customize/skills](https://claude.ai/customize/skills), click **+**, **Create skill** and
**Upload a skill**. Code execution must be on. Upload a new zip to update.

**Other agents** that read `SKILL.md` skills: copy `plugins/geopressure/skills/geopressure/` to the
folder your agent reads skills from.

The full analysis needs an agent that can run R on your computer, with internet: Claude Code is the
best fit. In a chat without R, the skill still answers questions and writes the scripts for you to
run. A project created from GeoPressureTemplate also carries its own `AGENTS.md`, which guides any
agent through the analysis, with or without this skill.

## Release

Tag `vX.Y.Z`, bump `version` in both `plugins/*/.claude-plugin/plugin.json`, and attach the
claude.ai zip to the GitHub release, built without the test cases:

```bash
cd plugins/geopressure/skills && zip -r ../../../geopressure.zip geopressure -x "geopressure/evals/*"
```

## How the skills are written

- **The repos hold the facts; the skills hold the know-how.** Function arguments, the method,
  examples and changes between versions live in the package sites, the GeoPressureManual, the
  GeoPressureTemplate, each package's NEWS and the papers. A skill says where each kind of answer
  lives and how to work with the user. It does not copy those facts, so it does not go stale when the
  tools change.
- **Know-how tied to one repo lives in that repo.** For example, how an agent runs a study project
  is in the GeoPressureTemplate's `AGENTS.md`, so it changes with the template.
- **Real questions test the skill.** Each skill has an `evals/` folder of realistic requests with
  what a good answer contains. Add a case whenever a question goes badly; if the failure was a
  missing fact, fix the docs, not the skill. Run them from the skill folder (`plugins/<plugin>/skills/<skill>/`) with
  `claude plugin eval . --allow-tools Write,Edit,Bash --scaffold` (real, billed model runs).
