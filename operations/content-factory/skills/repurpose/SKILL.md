# Repurpose

## Command
/repurpose <content_title> [--platforms <list>]

## Purpose
Adapt a pillar piece of content into platform-native derivatives across social channels.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| content_title | string | Yes | Title of the source content to repurpose |
| --platforms | string | No | Comma-separated platform list. Default: all active platforms |

## Output
Genre: social-package
Format: Markdown with platform-specific content + visual briefs

Produces:
1. **Platform-Native Posts** -- adapted content per platform (not cross-posted)
2. **Visual Briefs** -- design direction for each platform's visual needs
3. **Scheduling Recommendation** -- optimal post times per platform
4. **Hashtag Strategy** -- platform-appropriate hashtags

## Agent Activation
1. **social-media** (wave 1): Platform adaptation, hooks, CTAs, scheduling
2. **designer** (wave 1): Visual asset briefs per platform specs

## Process
```
1. Analyze source content for repurposable elements (stats, tips, quotes, frameworks)
2. Social media manager creates platform-native adaptations
3. Designer creates visual briefs for each platform format
4. Schedule across platforms with optimal timing
5. Target: 1 pillar piece -> 5+ derivative posts
```

## Examples
```
/repurpose "The Complete Guide to B2B Content Marketing"
/repurpose "Q1 Results Case Study" --platforms linkedin,x
```
