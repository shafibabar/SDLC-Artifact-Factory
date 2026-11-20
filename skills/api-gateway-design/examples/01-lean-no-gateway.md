# Example 1 — Lean: A Single Application Asking for a Gateway

Self-contained. **Bakeoff** is an app for a home-bakers' club to schedule contests and post results. **Lean** profile: one web front end and one backend application deployed as one container, one database, about 400 members.

## Input

> **User:** "Put Kong in front of the app so it's ready. Add a plugin that checks whether a member is an organiser or a judge, so the app doesn't need to. And since Kong checks the token, the app can skip that."

## Working it

- **Gateway or none?** The container diagram's gateway section decides placement at Design, and for one application it says none: the ingress routes to the application, which validates tokens itself. A gateway in front of one application is another system to run, with no cross-cutting concern to house and nothing shared by several deployables.
- **The role-checking plugin** is declined. What a member may do is an authorization decision, and authorization stays in the service that owns the data; the edge proves who, never what. The same split would also leave two layers to keep consistent.
- **"The app can skip the token check"** is declined. Even with a gateway, every service verifies identity itself: a request can reach a service without passing the gateway, and nothing is trusted by position. Here the application is the only service and does its own validation.
- **What is configured instead:** the ingress, with TLS termination, routing and request logs, as declarative files in version control, reviewed like any change. No live edits in an admin interface.
- **When the answer would change:** several deployables sit behind one public API, per-key rate limits are needed, or a second client needs a different payload (a backend-for-frontend behind a gateway). The product would then be named as a proposal pending an ADR, since the default stack names no gateway.
- **No per-tenant limits or consumers:** Bakeoff is one club.

## Output: the reply (a short note at lean)

> **No gateway for Bakeoff.** The container diagram places none, because there is one application: the ingress routes to it and the application validates tokens itself.
>
> - **No role-checking plugin:** authorization stays in the application; the edge only proves who the caller is.
> - **The application still verifies every token itself.** Even where a gateway exists, services never skip their checks.
> - **Configuration** is the ingress's TLS, routing and logs as declarative files in version control, with the diff reviewed. No live edits in an admin interface.
> - **I would revisit** when several deployables share a public API, per-key limits appear, or a second client needs its own payload. Kong would then be a proposal pending an ADR, not a default.
>
> No separate design document is produced beyond this note, and it contains no implementation code.
