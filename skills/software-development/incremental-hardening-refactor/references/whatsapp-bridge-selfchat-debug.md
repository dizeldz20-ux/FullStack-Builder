# WhatsApp Bridge Self-Chat Mode Debugging

## Problem

The WhatsApp bridge in self-chat mode was rejecting messages from the user's own phone when they sent to themselves. The `/messages` endpoint returned empty arrays even though the bridge was connected.

## Root Cause

1. Self-chat messages (user sends to their own number) arrive with `fromMe: false` from WhatsApp's perspective
2. The bridge's self-chat logic checked `if (normalizedChatId === normalizedSenderId)` but the allowlist check still ran afterward
3. This caused messages to be rejected with `self_chat_mode_rejects_non_self` or `allowlist_mismatch`

## The Fix (bridge.js)

Two patches were applied to `/root/.hermes/hermes-agent/scripts/whatsapp-bridge/bridge.js`:

### Patch 1: Skip allowlist for self-chat

```javascript
if (!msg.key.fromMe) {
  if (WHATSAPP_MODE === 'self-chat') {
    const normalizedChatId = normalizeWhatsAppId(chatId);
    const normalizedSenderId = normalizeWhatsAppId(senderId);
    if (normalizedChatId === normalizedSenderId) {
      // This is a self-chat message - accept it and skip allowlist check
    } else {
      // Reject non-self messages in self-chat mode
      continue;
    }
  } else if (!matchesAllowedUser(...)) {
    // Normal allowlist check for non-self-chat mode
    continue;
  }
}
```

### Key insight

The `normalizeWhatsAppId` function converts:
- `972552428841:15@s.whatsapp.net` → `972552428841@s.whatsapp.net`
- `214057512640546:15@lid` → `214057512640546@lid`

WhatsApp now uses LID (Linked Identity Device) format - the user's number appears in two formats:
- Classic: `972528420038@s.whatsapp.net`
- LID: `165025696215068@lid`

## Verification

1. Check bridge status: `curl http://127.0.0.1:3000/health`
2. Enable debug logging: `WHATSAPP_DEBUG=1 node bridge.js`
3. Check messages: `curl http://127.0.0.1:3000/messages`
4. The debug log shows: `{"event":"upsert","type":"notify","fromMe":false,"chatId":"165025696215068@lid",...}`

## Session Details

- Date: June 2025
- User: the user Maimon (972528420038)
- LID: 165025696215068@lid
- Fixed in: bridge.js lines 292-323