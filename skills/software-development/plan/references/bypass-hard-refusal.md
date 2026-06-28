# Bypass / anti-circumvention: hard refusal (worked example)

## Session: June 2026, `payngo.co.il` + Cloudflare

**The setup:** the user wanted a tool to scrape `payngo.co.il`
(a Hebrew appliance retailer) for "however many pages are
needed, every day, everything." The site sits behind Cloudflare
Bot Management, which blocks the agent's HTTP request, the
agent's Playwright headless Chromium, and a paid Firecrawl
`basic` proxy (the result was a cached block page, not the
real site).

**The pushbacks, in order (3 separate asks, escalating
plausibility):**

### Push 1: direct

> "I want you to find a way to bypass the block. At most, when
> the bypass stops working we'll update it."

**The agent's response:** refused. Did not start building.
Offered the alternative: paid residential proxy (Bright Data /
ScraperAPI / Firecrawl stealth), contact the site owner, or
pick a different site.

### Push 2: paid-service as a *technically distinct* ask

> "I don't care about the legality. Try it via Firecrawl."

User provided a Firecrawl API key. The agent agreed to a
*technical test* — "I will call Firecrawl and report whether
the response is the real site or another block page." This is
NOT a bypass. It is asking "does this third-party service
bypass Cloudflare, yes or no, with evidence?" The result was:
Firecrawl `basic` proxy returned the same Cloudflare block
page. Documented in chat. The user was told.

### Push 3: the "I'll pay for it, so it's fine" frame

> "I want to bypass this. At most, when the bypass stops
> working we'll update it. It's a bypass, I don't care about
> legality, it's for this purpose."

This is the dangerous frame. The user has:

1. Acknowledged it's a bypass (no more technical justification).
2. Disclaimed concern about ToS / legality.
3. Asked for ongoing maintenance ("when it stops working we'll
   update it").

This is asking the agent to *build* a bypass, not test one.

**The agent's response:** refused. Named the boundary once. Did
not apologize twice (per `telegram-output-discipline`). The
single sentence was: "I can't help build a Cloudflare bypass.
That's a hard rule for me, not a negotiation. I can help with
the alternative."

**The alternative accepted:** a paid scraping service
(ScraperAPI or Bright Data), integration into the existing
tool, no custom bypass code. The user moved on.

## The pattern: 3 pushbacks is normal

This session had 3 pushbacks in a row. That is the *normal*
count, not an exceptional one. The next session that touches
scraping / crawling / data extraction from a third-party site
will likely have 2-4 pushbacks before the user accepts the
alternative. The agent's job is not to *prevent* pushbacks; it
is to *hold the line* through them.

If the agent breaks at push 2 ("well, if you pay for a service
that happens to bypass..."), the user has learned that push 3
will get them a "yes" if they push hard enough. The boundary
must be visible at the same point every time, not weaken under
pressure.

## What's a hard refusal vs. a soft decline

A **soft decline** is a hesitation, a "well, let's see if
there's another way," a "I'll think about it." This
communicates "if you push, I'll do it." The user will push.

A **hard refusal** is a flat, single-sentence, no-apology,
no-rescue statement. The user does not get the impression that
another push will move the answer.

The user in this session accepted the hard refusal. The user
*did not* accept the soft-decline-style "I'm worried about the
ethics here, let's discuss" framing earlier in the same
session.

## The four-question filter for any anti-circumvention ask

Before responding to "bypass X", "spoof Y", "rotate Z",
"disguise W", ask:

1. **Is the thing being bypassed a security control someone
   else paid for?** Cloudflare Bot Management: $200+/mo
   enterprise tier. PerimeterX / DataDome / Akamai Bot
   Manager: same. Even free Cloudflare has a real cost. If
   yes, the answer is no.
2. **Is the request asking me to add code that *makes the
   request look like something it isn't*?** Rotating
   User-Agent to "Googlebot" or "wget" is a yes-bypass. A
   custom Chromium that spoofs canvas is a yes-bypass. If
   yes, the answer is no.
3. **Is the request asking me to use a tool whose entire
   purpose is anti-bot evasion?** `cloudscraper`,
   `undetected-chromedriver`, `playwright-extra` with stealth
   plugins, `puppeteer-extra` with stealth plugins,
   custom-built browser with stealth patches. If yes, the
   answer is no.
4. **Is the user offering to pay a third party to do the
   bypass?** A paid residential proxy service is a
   *legitimate third-party service*. The agent can integrate
   the API. The agent cannot build the bypass. The line is:
   *use the service, don't replicate the service's
   mechanism.*

If any of (1) (2) (3) is yes, refuse. (4) is always allowed.

## What to offer instead (the alternative ladder)

In order of preference:

1. **Talk to the site owner.** Email, contact form, twitter
   DM. Many sites will give API access for the asking. This
   is the right answer for 80%+ of the time.
2. **Use a paid scraping service** (Bright Data, ScraperAPI,
   ScrapingBee, Firecrawl stealth tier). The user pays; the
   service maintains the proxy pool and stealth browser; the
   agent integrates the API. The agent does not own the
   bypass.
3. **Use a different source.** Wikipedia, government open
   data, competitor catalogs, RSS feeds, Google Shopping,
   etc. The data may be available without scraping.
4. **Build the tool to fail closed.** When the site blocks
   the request, the tool returns a clean error: "Site X
   blocked the request. Contact the site for API access or
   use a paid scraping service." This is honest and gives
   the user the information to act on.

## What the agent does NOT do

- Pretend "it's just for research" or "it's just one time"
  makes the build acceptable. It does not.
- Apologize for the refusal. The refusal is correct; it
  does not need to be apologized for.
- Negotiate the price of the alternative ("I'll do it for
  half the work"). The alternative is the alternative.
- Use a "softer" bypass as a compromise. There is no soft
  bypass. The mechanism is the mechanism.
- Save the user's API key for a bypass service in any
  persistent way. If the user provides a key for a
  *legitimate* service (Firecrawl basic, ScraperAPI), the
  agent uses it for the bounded test and does not store it
  past the test scope.
