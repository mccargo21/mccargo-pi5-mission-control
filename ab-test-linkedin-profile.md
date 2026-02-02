# A/B Test: LinkedIn Profile Optimization

**Owner:** Adam McCargo
**Status:** Planning
**Date:** February 1, 2026

---

## Test Context

### What we're testing
LinkedIn profile improvements to achieve a specific business goal.

### Current profile state
*To be confirmed with Adam*

---

## Hypothesis Framework

**Draft hypothesis:**

```
Because [observation/data],
we believe [change to profile]
will cause [expected outcome]
for [target audience].
We'll know this is true when [metrics].
```

---

## Test Design

### Type
Time-based split (LinkedIn doesn't support native A/B testing)

### Duration
- Variant A (Control): 2-3 weeks
- Variant B: 2-3 weeks
- Total: 4-6 weeks

### Sample size considerations
- LinkedIn's algorithm takes time to distribute changes
- Need to account for variability in weekly view patterns
- Compare same days of week to reduce noise

---

## Metrics Selection

### Primary Metric
*To be defined based on goal*

Options:
- Profile views per week
- Inbound connection requests per week
- Recruiter/DM inquiries per week
- Search appearances per week

### Secondary Metrics
- Connection acceptance rate
- "Who viewed your profile" quality
- Featured content clicks
- Post engagement rate

### Guardrail Metrics
- Profile engagement score
- Post reach
- Network growth rate

---

## Testing Approach

### Option 1: Sequential Testing (Recommended)

```
Weeks 1-2: Baseline (current profile)
Weeks 3-4: Variant B
Week 5: Return to control (optional)
Week 6: Variant B again (optional)
```

**Pros:** Clean measurement, simple to implement
**Cons:** Takes longer, external factors could confound

### Option 2: Parallel Views

Create a short link/landing page with profile variants:
- Link 1 → Profile version A screenshot + "Connect on LinkedIn"
- Link 2 → Profile version B screenshot + "Connect on LinkedIn"
- Track click-through to actual LinkedIn profile

**Pros:** True A/B, faster results
**Cons:** Friction for viewers, less natural

---

## Information Needed From Adam

### 1. Primary Goal
What's the #1 outcome you want from your LinkedIn profile?
- [ ] Attract contract clients for digital marketing
- [ ] Get recruited for full-time roles
- [ ] Build thought leadership in travel/tourism
- [ ] Expand professional network
- [ ] Something else

### 2. Change to Test
Which part of your profile are you most interested in optimizing?
- [ ] Headline
- [ ] About section
- [ ] Experience descriptions
- [ ] Featured section (portfolio, articles, etc.)
- [ ] Skills/endorsements
- [ ] Complete profile overhaul

### 3. Target Audience
Who do you want to attract?
- [ ] SMBs needing marketing help
- [ ] Enterprise marketing teams
- [ ] Travel/tourism industry
- [ ] Recruiters at marketing agencies
- [ ] Other (specify)

### 4. Baseline Metrics
Do you have access to any current data?
- Weekly profile views: _____
- Monthly connection requests: _____
- Monthly inbound inquiries: _____
- Search appearances per week: _____

### 5. Current Profile Content
Please provide:
- Current headline: _________________
- Current About section: _________________
- Top 3 experience bullet points: _________________

---

## Next Steps

1. Adam answers questions above
2. Draft specific hypothesis
3. Create variant B (modified profile content)
4. Define success criteria and measurement plan
5. Document test plan
6. Execute and monitor

---

## Notes

- LinkedIn shows profile stats under "My Network" → "Who viewed your profile"
- Consider screenshotting current stats before starting
- Best to test during business cycles (avoid holidays)
- Document any external factors during test period (viral post, industry news, etc.)
