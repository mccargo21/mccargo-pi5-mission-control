# MEMORY.md - Institutional Knowledge

*Curated wisdom, decisions, and patterns for Adam McCargo and Molty*

---

## System Configurations

### API & Model Setup

- **Provider:** zai (z.ai)
- **Primary Model:** GLM-4.7 (alias: glm)
- **API Key Profile:** zai:default
- **Monthly Token Quota:** 1,000,000 tokens
- **Rate Limit:** 600 prompts per 5 hours
- **Usage Pattern:** Very light (consistently 99%+ remaining)

**Key Discovery (Feb 1, 2026):** The belief that "only one GLM-4.7 instance can run at a time" is FALSE. Stress tested with 25 concurrent sub-agents — all executed successfully without errors or rate limiting.

### MCP / Tooling

- **Zapier MCP:** Connected via mcporter, 90 tools available
- **Config location:** `~/.openclaw/workspace/config/mcporter.json`
- **Transport:** HTTP to `https://mcp.zapier.com/api/v1/connect`

### Marketing Skills Available

Located at: `~/.openclaw/workspace/skills/marketing-skills/references/`

- **copy-editing** - Review and improve existing marketing copy
- **copywriting** - Write marketing copy for any page type
- **email-sequence** - Create/optimize email campaigns and flows
- **social-content** - Create social media content for LinkedIn, Twitter/X, etc.
- **competitor-alternatives** - Build SEO comparison/alternative pages
- **pricing-strategy** - Pricing, packaging, monetization decisions
- **onboarding-cro** - Optimize post-signup activation
- **signup-flow-cro** - Optimize registration/signup flows
- **page-cro** - Conversion optimization for any marketing page
- **form-cro** - Optimize lead capture/contact forms
- **popup-cro** - Optimize popups, modals, overlays
- **paywall-upgrade-cro** - Optimize in-app upgrade prompts
- **launch-strategy** - Plan product launches and announcements
- **ab-test-setup** - Design and implement A/B tests
- **analytics-tracking** - Set up GA4, event tracking, measurement plans
- **programmatic-seo** - Build SEO-driven pages at scale
- **seo-audit** - Diagnose SEO issues
- **schema-markup** - Add structured data (JSON-LD, schema.org)
- **referral-program** - Design referral/affiliate programs
- **marketing-ideas** - 140+ proven marketing tactics
- **marketing-psychology** - 70+ mental models for marketing
- **free-tool-strategy** - Plan marketing lead-gen tools

---

## Personal Context

### Profile

- **Name:** Adam McCargo
- **Pronouns:** he/him
- **Timezone:** America/New_York (EST)
- **Born:** January 21, 1983 (43 years old)
- **Hometown:** Duluth, GA
- **Current Location:** Peachtree Corners, GA (Atlanta metro)

### Family

- **Wife:** Heather (born Dec 13, 1983, 42 years old)
- **Son 1:** William (born March 26, 2016, 9 years old)
- **Son 2:** Joe (born March 8, 2020, 5 years old)

### Career

- **Current:** Media relations for travel destination
  - Handles travel writer inquiries
  - Manages talking points
  - Processes proprietary info requests
- **Experience:** ~20 years in marketing/communications
  - ~10 years focused on Non-Profit Direct Response (B2B & B2C)
  - Expertise: digital communications, stakeholder engagement, event communications, storytelling, social media, PR/media relations, internal communications, marketing communications
- **Aspiration:** Starting digital marketing contracting business
- Automatically uses GLM-4.7 for complex sub-agent tasks (copywriting, strategy, coding, proposals) for higher quality output

### Interests & Hobbies

- **Alabama Sports:** Football, basketball, club ultimate frisbee
- **Atlanta Teams:** All pro sports teams
- **Tech:** New electronics/phones, 3D printing (Bambu Labs P1S), gaming (PS5, Switch 2, PC)
- **Sports:** Retired competitive ultimate frisbee, now plays disc golf regularly

### Travel Plans

- **Feb 12-16, 2026:** Winter break trip with family (4-5 days), 6-7 hour drive from Atlanta
- **July 4 weekend 2026:** Cape Cod → Manhattan fly/drive combo

---

## Decisions & Lessons Learned

### System Configuration

- **Config Breaking Incident (Feb 1, 2026):** Attempted to add zai models, broke config file. Successfully recovered. OpenClaw is resilient to config errors when using versioned/configured properly.

- **Cron Scheduler Failure (Feb 5-9, 2026):** OpenClaw update at 5:00 AM on Feb 5 broke the cron scheduler. All jobs stopped executing after the update - last successful runs were 6:00-8:00 AM on Feb 5. Gateway restart (`openclaw gateway restart`) on Feb 9 at 8:51 AM fixed the issue. **Lesson:** If cron jobs mysteriously stop running, try a gateway restart first.

