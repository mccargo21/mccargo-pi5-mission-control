#!/usr/bin/env python3
"""
Nonprofit Marketing Idea Generator
Generates creative, strategic marketing ideas for your nonprofit transition.
"""

import sys
import json
import random
from datetime import datetime, timezone

# Idea templates
IDEA_TEMPLATES = {
    "educational_content": {
        "title": "Educational Content Package",
        "description": "Leverage {experience} years of marketing experience into educational resources (guides, playbooks, workshops) for nonprofits to use in donor acquisition and engagement campaigns.",
    },
    "thought_leadership": {
        "title": "Thought Leadership Conference",
        "description": "Create a quarterly virtual conference featuring speakers from leading nonprofit marketers. Package insights from your agency experience into actionable workshops on storytelling, ethics, and authentic marketing.",
    },
    "skills_consulting_network": {
        "title": "Skills-Based Consulting Network",
        "description": "Build a curated network of senior marketers who volunteer to provide fractional consulting to nonprofits. Create a platform matching nonprofits to experts based on their needs (digital, fundraising, branding, governance).",
    },
    "digital_marketing_incubator": {
        "title": "Nonprofit Digital Transformation Lab",
        "description": "Launch a 12-week cohort program where nonprofits work alongside your digital marketing mentors to modernize their systems (CRM, social media, automation). Cap at 8-12 nonprofits per cohort.",
    },
    "corporate_giving_bridge": {
        "title": "Corporate Giving Bridge",
        "description": "Develop a B2B service connecting {contact_name}'s corporate clients with nonprofits looking for CSR partnerships. Provide case studies, partnership templates, and relationship management.",
    },
    "grant_writing_incubator": {
        "title": "Grant Writing Incubator",
        "description": "Free program where you help nonprofits write winning grants (CFPC, NIH, local foundations). Build your reputation as 'the grant whisperer' and offer workshops on grant writing and strategy. Upsell: 'Need help scaling? Here's a grant opportunity'.",
    },
    "board_placement_concierge": {
        "title": "Board Placement Concierge",
        "description": "Research and place yourself on nonprofit boards. Offer: 'I'll guarantee board placement or your money back'. Free initial consultation, success-based fee (5% of first year's salary).",
    },
    "side_hustle_newsletter": {
        "title": "The Side Hustle Newsletter",
        "description": "Weekly digest of quick nonprofit marketing tactics. Growth-focused, actionable, builds your email list. Focus on: 'Marketing for Sustainable Nonprofits', 'Nonprofit Case Study Library', 'The 30-Day Pivot Challenge'.",
    },
    "nonprofit_case_study_library": {
        "title": "Nonprofit Case Study Library",
        "description": "Document 50+ successful case studies in various nonprofit sectors (advocacy, education, health, environment, arts). Sell access on a subscription basis. Use cases to attract corporate sponsors. Upsell: 'Need help scaling? Here's a case study'.",
    },
    "day_pivot_challenge": {
        "title": "The 30-Day Pivot Challenge",
        "description": "Challenge nonprofits: 'Test one new channel for 30 days' and provide support: strategy, creative assets, analytics. Best participant gets pro-bono consulting package from your agency. Upsell: Full engagement package with dedicated support.",
    },
    "corporate_volunteer_program": {
        "title": "Corporate Volunteer Program",
        "description": "Marketing Sabbatical program: Corporations sponsor employees to work at nonprofits for 6 months. Recruit companies you've worked with (agencies have alumni). Offer: 'We'll help you transition smoothly'.",
    },
    "social_enterprise_marketing": {
        "title": "Social Enterprise Marketing",
        "description": "Marketing services for large nonprofits. Specialize in donor acquisition, major donor campaigns, planned giving strategy, and board development. Position yourself as a thought leader.",
    },
}

# Creative enhancers
ENHANCERS = [
    {
        "for": "{social_cause}",
        "leveraging": "{industry} expertise",
        "partnering_with": "{platform} community",
        "targeting": "{geographic} donors",
        "storytelling": "{emotional_angle}",
        "gamification": "{engagement_mechanic}",
    },
    {
        "for": "{social_cause}",
        "leveraging": "{industry} expertise",
        "partnering_with": "{platform} community",
        "targeting": "{geographic} donors",
        "storytelling": "{emotional_angle}",
        "gamification": "{engagement_mechanic}",
    },
]

# Helper functions
def select_enhancer():
    """Select a random creative enhancer to add to an idea text."""
    return random.choice(ENHANCERS)

def add_enhancer(idea_text):
    """Apply a random creative enhancer pattern to an idea text."""
    enhancer = select_enhancer()
    
    # Build enhancer pattern dict
    pattern = {
        "for": enhancer["for"],
        "leveraging": enhancer["leveraging"],
        "partnering_with": enhancer["partnering_with"],
        "targeting": enhancer["targeting"],
        "storytelling": enhancer["storytelling"],
        "gamification": enhancer["gamification"],
    }
    
    # Return formatted string
    return ' '.join([
        f"{k}: {v}"
        for k, v in pattern.items()
    ])

