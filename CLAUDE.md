# CLAUDE.md

## Status
Phase 0/1: repo scaffolded; concept proposal awaiting user approval. No game code yet.

## Environment
Windows, PowerShell. Rojo 7.7.0 at C:\Tools\Rojo. Studio installed. No Luau linters installed.
Roblox web APIs reachable (Creator Store toolbox endpoint returned 200).

## Rules (project)
- Rojo is the source of truth; no logic only in Studio.
- Server-authoritative; validate all remotes. Purchases only via ProcessReceipt.
- Never invent asset or product IDs; register external assets in docs/ASSET_REGISTRY.md.
- Strip scripts from third-party models.
- Commits: Conventional Commits, no co-author/tool attribution (user's global rule).

## To be filled after concept approval
Concept, architecture, conventions, decisions, known issues, manual actions.
