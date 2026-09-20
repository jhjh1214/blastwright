# Monetization

**Status: not implemented (Phase 10).** Nothing here is built. No product IDs exist; none are invented.

## Principles
Free players get the complete game. Purchases save time or add cosmetics. Server-side only: `MarketplaceService.ProcessReceipt` is the sole grant path, with idempotency via the profile's `Purchases` list (already reserved in the save schema).

## Planned ladder
| Tier | Idea |
|---|---|
| Tiny | Cosmetic blast color |
| Small | Shard boost pack (Developer Product) |
| Medium | Extra rig slot / Auto-collect (Gamepass) |
| Large | Starter bundle |
| Premium | Founder pack |

## Rules
- Product IDs live in a config module and stay `nil` until the developer supplies them. The UI must show "unavailable" rather than crash.
- Never grant based on a client message.