def generate_idea(template_key, experience_years, industry):
    """Generate a complete idea using a template and personalization."""
    template = IDEA_TEMPLATES[template_key]
    
    # Build idea
    idea = {
        "title": template["title"],
        "description": template["description"],
        "enhancers": [],
        "estimated_effort": "Low" if "Quick" in template["description"] else "Medium",
        "category": template_key,
    }
    
    # Add creative enhancers
    enhancer_pattern = add_enhancer(idea["description"])
    if enhancer_pattern:
        idea["enhancers"].append(enhancer_pattern)
    
    # Add quick win enhancer if applicable
    if "Quick" in template["description"]:
        idea["enhancers"].append({
            "type": "quick_win",
            "text": "3-month runway to build portfolio"
        })
    
    # Add partnership enhancer if applicable
    if "partnership" in template["description"].lower() or "B2B" in template["description"]:
        idea["enhancers"].append({
            "type": "partnership",
            "text": "LinkedIn referral network for cross-promotions"
        })
    
    return idea

def generate_strategy_report(ideas):
    """Group ideas by category and add strategic insights."""
    categories = {
        "Content": [],
        "Events": [],
        "Platforms": [],
        "Services": [],
        "Partnerships": [],
    }
    
    # Group ideas by category
    for idea in ideas:
        cat = idea.get("category", "general")
        if cat not in categories:
            categories[cat] = []
        categories[cat].append(idea)
    
    # Build strategic summary
    summary = {
        "total_ideas": len(ideas),
        "categories": {k: len(v) for k, v in categories.items() if v},
    }
    
    # Add strategic insights
    # Insight 1: Content creation is highest leverage
    content_count = len(categories.get("Content", []))
    if content_count > 0:
        categories["Content"].append({
            "insight": "Content creation represents your highest leverage - 20+ years of agency experience packaged into scalable resources."
        })
    
    # Insight 2: Platforms build recurring revenue
    platform_count = len(categories.get("Platforms", []))
    if platform_count > 0:
        categories["Platforms"].append({
            "insight": "Platform models generate recurring revenue while you build your client base. Focus on B2B services first, then scale."
        })
    
    # Insight 3: Services provide immediate wins
    service_count = len(categories.get("Services", []))
    if service_count > 0:
        categories["Services"].append({
            "insight": "Consulting services (grant writing, board placement, fractional CMO) provide quick wins to build credibility and cash flow while you develop long-term client relationships."
        })
    
    return {
        "ideas": ideas,
        "summary": summary,
    }

def main():
    # Parse command line args
    if len(sys.argv) < 2:
        print(json.dumps({
            "error": "Usage: python3 nonprofit-marketing-generator.py [action]",
            "actions": {
                "generate": "Generate 5 creative nonprofit marketing ideas",
                "report": "Show current configuration and templates",
            },
            "examples": {
                "generate": "python3 nonprofit-marketing-generator.py generate --experience \"20 years\" --industry \"Marketing\"",
                "report": "python3 nonprofit-marketing-generator.py report",
            },
        }))
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "generate":
        # Generate 5 random ideas using templates
        ideas = []
        template_keys = list(IDEA_TEMPLATES.keys())
        
        for i in range(5):
            template_key = random.choice(template_keys)
            idea = generate_idea(template_key, 20, "Advertising/Marketing")
            ideas.append(idea)
        
        # Add strategy
        strategy = generate_strategy_report(ideas)
        
        output = {
            "success": True,
            "action": "generated_ideas",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "data": {
                "ideas": ideas,
                "strategy": strategy,
                "templates_used": template_keys,
                "total_ideas": len(ideas),
                "metadata": {
                    "generated_for": "Adam McCargo",
                    "experience_years": 20,
                    "industry": "Advertising/Marketing",
                }
            }
        }
        
        print(json.dumps(output, indent=2))
        sys.exit(0)
    
    elif command == "report":
        # Show available templates
        output = {
            "success": True,
            "action": "configuration_report",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "data": {
                "available_templates": IDEA_TEMPLATES,
                "template_count": len(IDEA_TEMPLATES),
                "enhancers": ENHANCERS,
                "examples": {
                    "generate": "python3 nonprofit-marketing-generator.py generate --experience \"20 years\" --industry \"Marketing\"",
                },
            }
        }
        
        print(json.dumps(output, indent=2))
        sys.exit(0)
    
    else:
        print(json.dumps({
            "error": f"Unknown command: {command}",
            "success": False,
        }))

if __name__ == "__main__":
    main()
