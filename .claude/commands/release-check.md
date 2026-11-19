---
description: Check version consistency and release readiness
---
Use the `release-installers` skill: verify the version string matches across all files it lists, that CI on `dev` is green (`gh run list --branch dev --limit 3`), and summarise what a release would publish. Do not tag or push.
