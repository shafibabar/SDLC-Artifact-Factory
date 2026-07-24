---
name: alerting-rules-design-<product>
product: <product-name>
version: 1.0.0
phase: deploy
created: <date>
owner: platform-engineer
---

# Alerting Rules Design — <Product>

## Alert Inventory
| Alert | Symptom / SLO protected | Severity | Windows / burn rate | Runbook |

## Burn-Rate Policy Applied
| SLO | Fast burn (page) | Slow burn (page) | Trickle (ticket) |

## Pipeline Leading Indicators
| Alert | Condition | Severity | Rationale |

## Routing and Inhibition
[Route tree, grouping keys, inhibition rules, receivers]

## Review Log
| Date | Alert | Fired count | Actioned? | Toil (repeat manual fix?) | Decision (keep/tune/delete/automate) |

## Configuration Files
- prometheus/rules/slo-burn-*.yaml
- prometheus/rules/pipeline-leading-indicators.yaml
- alertmanager/alertmanager.yml
