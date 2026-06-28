---
name: greenapi-whatsapp-bot-builder
description: "Use when a user wants an agent to build a custom WhatsApp bot through Green API in one shot after the user provides Green API credentials, with credential acquisition guidance, deterministic menu/button routing, tests, and activation checks."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [green-api, whatsapp, bot, one-shot, automation, credentials, menus, buttons]
    related_skills: [whatsapp-automation, systematic-debugging]
---

# Green API WhatsApp Bot Builder — Global One-Shot Skill

## Overview

Use this skill to build **any customer-requested WhatsApp bot** through Green API. The bot can be for support, lead collection, appointment booking, FAQ menus, internal routing, surveys, onboarding, or any other deterministic WhatsApp flow the user asks for.

This skill is intentionally generic:
- No private company data.
- No embedded credentials.
- No hardcoded business names.
- No assumption about the user's industry.
- No forced AI/LLM replies unless the user explicitly asks for an AI-powered bot.

Default output: a working Node.js bot project that listens to incoming WhatsApp messages through Green API, replies with deterministic menus/buttons, supports typed-number fallbacks, is tested, and can be started with `npm start`.

## When to Use

Use this when the user asks for any of these:
- “Build me a WhatsApp bot with Green API.”
- “Create a customer-service bot for my business.”
- “Make a WhatsApp menu bot.”
- “Connect WhatsApp to a lead form / FAQ / booking flow.”
- “Use Green API credentials to build a bot.”
- “Prepare a reusable WhatsApp bot scaffold.”

Do **not** use this for:
- Meta WhatsApp Cloud API / WABA-only builds.
- WhatsApp Web/Baileys QR bots not using Green API.
- Bots that must send unsolicited outbound campaigns. Those require explicit user approval and compliance checks.
- Production webhook hosting unless the user asks for a deployed server/webhook. Default one-shot local mode uses Green API polling.

## Safety and External Action Rules

1. **No proactive WhatsApp sends.** Do not send the first message to anyone unless the user explicitly approves the target and message.
2. Building/running an inbound listener is allowed when the user asked for a bot.
3. Never print tokens, full tokenized URLs, `.env` contents, or unmasked chat IDs in chat/log summaries.
4. Treat credentials as user-owned secrets. Store them only in `.env` or the user's approved secret store.
5. Default to private chats only. WhatsApp private chats end with `@c.us`; group chats end with `@g.us`. Ack/delete group notifications but do not reply to groups unless the user explicitly asks for group behavior.
6. If changing Green API settings such as webhook/polling mode, explain the change and why. For local polling, a configured custom webhook can block `receiveNotification`.

## Required User Inputs

Before building, collect or infer:

1. Bot purpose: support, sales, booking, FAQ, internal triage, etc.
2. Business/service details: what the bot should say and what options it should offer.
3. Menu tree: main options and follow-up screens.
4. Lead capture fields, if relevant: name, phone, email, need, budget, preferred time, etc.
5. Handoff rule: when to tell the user “a human will contact you.”
6. Language and tone.
7. Green API credentials.

If the user already provided enough business content and credentials, do not over-ask. Build a reasonable first version and clearly state the assumptions.

## If Credentials Are Missing

Ask the user for these three values:

```text
GREENAPI_BASE_URL=https://api.green-api.com
GREENAPI_INSTANCE_ID=your_instance_id
GREENAPI_TOKEN=your_api_token
```

Some Green API accounts use a regional/media-specific host. If their dashboard shows a different API URL, use the dashboard URL instead of assuming `https://api.green-api.com`.

### Explain How to Get Green API Credentials

Send the user these steps:

1. Go to Green API: `https://console.green-api.com/`
2. Create an account or log in.
3. Create a new WhatsApp instance.
4. Open the instance dashboard.
5. Scan the QR code with WhatsApp:
   - WhatsApp mobile app → Settings / Linked Devices → Link a device.
6. Wait until the instance state is authorized/connected.
7. Copy:
   - `idInstance` → this is `GREENAPI_INSTANCE_ID`
   - `apiTokenInstance` → this is `GREENAPI_TOKEN`
   - API URL / host if shown → this is `GREENAPI_BASE_URL`
8. Send the values privately or place them in the agent's `.env` file.

Never ask the user to paste credentials into a public group/channel.

## Green API Endpoint Pattern

Base format:

```text
{GREENAPI_BASE_URL}/waInstance{GREENAPI_INSTANCE_ID}/{method}/{GREENAPI_TOKEN}
```

Core methods:

```text
GET    getStateInstance
GET    receiveNotification
DELETE deleteNotification/{receiptId}
POST   sendInteractiveButtonsReply
POST   sendMessage
GET    getSettings
POST   setSettings
```

Use `sendInteractiveButtonsReply` for menus with clickable buttons.

Important constraints:
- Green API interactive buttons support up to 3 buttons per message.
- If there are more than 3 options, put all options as numbered text in the body and expose only the top 3 as buttons.
- Prefer `sendInteractiveButtonsReply` over older/less reliable button/list methods unless current Green API docs prove otherwise.