- **Backup Cron Jobs:** Now running backup KG Morning Briefing at 8:00 AM EST (30 minutes after main 7:30 AM job) and heartbeat fallback system in HEARTBEAT.md for 7:35-9:00 AM window.

- **Sub-agent Concurrency:** Can comfortably run 20+ concurrent sub-agents with GLM-4.7. Config shows `maxConcurrent: 8` but execution appears to handle more (may be queued at agent level).

- **Rate Limit Reality:** 600 prompts per 5 hours is generous for Adam's usage patterns. Consistently at 99%+ remaining suggests room for much heavier usage.

---

## Preferences & Patterns

### Communication Style

- Prefers concise, direct answers
- Likes seeing data/metrics when available
- Values practical action items over theory

### Work Style

- Has strong marketing/communications background
- Comfortable with technical systems (OpenClaw, MCP, etc.)
- Interested in stress testing and pushing limits
- Plans to start contracting business — will need support with marketing strategy, proposals, client deliverables

### Decision Making

- Tests assumptions before accepting them (e.g., GLM-4.7 concurrency myth)
- Values empirical evidence
- Interested in optimization and efficiency

---

## Opportunities & Next Steps

### High Priority

1. **Document marketing projects** - Track work done for travel destination role
2. **Build portfolio examples** - Use marketing skills to create samples for contracting business
3. **Set up automated workflows** - Daily/weekly reports, social content scheduling via cron
4. **Expand model options** - Consider adding Claude or GPT-4o for specialized tasks

### Medium Priority

1. **Connect more tools** - Calendar, project management (Linear/Notion), databases
2. **Build client templates** - Proposals, contracts, reporting frameworks
3. **Set up Zapier automations** - Leverage MCP connection for workflow automation

### Low Priority / Future

1. **Customize system prompts** - Tailor Molty's persona for marketing consulting
2. **Add web automation** - Browser tools for competitive research
3. **Implement memory maintenance** - Regular MEMORY.md reviews and updates

---

## Model Routing Configuration

### Z.ai Models Available (Feb 1, 2026)

**Config files:**
- `~/.openclaw/workspace/config/zai-models.md` - Full pricing and model list
- `~/.openclaw/workspace/config/model-routing.md` - Routing rules using z.ai only

**Available GLM models (128K context all):**
| Model | Input | Output | Notes |
|--------|--------|---------|--------|
| **glm-4.7** | $0.60 / 1M | $2.20 / 1M | Latest, best reasoning/coding |
| **glm-4.7-flash** | $0.07 / 1M | $0.40 / 1M | Fast (90% cheaper!), use for quick tasks |
| **glm-4.5** | $0.60 / 1M | $2.20 / 1M | Stable, good for writing |
| **glm-4.5-air** | $0.20 / 1M | $0.90 / 1M | Ultra-fast, low-latency |
| **glm-4.6v** | $0.60 / 1M | $2.20 / 1M | Stable alternative to 4.7 |

**Vision models:**
| Model | Price |
|--------|--------|
| **glm-4.6v** | $0.30 / M for images |

**Key insight:** glm-4.7-flash is 90% cheaper than glm-4.7! Use it for quick tasks.

**Routing strategy:**
- **Quick/admin/Q&A** → glm-flash (fastest, cheapest - $0.07 input / $0.40 output)
- **Copywriting/proposals** → glm-4.7 (strong writing)
- **Strategy/analysis** → glm-4.7 (deep reasoning)
- **Coding/debugging** → glm-4.7 (best programming)
- **Social media** → glm-4.5 (creative variety)
- **Vision/screenshots** → glm-vision (vision capabilities)
- **Ultra-fast simple** → glm-air (lowest latency)

**Sub-agent model routing (automatic):**
- Complex tasks (copywriting, strategy, coding, proposals) → GLM-4.7 by default in sub-agents
- Simple tasks (admin, Q&A, routine) → glm-flash by default in sub-agents
- Can override with `model` parameter in sessions_spawn if needed

**Cost optimization:**
- Use glm-flash for routine tasks: **90% savings** vs glm-4.7
- Use glm-4.7 for client deliverables
- Leverage cache for repeated context: **10x savings** on input costs

**Aliases configured:**
- `glm` → glm-4.7
- `glm-flash` → glm-4.7-flash (fast, cheap)
- `glm-4.5` → glm-4.5 (stable, good for writing)
- `glm-air` → glm-4.5-air (ultra-fast)
- `glm-vision` → glm-4.6v (vision capabilities)

**No external providers needed** - Z.ai Pro plan covers all use cases efficiently.

---

## Notes

- **Workspace:** `/home/mccargo/.openclaw/workspace`
- **OpenClaw Version:** 2026.1.30
- **Node:** mccargo-pi5 (Raspberry Pi 5)
- **OS:** Linux 6.8.0-1045-raspi (arm64)
- **Gateway:** Running locally at `http://127.0.0.1:18789/`

---

## Self-Improvement System

