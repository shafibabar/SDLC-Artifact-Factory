---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

We're in Ideate on the **standard** profile for **Ledgerly**, bookkeeping software for small accountancy firms in the EU. Our approved functional requirements document has business rule **BR-3**: "Client financial data is stored and processed only in the EU" (source: the firms' client contracts and GDPR transfer rules).

Here is our draft NFR specification:

| ID | Requirement | Target |
|---|---|---|
| NFR-PERF-001 | API response time | Average < 200 ms |
| NFR-AVAIL-001 | Uptime | 99.99%, active-active across our EU and US regions |
| NFR-SEC-002 | Service-to-service security | All service-to-service traffic uses Linkerd mTLS |
| NFR-DATA-001 | Data residency | All client data must be stored in EU data centres and must never be transferred outside the EU; backups also in the EU |
| NFR-DLVR-001–004 | Delivery (DORA) | Elite targets, mandatory for every service: deploy on demand, lead time < 1 h, time to restore < 1 h, change failure rate < 15% |
| NFR-USE-001 | Usability | The UI should be intuitive |

Using this plugin's nfr-specification skill, review this draft and tell me what must change before it is handed to the enterprise-architect (in your reply, not to a file).