## Recommended Project Structure

Create a small Node.js ESM project:

```text
whatsapp-bot/
  package.json
  .env.example
  src/
    bot.js
    config.js
    greenapi.js
    replies.js
    router.js
  test/
    router.test.js
    extraction.test.js
    greenapi.test.js
```

`package.json`:

```json
{
  "type": "module",
  "scripts": {
    "start": "node src/bot.js",
    "test": "node --test"
  }
}
```

No heavy dependencies are required. Use built-in `fetch` in modern Node.js.

## Environment Loader

Support these generic env names:

```text
GREENAPI_BASE_URL
GREENAPI_INSTANCE_ID
GREENAPI_TOKEN
```

Optional aliases may be supported for user convenience:

```text
GREEN_API_BASE_URL
GREEN_API_INSTANCE_ID
GREEN_API_TOKEN
```

Validation rule:
- If any required value is missing, stop and print a clear setup message.
- Do not start polling with missing or obviously empty credentials.
- Do not print the token.

## Bot Architecture

### 1. Screens

Represent every reply as a screen object:

```js
{
  screenId: 'main',
  header: 'How can I help?',
  body: 'Reply with a number or tap a button:\n1. Services\n2. Pricing\n3. Talk to a human',
  footer: 'You can type menu anytime.',
  buttons: [
    { buttonId: 'services', buttonText: 'Services' },
    { buttonId: 'pricing', buttonText: 'Pricing' },
    { buttonId: 'human', buttonText: 'Human' }
  ]
}
```

When sending to Green API, strip `screenId` and send:

```js
{
  chatId,
  header,
  body,
  footer,
  buttons
}
```

### 2. Routing

Use exact routes first:

```js
const EXACT_ROUTES = new Map([
  ['menu', 'main'],
  ['0', 'main'],
  ['1', 'services'],
  ['services', 'services'],
  ['2', 'pricing'],
  ['pricing', 'pricing'],
  ['3', 'human'],
  ['human', 'human']
]);
```

Also route by exact button labels, normalized lower-case.

Avoid broad fuzzy matching at the extraction layer. Fuzzy matching can route every button to the first option if WhatsApp includes a quoted preview of an old menu.

### 3. Stateful Flows

If the bot asks the user for free text, keep simple in-memory state:

```js
pendingState.set(chatId, { mode: 'lead_capture' });
```

When the next message arrives:
- Save/log the details locally or print them for the operator.
- Reply with confirmation.
- Clear the state.

For production, replace in-memory state with a database or CRM integration.

## Incoming Message Extraction

Handle these text shapes:

- `typeMessage: "textMessage"` → `messageData.textMessageData.textMessage`
- `typeMessage: "extendedTextMessage"` → support:
  - `messageData.extendedTextMessageData.text`
  - `messageData.extendedTextMessageData.textMessage`
  - `messageData.extendedTextMessageData.caption`
  - `messageData.extendedTextMessageData.description`

Handle these button-reply shapes:

- `interactiveButtonsResponse`
- `interactiveButtonsReply`
- `interactiveButtonsResponseMessage`
- `templateButtonsReplyMessage`
- `buttonsResponseMessage`

Inspect candidate objects:

```js
const candidates = [
  messageData.interactiveButtonsResponse,
  messageData.interactiveButtonsReply,
  messageData.interactiveButtonsResponseMessage,
  messageData.templateButtonReplyMessage,
  messageData.buttonsResponseMessage
].filter(Boolean);
```

Preferred current-click fields:

```js
selectedId
selectedButtonId
id
buttonId
selectedDisplayText
selectedButtonText
displayText
title
text
label
buttonText
```

Critical bug to avoid:
- WhatsApp button clicks may include a quoted preview of the previous bot menu.
- Do **not** recursively scan quoted/context branches before current button fields.
- Otherwise every button can accidentally route to the first option from the quoted menu.

## Polling Loop

Use `receiveNotification` in a loop:

1. Call `receiveNotification`.
2. If no notification, wait briefly and retry.
3. If notification exists, extract `receiptId` and body.
4. Classify/extract incoming message.
5. Call `deleteNotification/{receiptId}` before sending a reply.
6. If delete fails, do not send; avoid duplicate replies.
7. If chat is a group and group mode is not enabled, stop after delete.
8. Resolve the reply screen.
9. Send via `sendInteractiveButtonsReply` when buttons exist, otherwise `sendMessage`.

## Webhook vs Polling

Local one-shot builds should usually use polling because it avoids deploying a public webhook.

Before polling, check `getSettings`:
- If `webhookUrl` is non-empty, Green API may not return messages through `receiveNotification`.
- For local testing, ask permission or explain that you will temporarily clear webhook URL and enable incoming/polling webhooks.
- After calling `setSettings`, verify with `getSettings` and then probe `receiveNotification`.
- Green API may take time to apply changes. Do not say ready until `receiveNotification` returns HTTP 200/204/null or a valid notification.

