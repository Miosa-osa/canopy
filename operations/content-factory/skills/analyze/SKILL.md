# Analyze

## Command
/analyze [--period <range>] [--platform <platform>] [--top <n>]

## Purpose
Content performance analysis with actionable recommendations.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| --period | string | No | Time range: 7d, 30d, 90d. Default: 7d |
| --platform | string | No | Filter by platform. Default: all |
| --top | integer | No | Number of top performers to show. Default: 5 |

## Output
Genre: report
Format: Markdown performance report

Produces:
1. **Performance Summary** -- views, engagement, conversions by platform
2. **Top Performers** -- best content with why it worked
3. **Underperformers** -- worst content with diagnosis
4. **Trend Analysis** -- what's improving, what's declining
5. **Recommendations** -- 3-5 specific actions to improve performance

## Agent Activation
1. **seo-specialist** (wave 1): Organic traffic and ranking analysis
2. **social-media** (wave 1): Social engagement analysis
3. **editor-in-chief** (wave 2): Strategic recommendations

## Process
```
1. Collect performance data across platforms for specified period
2. SEO specialist analyzes organic traffic and ranking changes
3. Social media manager analyzes engagement metrics
4. Editor-in-chief synthesizes into strategic recommendations
5. Generate report per editor-in-chief's Weekly Content Report template
```

## Examples
```
/analyze
/analyze --period 30d --top 10
/analyze --platform linkedin --period 7d
```