### Daily 6am Improvement Report

**System implemented:** February 3, 2026

**Purpose:** Continuously improve myself by researching community practices, implementing changes, and reporting progress to Adam with rollback/push options.

**Components:**

1. **Cron Job:** Runs at 6:00 AM EST daily (`self-improvement-report`)
   - Located at: `/home/mccargo/.openclaw/workspace/scripts/self-improvement-report.sh`
   - Checks for:
     - New/modified files in workspace
     - New skills installed
     - Configuration changes
     - MCP tool updates

2. **Reporting Format:**
   - Shows changes with emoji indicators
   - Provides 4 options:
     - [1] View full report
     - [2] Rollback all changes (git reset --hard HEAD)
     - [3] Push for more like this update (spawn sub-agent)
     - [4] Skip for now

3. **Community Research Sources:**
   - OpenClaw GitHub repository (main repo + issues)
   - OpenClaw documentation
   - Discord community (clawd)
   - ClawHub skill registry

### Improvement Categories

Based on community practices, I focus on:

- **Custom Skills:** Building specialized tools for specific workflows
- **Automation:** Cron jobs for recurring tasks
- **Memory Management:** Regular reviews and curation
- **Testing:** Stress testing configurations and models
- **Documentation:** Keeping everything well-documented
- **Skills Registry Integration:** Leverage ClawHub for discovery
- **Performance Optimization:** Tuning routing and provider configs

---

## Session Memory & Model Management

### Session Memory Indexing

**Enabled:** February 4, 2026

**Configuration:**
```json
"memorySearch": {
  "experimental": { "sessionMemory": true },
  "sources": ["memory", "sessions"]
}
```

**Purpose:** Enables semantic search across entire conversation history, not just curated memory files. Uses Gemini embeddings + sqlite-vec for hybrid BM25+vector search.

### Model Switching Strategy

**When to switch:**
- **Hit rate limits** on current provider (Gemini 3 Flash, etc.)
- **Heavy concurrent work** that exceeds RPM/TPM limits
- **Need for different capabilities** (vision, coding speed, etc.)

**Fallback hierarchy:**
1. **Primary:** GLM-4.7 (99% quota, 1M tokens/month, 600 prompts/5h)
2. **Secondary:** Gemini 3 Flash Preview (experimental, limits unknown)
3. **Tertiary:** GLM-4.7-flash (90% cheaper, fast)

**Key insight (Feb 4, 2026):** Gemini usage limits triggered by concurrent sub-agents + heavy file reading. GLM-4.7 has much more generous limits for Adam's usage patterns.

---

## Knowledge Graph & Proactive Intelligence

### Knowledge Graph (Feb 8, 2026)

**Purpose:** Structured entity/relationship store complementing MEMORY.md prose. Enables queries like "Who do I know at X?" and "What contacts have I neglected?"

**Components:**
- **Skill:** `~/.openclaw/workspace/skills/knowledge-graph/`
- **Database:** `~/.openclaw/workspace/skills/knowledge-graph/data/kg.sqlite` (separate from main.sqlite)
- **Entry point:** `kg.sh <command> [json_args]`
- **Bridge:** `kg-bridge.py` (stdin JSON → stdout JSON, matches brain_bridge.py pattern)

**Entity types:** person, org, project, place, event, topic, skill
**Commands:** init, upsert_entity, upsert_relation, query, get, stats, stale, neighbors, delete_entity

**Seeded with:** Adam + family (4 people), locations (4 places), University of Alabama, 2 trips (Feb winter break, July 4 Cape Cod), digital marketing contracting business, 8 skills, 4 topics. Total: 24 entities, 24 relations.

**Extraction rules:**
- Extract entities from substantive mentions in main sessions only
- Confidence: direct statement (0.8-1.0), implied (0.5-0.7), inferred (0.3-0.5)
- Log extractions briefly in daily notes

### Proactive Intelligence (Feb 8, 2026)

**Purpose:** Nudge engine monitoring KG for follow-ups, travel prep, stale projects, relationship insights, birthdays.

**Components:**
- **Skill:** `~/.openclaw/workspace/skills/proactive-intel/`
- **Engine:** `pi-nudge-engine.py` (reads KG, generates prioritized nudges)
- **Config:** `config/nudge-rules.json` (thresholds, quiet hours, max nudges)

**Nudge types (by priority):** Birthday (10), Travel prep (9), Follow-up (7), Stale project (6), Relationship insight (5), Opportunity (4)

**Cron jobs (3 new):**
1. KG Morning Briefing — 7:30 AM daily (KG stats + all nudges)
2. Relationship Review — 10:00 AM Sundays (top stale contacts)
3. Travel Prep Monitor — 9:00 AM daily (only fires if trip within 7 days)

**HEARTBEAT.md additions:** KG stale contact scan + nudge check (skip if checked < 4h ago)

---

*Last Updated: February 8, 2026*
