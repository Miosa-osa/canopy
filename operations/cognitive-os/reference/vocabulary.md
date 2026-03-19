# Vocabulary Transforms

## Universal → Domain Mapping

OptimalOS uses universal terms internally. When communicating to specific domains,
transform vocabulary for the receiver.

### Universal → Business
| Universal | Business |
|-----------|----------|
| Signal | Communication / Update |
| S/N Ratio | Quality / Relevance |
| Genre | Format / Template |
| Node | Department / Division |
| Context | Background / History |
| Decay | Relevance / Freshness |
| Intake | Capture / Record |
| Edge | Relationship / Connection |
| Entity | Contact / Organization |
| Tier | Detail Level / Summary Level |

### Universal → Technical
| Universal | Technical |
|-----------|-----------|
| Signal | Event / Payload |
| S/N Ratio | Quality Score |
| Genre | Schema / Template |
| Node | Namespace / Module |
| Context | State / Configuration |
| Decay | TTL / Expiration |
| Intake | Ingestion / Pipeline |
| Edge | Foreign Key / Association |
| Entity | Record / Resource |
| Tier | Cache Level / Resolution |

### Universal → Sales
| Universal | Sales |
|-----------|-------|
| Signal | Lead / Update / Intel |
| S/N Ratio | Lead Quality |
| Genre | Pitch / Deck / One-pager |
| Node | Account / Territory |
| Context | Account History |
| Decay | Pipeline Stage / Freshness |
| Intake | CRM Entry |
| Edge | Referral / Introduction |
| Entity | Contact / Company |
| Tier | Summary / Deep Dive |

### Universal → Personal
| Universal | Personal |
|-----------|----------|
| Signal | Thought / Observation |
| S/N Ratio | Importance |
| Genre | Journal / Note / Reflection |
| Node | Life Area |
| Context | Memory / Experience |
| Decay | Relevance |
| Intake | Journaling / Capture |
| Edge | Connection / Pattern |
| Entity | Person / Place / Thing |
| Tier | Quick Note / Detailed Reflection |

## Application Rule
Before encoding a signal for a specific receiver, check their domain and transform
the vocabulary. The owner and the engine use universal terms. Everyone else gets
domain-appropriate language.