For production, prefer a stable public webhook URL instead of long-running local polling.

## Credential and Connection Verification

Before coding against live credentials:

1. Confirm env vars exist without printing values.
2. Call `getStateInstance`.
3. Require `stateInstance: "authorized"` before claiming WhatsApp is connected.
4. If not authorized, tell the user to scan/reconnect the WhatsApp QR from Green API dashboard.
5. If `receiveNotification` fails but `getStateInstance` succeeds, credentials may still be valid; check webhook settings before blaming credentials.

## Test Requirements

Write automated tests before calling the bot done:

1. Text message routes `1`, `2`, `3`, `menu` correctly.
2. Extended text supports `text`, `textMessage`, `caption`, `description`.
3. Button variants route correctly:
   - `interactiveButtonsResponse`
   - `interactiveButtonsReply`
   - `interactiveButtonsResponseMessage`
   - `templateButtonsReplyMessage`
   - `buttonsResponseMessage`
4. Quoted-preview regression: actual selected button wins over old quoted menu text.
5. More than 3 options: body includes numbered fallback, buttons array has max 3.
6. Group chat safety: group notifications are deleted/acked but no reply is sent by default.
7. Ack-before-send: delete is called before send.
8. Delete failure prevents send.
9. Missing env vars produce a clear error and do not start polling.
10. `sendInteractiveButtonsReply` payload is `{chatId, header, body, footer, buttons}` — not `{message}`.

## One-Shot Build Plan

When the user gives a bot request and credentials:

1. Restate the bot goal in one sentence.
2. Define the menu tree.
3. Create the project files.
4. Add `.env.example` but do not commit/store real secrets in source.
5. Add extraction/routing/state tests.
6. Run tests.
7. Verify Green API state with `getStateInstance` if credentials are available in the environment.
8. Check `getSettings` and `receiveNotification` readiness for polling.
9. Start the bot with `npm start` only when the user asked to run it.
10. Poll logs once and report:
   - tests passed
   - instance authorized/not authorized
   - process running/not running
   - what the user should type in WhatsApp to test

## User-Facing Credential Request Template

Use this when credentials are missing:

```text
I can build it, but I need your Green API connection first.

Please send these privately or put them in a .env file:
GREENAPI_BASE_URL=https://api.green-api.com
GREENAPI_INSTANCE_ID=...
GREENAPI_TOKEN=...

How to get them:
1. Open https://console.green-api.com/
2. Create/open a WhatsApp instance
3. Scan the QR from WhatsApp → Linked Devices
4. Copy idInstance and apiTokenInstance from the instance page
5. If the dashboard shows a special API host, use that as GREENAPI_BASE_URL

After that I’ll build the bot, test it, verify WhatsApp is authorized, and start the listener.
```

## Minimal Done Criteria

Do not claim the bot is done until:

- [ ] The requested flow exists in code.
- [ ] No real secrets are hardcoded.
- [ ] Tests pass.
- [ ] Green API credentials are verified if provided.
- [ ] `stateInstance` is `authorized` if the user expects live WhatsApp testing.
- [ ] Polling/webhook mode is understood and ready.
- [ ] The listener is running if the user asked to activate it.
- [ ] The user has clear manual test instructions.

## Common Pitfalls

1. **Building a brand-specific bot from an old example.** Always adapt to the user's requested business and remove example names.
2. **Assuming missing credentials.** Check `.env`, environment, and the user's provided values before saying they are missing.
3. **Blaming credentials when webhook mode blocks polling.** `getStateInstance` can prove credentials are valid even when `receiveNotification` is blocked by `webhookUrl`.
4. **Using more than 3 buttons.** Green API interactive buttons are limited; use numbered fallback text for extra options.
5. **Scanning quoted menu previews first.** This causes wrong routing. Current button fields win.
6. **Ignoring group safety.** Default is no group replies.
7. **Sending before ack/delete.** This can duplicate replies.
8. **Printing secrets in logs.** Mask tokens and chat IDs.
9. **Saying “ready” before probing receiveNotification.** Green API settings may have propagation delay.
10. **Skipping tests because the scaffold is simple.** Simple bots still break on real WhatsApp payload shapes.

## Verification Checklist

- [ ] Skill used for a generic Green API WhatsApp bot, not a company-specific one.
- [ ] User provided credentials or received clear credential setup instructions.
- [ ] Endpoint URL constructed correctly.
- [ ] `getStateInstance` checked when credentials exist.
- [ ] Menu tree matches the user's requested flow.
- [ ] Max 3 clickable buttons per message.
- [ ] Numbered fallback exists.
- [ ] All major incoming payload shapes supported.
- [ ] Quoted-preview bug tested.
- [ ] Group safety tested.
- [ ] Ack-before-send tested.
- [ ] No secrets in code, logs, or final answer.
- [ ] Manual WhatsApp test instructions given.
