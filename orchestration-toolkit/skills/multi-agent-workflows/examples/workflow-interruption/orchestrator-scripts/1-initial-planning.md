# Orchestrator Script: Initial Planning
## Workflow Interruption Example - T+0:00 (2025-11-24T10:00:00Z)

**Orchestrator Role**: I am the orchestrator responsible for managing the "Real-Time Notification System for E-Commerce Platform" workflow. This document captures my initial planning decisions, rationale, and the workflow setup strategy I executed at T+0:00.

**Context**: The stakeholder has requested implementation of a comprehensive notification system for an e-commerce platform. The system must support real-time WebSocket updates, mobile push notifications, transactional emails, and SMS alerts. I am starting from scratch with no existing infrastructure.

---

## 1. Workflow Initialization

**Timestamp**: T+0:00 (2025-11-24T10:00:00Z)

### 1.1 Workflow Identification

I started by establishing a unique workflow identity that would persist across potential interruptions and resumptions.

**Decision**: Workflow ID = `notification-system-20251124`

**Rationale**:
- **Date-based naming**: The `20251124` suffix (YYYYMMDD format) provides chronological ordering and makes it immediately clear when this workflow was initiated
- **Descriptive prefix**: `notification-system` clearly identifies the domain, making it easy to distinguish from other concurrent workflows
- **Searchability**: This naming convention allows quick filesystem searches (`ls -la .development/workflows/notification-system-*`) to find related workflows
- **Uniqueness**: The date-based approach prevents naming collisions if we need to create similar workflows on different days

**Alternative considered**: Using UUID-based IDs (e.g., `workflow-a4f3b2c1-...`) was rejected because UUIDs are not human-readable and make it difficult to identify workflows at a glance.

### 1.2 Directory Structure Setup

I established the workflow directory structure to ensure all state, outputs, and archives are organized systematically.

**Decision**: Create directory at `.development/workflows/notification-system-20251124/`

**Directory Structure Created**:
```
.development/workflows/notification-system-20251124/
├── workflow-state.yaml          # Primary state file (updated after each phase/agent)
├── STATUS.yaml                  # Active agent status (updated during agent execution)
├── shared/                      # Cross-phase shared artifacts
│   ├── decisions.md             # Technology decisions log
│   └── architecture.md          # System architecture diagrams
├── active/                      # Currently running agent working directory
└── archive/                     # Completed agent outputs (timestamped subdirectories)
```

**Rationale**:
- **Centralized state**: `workflow-state.yaml` is the single source of truth for workflow progress, phase status, and agent history
- **Active monitoring**: `STATUS.yaml` provides real-time visibility into what agents are currently doing (critical for interruption detection)
- **Shared knowledge**: `shared/` directory allows agents to reference decisions made in earlier phases without redundant work
- **Archive immutability**: Completed agent outputs are moved to timestamped `archive/` subdirectories, preserving historical context
- **Active isolation**: The `active/` directory contains only currently-running agent work, making it easy to identify in-progress tasks

**File Path Examples** (relative to this example directory):
- Primary state: `.development/workflows/notification-system-20251124/workflow-state.yaml`
- Active status: `.development/workflows/notification-system-20251124/STATUS.yaml`
- Archived output: `.development/workflows/notification-system-20251124/archive/planning-20251124-1130/agent-001-system-design.md`

### 1.3 Initial State File Creation

I created the `workflow-state.yaml` file to establish the initial workflow state before launching any agents.

**Decision**: Initialize `workflow-state.yaml` with:
- Workflow metadata (ID, name, created timestamp)
- Phase definitions (5 phases: planning, research, design, execution, review)
- Empty agent tracking structures
- Initial status = `active`

**Initial Content Structure**:
```yaml
workflow_id: notification-system-20251124
workflow_name: Real-Time Notification System for E-Commerce Platform
created_at: 2025-11-24T10:00:00Z
updated_at: 2025-11-24T10:00:00Z
status: active

current_phase:
  name: planning
  started_at: null  # Will be set when agent-001 launches
  completed_at: null
  progress_percent: 0

phases:
  planning:
    status: pending
    agents_used: []
    token_budget: 25000
    tokens_used: 0
  # ... (research, design, execution, review phases)

active_agents: []
completed_agents: []
questions_pending: []
questions_resolved: []
decisions: []
```

**Rationale**: This initial state provides a clear baseline that can be compared against later states to track progress. If an interruption occurs, I can resume by reading this file and determining which phase was active and what agents had completed.

---

## 2. Phase Selection Strategy

**Timestamp**: T+0:00 (2025-11-24T10:00:00Z)

### 2.1 Phase Architecture Decision

I analyzed the workflow requirements and decided on a 5-phase approach to balance thoroughness with efficiency.

**Decision**: Use 5 phases: **Planning → Research → Design → Execution → Review**

**Phase Breakdown**:

| Phase | Purpose | Key Deliverables | Rationale |
|-------|---------|------------------|-----------|
| **1. Planning** | System architecture, requirements analysis, service boundary definition | Microservices architecture, technology stack decisions, 4 notification service definitions | **Essential** - Without clear architecture, research and execution phases would lack direction. This phase establishes what we're building and why. |
| **2. Research** | Technology evaluation, provider comparison, pattern investigation | Notification provider analysis (FCM, APNs, SendGrid, Twilio), WebSocket architecture patterns, integration best practices | **Essential** - E-commerce notifications require third-party services (push, email, SMS). Research ensures we select reliable, scalable providers with good API support. |
| **3. Design** | Data modeling, API schema definition, database design | Data models for notifications, user preferences, delivery tracking | **Anticipated skip** - If the planning phase produces clear service boundaries and the architecture is straightforward (REST APIs, event-driven messaging), we may not need a separate design phase. Data models can be defined during execution. |
| **4. Execution** | Implementation of 4 notification services | WebSocket service, Push notification service, Email service, SMS service (all with code, configuration, error handling) | **Essential** - Core deliverable. This is where the actual notification system code is written. Expected to be the longest phase. |
| **5. Review** | Integration testing, validation, quality assurance | Integration test suite, validation report, deployment readiness checklist | **Essential** - Notification systems must be reliable (users depend on order confirmations, shipping updates). Review phase ensures all services work together correctly and handle errors gracefully. |

### 2.2 Design Phase Skip Rationale

I anticipated potentially skipping the Design phase based on past experience with similar workflows.

**Decision**: Budget 0 tokens for Design phase, but keep it in the workflow structure

**Rationale**:
- **Conditional necessity**: Design phases are valuable when:
  - Complex data relationships require normalization decisions
  - Multiple services share overlapping data models
  - Database schema changes impact existing systems
- **Anticipated simplicity**: For this notification system:
  - Each service is relatively independent (WebSocket, Push, Email, SMS)
  - Data models are straightforward (notifications, user preferences, delivery logs)
  - No complex joins or denormalization tradeoffs
- **Fallback option**: If the Planning phase reveals unexpected complexity (e.g., shared notification queue with priority ordering), I can allocate tokens to Design phase by reallocating from the buffer
- **Workflow clarity**: Keeping Design in the phase list (even with 0 budget) makes the skip decision explicit and documented

**Skip Trigger**: If agent-001 (Planning phase) produces clear service boundaries, simple data models, and straightforward APIs, I will mark Design phase as `status: skipped` and proceed directly to Research.

### 2.3 Phase Sequencing

I considered parallel vs sequential phase execution and decided on a hybrid approach.

**Decision**: Sequential phases with parallel agents within phases

**Sequencing Logic**:
1. **Planning → Research** (sequential): Research depends on architectural decisions from Planning
2. **Research (parallel agents)**: Provider research (agent-002) and WebSocket patterns (agent-003) can run simultaneously
3. **Research → Execution** (sequential): Execution needs provider selections from Research
4. **Execution (single agent, 4 services)**: agent-004 implements all 4 services sequentially to maintain consistency
5. **Execution → Review** (sequential): Review validates what Execution built

**Rationale**:
- **Dependencies drive sequence**: Can't research notification providers until we know what types of notifications we need (Planning output)
- **Parallelism within phases**: Research phase has two independent topics (providers vs WebSocket patterns) that can run concurrently, saving ~45 minutes
- **Consistency over parallelism in Execution**: Considered launching 4 parallel agents (one per service) but rejected because:
  - Risk of architectural inconsistency (different error handling patterns, configuration approaches)
  - Coordination overhead (ensuring shared patterns are followed)
  - Token inefficiency (4 agents duplicating shared context like RabbitMQ integration)
  - Single agent can reference prior services to maintain consistency

---

## 3. Token Budget Allocation

**Timestamp**: T+0:00 (2025-11-24T10:00:00Z)

### 3.1 Total Budget Determination

I established the overall token budget based on workflow complexity and expected deliverables.

**Decision**: Total budget = **110,000 tokens**

**Calculation Rationale**:
- **Deliverables estimate**: 4 notification services × ~1,000 lines each = ~4,000 lines of code
- **Documentation overhead**: Architecture docs, API specs, configuration guides ≈ 30% additional context
- **Agent coordination**: Questions, decisions, state updates ≈ 15% overhead
- **Historical benchmark**: Similar microservices implementations averaged 90K-120K tokens
- **Buffer inclusion**: 110K provides ~37K buffer (33% safety margin) for unexpected complexity

**Alternative considered**: I considered a 150K budget but rejected it as excessive for this scope. Notification services are well-understood patterns with good library support (Socket.io, SendGrid, Twilio), so 110K should be sufficient.

### 3.2 Phase-Level Budget Allocation

I allocated the 110K token budget across the 5 phases based on expected complexity and deliverables.

**Decision**: Phase budgets as follows:

| Phase | Token Budget | % of Total | Rationale |
|-------|--------------|------------|-----------|
| Planning | 25,000 | 23% | **Architecture definition is front-loaded**. Agent-001 must: analyze requirements, define 4 service boundaries, select technology stack (Node.js vs Go vs Python), decide on messaging patterns (RabbitMQ vs Kafka), establish shared patterns (error handling, logging). This is concept-heavy work requiring thorough analysis. |
| Research | 30,000 | 27% | **Provider research is breadth-intensive**. Two parallel agents (agent-002: notification providers, agent-003: WebSocket patterns) must: evaluate 3-4 providers per category (FCM vs APNs vs OneSignal for push, SendGrid vs Mailgun vs AWS SES for email), compare pricing/reliability/features, investigate WebSocket scaling patterns (Socket.io vs raw ws, Redis adapter vs in-memory). High token usage due to comparison matrices. |
| Design | 0 | 0% | **Anticipated skip** (see Section 2.2). Data models are straightforward for notification systems. If unexpectedly needed, reallocate from 37K buffer. |
| Execution | 35,000 | 32% | **Largest phase by deliverables**. Agent-004 must implement 4 services: (1) WebSocket service (~850 lines: connection management, room broadcasting, Redis scaling), (2) Push notification service (~650 lines: FCM/APNs integration, device token management), (3) Email service (~1,050 lines: SendGrid integration, template system, queue management), (4) SMS service (~800 lines: Twilio integration, rate limiting, opt-out handling). High token usage due to code generation volume. |
| Review | 20,000 | 18% | **Integration testing and validation**. Agent-005 must: validate all 4 services work together, test error handling across services, verify configuration consistency, create integration test examples, document deployment steps. Lower token usage than Execution (validation vs creation) but non-trivial due to cross-service testing. |
| **Buffer** | **37,000** | **33%** | **Safety margin for unknowns**. Covers: unexpected questions requiring research, design phase activation if needed, token budget overruns in any phase, additional agents if Execution needs to be split. |
| **Total** | **147,000** | **100%** | **Budgeted: 110K, Available buffer: 37K** |

### 3.3 Budget Justification: Research Phase (30,000 tokens)

I allocated the second-highest budget to Research despite it producing documentation rather than code.

**Rationale**:
- **Provider landscape is broad**:
  - Push notifications: FCM (Android), APNs (iOS), OneSignal (unified), Pusher (WebSocket-integrated)
  - Email: SendGrid, Mailgun, AWS SES, Postmark
  - SMS: Twilio, Nexmo/Vonage, AWS SNS, MessageBird
  - WebSocket: Socket.io, ws library, uWebSockets.js, Pusher
- **Comparison requires depth**: Each provider evaluation includes:
  - API quality assessment (SDKs, documentation, error handling)
  - Reliability metrics (uptime SLAs, delivery rates)
  - Pricing analysis (cost per notification, volume tiers)
  - Integration complexity (authentication, webhook setup)
- **Parallel agents**: Running agent-002 (providers) and agent-003 (WebSocket patterns) simultaneously doubles the effective token usage during this phase
- **Decision impact**: Wrong provider selection discovered late (during Execution) would require significant rework

**Token Distribution within Research**:
- agent-002 (notification providers): ~15,000 tokens (push + email + SMS evaluation)
- agent-003 (WebSocket patterns): ~15,000 tokens (Socket.io vs raw ws, scaling strategies, room management)

### 3.4 Budget Justification: Execution Phase (35,000 tokens)

I allocated the highest budget to Execution as it produces the primary deliverables.

**Rationale**:
- **4 services × ~1,000 lines each** = ~4,000 lines of implementation code
- **Service complexity breakdown**:
  - **WebSocket service** (~850 lines, ~9,000 tokens): Connection lifecycle, room-based broadcasting, Redis adapter for horizontal scaling, authentication middleware, heartbeat/ping-pong, graceful shutdown
  - **Push notification service** (~650 lines, ~8,000 tokens): FCM integration (Android), APNs integration (iOS), device token management, platform-specific payload formatting, batch sending, delivery tracking
  - **Email service** (~1,050 lines, ~10,000 tokens): SendGrid integration, Handlebars template system with partials, Bull queue for reliability, webhook handling (delivered/bounced/clicked events), retry logic, bounce management
  - **SMS service** (~800 lines, ~8,000 tokens): Twilio integration, E.164 phone number validation, rate limiting (carrier restrictions: 1 msg/sec), opt-out management (STOP/START keywords), delivery receipts
- **Shared patterns overhead** (~2,000 tokens): Error handling patterns, logging configuration, environment variable management, database connection pooling, RabbitMQ consumer setup

**Sequential implementation strategy**: agent-004 will implement services in order:
1. WebSocket (foundational, no external dependencies)
2. Push (depends on WebSocket for real-time delivery status)
3. Email (most complex, queue management patterns inform SMS)
4. SMS (simplest, benefits from patterns established in Email)

This ordering allows agent-004 to reuse patterns and maintain consistency.

### 3.5 Budget Monitoring Strategy

I established checkpoints to monitor token usage and prevent budget overruns.

**Decision**: Review token usage after each agent completes

**Monitoring Checkpoints**:

| Checkpoint | Trigger | Action |
|------------|---------|--------|
| **Post-Planning** (agent-001) | Planning phase complete | Compare actual tokens used (18.5K) vs budget (25K). If under budget, shift savings to Execution or buffer. If over budget, assess impact and potentially reallocate from Design (0K) or buffer. |
| **Post-Research** (agents-002, 003) | Research phase complete | Compare actual (22K) vs budget (30K). Research typically runs under budget if agents are well-scoped. Shift savings to Execution (highest risk phase). |
| **Mid-Execution** (agent-004, 50% complete) | 2 of 4 services complete | Extrapolate token usage. If 2 services consumed >17.5K tokens (50% of 35K budget), intervention needed. Options: optimize remaining services, split agent-004 into agent-004a/004b, reallocate from buffer. |
| **Post-Execution** (agent-004) | Execution phase complete | Verify all services implemented. Check token usage vs 35K budget. If significantly under budget, increase Review phase scope (add load testing). |
| **Pre-Review** (before agent-005) | Before launching agent-005 | Calculate remaining budget. Review phase budgeted at 20K, but actual need may vary based on Execution deliverables. Adjust scope (integration tests only vs full deployment validation). |

**Buffer Depletion Trigger**: If cumulative token usage exceeds 90K (leaving <20K buffer), I will:
1. Assess remaining work (incomplete services, pending Review phase)
2. Consider scope reduction (cut nice-to-have features like delivery analytics dashboards)
3. Potentially request user approval for budget increase if critical features remain

---

## 4. Initial Agent Launch Decision

**Timestamp**: T+0:00 (2025-11-24T10:00:00Z)

### 4.1 Agent Selection for Planning Phase

I determined which agent to launch first based on the phase sequence established in Section 2.

**Decision**: Launch **agent-001-system-design** for Planning phase

**Agent ID Naming Convention**: `agent-{sequential-number}-{topic-description}`
- `001`: Sequential numbering for chronological tracking
- `system-design`: Descriptive topic for easy identification in logs and archives

**Rationale**:
- **Phase dependency**: Planning is the first phase in the sequential workflow (Planning → Research → Design → Execution → Review)
- **No prerequisites**: Planning phase has no dependencies on prior work, making it safe to launch immediately
- **Foundation for later phases**: Research phase agents (002, 003) cannot start until Planning defines what notification types are needed

### 4.2 Agent Scope Definition

I carefully defined the scope for agent-001 to ensure it produces actionable outputs for downstream phases.

**Decision**: agent-001 scope includes:
1. **System architecture design** (microservices vs monolith decision)
2. **Service boundary definition** (identify 4 independent notification services)
3. **Technology stack selection** (Node.js/Python/Go, databases, message queues)
4. **Integration pattern design** (event-driven messaging, API contracts)
5. **Notification types cataloging** (real-time WebSocket, push, email, SMS)

**Expected Deliverables**:

| Deliverable | Format | Purpose |
|-------------|--------|---------|
| Microservices architecture diagram | Markdown with ASCII diagrams or Mermaid | Visual representation of service boundaries, data flow, and integration points |
| Service boundary definitions | Markdown table: Service Name, Responsibility, APIs, Dependencies | Clear ownership and interfaces for each of the 4 services |
| Technology decisions | Markdown with decision records (ADRs) | Rationale for Node.js (vs Go/Python), PostgreSQL (vs MongoDB), RabbitMQ (vs Kafka), Redis (vs Memcached) |
| Notification types matrix | Table: Type, Latency Requirement, Use Cases, Priority | Maps business requirements to technical implementation (e.g., WebSocket for <500ms order status updates) |

**Out of Scope for agent-001**:
- Specific provider selection (e.g., SendGrid vs Mailgun) → Delegated to agent-002 in Research phase
- Data model schemas → Deferred to Design phase (or Execution if Design is skipped)
- Implementation code → Delegated to agent-004 in Execution phase

### 4.3 Agent Prompt Design

I crafted a detailed prompt for agent-001 to ensure it produces the outputs needed for Research phase.

**Prompt Structure**:
```
Context:
- E-commerce platform with 500K+ daily active users
- Current pain point: No unified notification system, manual order status updates
- Business requirement: Real-time notifications for order updates, shipping alerts, promotions

Your Task:
Design the system architecture for a real-time notification system.

Specific Deliverables:
1. Architecture diagram (microservices vs monolith decision with rationale)
2. Service boundary definitions (identify independent notification services)
3. Technology stack recommendations (language, databases, message queues, caching)
4. Integration patterns (how services communicate, event-driven design)
5. Notification types catalog (WebSocket, push, email, SMS with latency requirements)

Output Format:
- Create architecture.md in shared/ directory
- Use decision record format for technology choices (Context, Decision, Consequences)
- Include ASCII diagrams or Mermaid for architecture visualization

Constraints:
- Budget: 25,000 tokens (you have ~18K after prompt and context)
- Timeline: 1.5 hours expected
- Scope: Architecture only, no implementation code
```

**Rationale**:
- **Context setting**: Provides business constraints (500K DAU) to inform scalability decisions
- **Explicit deliverables**: Prevents agent from wandering into out-of-scope work (e.g., implementation)
- **Output format specification**: Ensures outputs are machine-readable for later phases (e.g., Research can parse architecture.md)
- **Constraints**: Token budget and timeline create urgency and prevent over-engineering

### 4.4 Expected Effort Estimation

I estimated the time and token usage for agent-001 based on similar past workflows.

**Decision**: Estimated effort for agent-001:
- **Time**: 1.5 hours (90 minutes)
- **Tokens**: 18,500 tokens (74% of 25K Planning budget)

**Time Breakdown Estimate**:
- Requirements analysis: 20 minutes (understand e-commerce notification needs)
- Architecture options evaluation: 30 minutes (microservices vs monolith, synchronous vs async)
- Technology stack research: 25 minutes (Node.js ecosystem, database options, message queues)
- Documentation creation: 15 minutes (write architecture.md, create diagrams)

**Token Breakdown Estimate**:
- Prompt and context: ~2,500 tokens (e-commerce requirements, constraints)
- Architecture analysis: ~6,000 tokens (evaluate options, document decisions)
- Technology research: ~5,000 tokens (compare Node.js/Go/Python, RabbitMQ/Kafka)
- Output generation: ~5,000 tokens (architecture.md, decision records, diagrams)

**Confidence Level**: Medium confidence (±25% variance)
- **Underrun risk**: If requirements are clearer than expected or agent reuses known patterns, could finish in 1.2 hours with 15K tokens
- **Overrun risk**: If agent explores too many technology options or creates overly detailed diagrams, could take 2 hours with 22K tokens
- **Mitigation**: I will check STATUS.yaml at T+1:00 (after 1 hour) to assess progress and intervene if agent is off track

### 4.5 Success Criteria Definition

I defined clear success criteria to determine when agent-001 has completed its scope.

**Decision**: agent-001 succeeds when:

| Criterion | Validation Method | Rationale |
|-----------|-------------------|-----------|
| **Architecture diagram exists** | File exists at `shared/architecture.md` with visual representation | Research phase agents need to visualize system structure |
| **4 services identified** | architecture.md contains service boundary table with ≥4 rows | Execution phase needs clear service definitions |
| **Technology stack decided** | Decision records exist for: language, database, message queue, caching layer | Research phase needs to know what technologies to investigate deeper |
| **Latency requirements specified** | Notification types table includes latency column (e.g., WebSocket <500ms, Email <30s) | Informs provider selection in Research phase |
| **No implementation code** | architecture.md contains only diagrams/descriptions, no .js/.py/.go files | Keeps Planning phase focused on design, prevents scope creep |

**Failure Modes and Recovery**:

| Failure Mode | Detection | Recovery Action |
|--------------|-----------|-----------------|
| **Agent stuck on technology research** | STATUS.yaml shows no progress for 30+ minutes | Intervene: Ask agent to use known-good stack (Node.js, PostgreSQL, RabbitMQ, Redis) rather than exhaustive research |
| **Agent produces implementation code** | Output includes .js files or code snippets | Reject deliverables, clarify scope: "Architecture only, defer implementation to Execution phase" |
| **Architecture too vague** | Service boundaries undefined or <4 services identified | Request revision: "Define specific responsibilities for each service, identify APIs and dependencies" |
| **Token budget overrun** | agent-001 approaches 25K tokens without completion | Options: (1) Accept partial output if core deliverables met, (2) Reallocate 5K from buffer, (3) Split into agent-001a (architecture) and agent-001b (technology stack) |

### 4.6 Launch Execution

I launched agent-001 using the Task tool with the prompt defined in Section 4.3.

**Decision**: Launch command executed at T+0:00

**Task Tool Parameters**:
```yaml
subagent_type: Plan
prompt: |
  {detailed prompt from Section 4.3}
conversation_context: |
  Workflow: notification-system-20251124
  Phase: Planning
  Budget: 25,000 tokens
  Expected deliverables: architecture.md, decision records, service definitions
```

**Post-Launch Actions**:
1. **Update workflow-state.yaml**:
   - Set `current_phase.name = "planning"`
   - Set `current_phase.started_at = "2025-11-24T10:00:00Z"`
   - Add agent-001 to `active_agents[]`
2. **Create STATUS.yaml**:
   - Initialize with agent-001 as active
   - Set initial status = "analyzing-requirements"
3. **Set monitoring reminder**: Check progress at T+1:00 (2025-11-24T11:00:00Z)

**Expected Completion**: T+1:30 (2025-11-24T11:30:00Z) based on 1.5-hour estimate

---

## 5. Monitoring Strategy

**Timestamp**: T+0:00 (2025-11-24T10:00:00Z)

### 5.1 Monitoring Approach

I established a systematic approach to monitor agent progress without micromanaging.

**Decision**: Periodic status checks via `STATUS.yaml` review

**Monitoring Frequency**:
- **Active phase**: Check STATUS.yaml every 20 minutes
- **Waiting phase**: Check workflow-state.yaml every 60 minutes (no active agents)
- **On-demand**: Immediate check if interruption suspected (e.g., system slowdown, disk activity drops)

**Rationale**:
- **20-minute intervals**: Balances responsiveness with avoiding excessive overhead
  - Too frequent (e.g., every 5 minutes): Overhead from file reads, potential to interrupt agent mid-thought
  - Too infrequent (e.g., every 60 minutes): Risk missing critical questions or stuck agents
- **STATUS.yaml as source of truth**: Contains real-time agent status updates (current task, progress, questions)
- **Non-intrusive**: File-based monitoring doesn't require API calls or agent interruption

**Monitoring Implementation**:
```bash
# Check current agent status
cat .development/workflows/notification-system-20251124/STATUS.yaml

# Look for:
# - current_task: What is agent working on right now?
# - progress_percent: Is progress increasing over time?
# - questions: Does agent need orchestrator input?
# - estimated_completion: Is agent on track vs original estimate?
```

### 5.2 Intervention Triggers

I defined specific conditions that require orchestrator intervention.

**Decision**: Intervene when any of these triggers occur:

| Trigger | Detection Method | Intervention Action | Urgency |
|---------|------------------|---------------------|---------|
| **Agent asks question** | `questions_pending[]` populated in STATUS.yaml | Answer immediately. Questions block agent progress. | **IMMEDIATE** (within 5 minutes) |
| **Token budget approaching limit** | `tokens_used` ≥ 90% of phase budget | Reallocate from buffer or scope reduction. Example: agent-001 at 22.5K of 25K budget → allocate 5K from buffer or ask agent to finalize current deliverables. | **HIGH** (within 10 minutes) |
| **Agent stuck (no progress)** | `progress_percent` unchanged for 30+ minutes OR `current_task` unchanged for 30+ minutes | Investigate logs, assess if agent is blocked. Options: (1) Ask clarifying question, (2) Provide additional context, (3) Terminate and restart with revised prompt. | **MEDIUM** (within 30 minutes) |
| **Estimated completion drift** | `estimated_completion` pushed back >30 minutes from original estimate | Assess scope creep. Example: agent-001 originally estimated T+1:30 completion, now shows T+2:15 → review STATUS.yaml to identify what's taking longer than expected. | **MEDIUM** (within 30 minutes) |
| **Filesystem errors** | Error messages in agent logs (permission denied, disk full) | Immediate remediation: free disk space, adjust permissions, restart agent if necessary. | **IMMEDIATE** (within 5 minutes) |

**Non-Intervention Scenarios** (when NOT to intervene):
- Agent is progressing normally (progress_percent increasing, no questions)
- Token usage is within budget (even if higher than estimate, as long as <90%)
- Estimated completion is within ±15 minutes of original estimate (acceptable variance)

### 5.3 Question Handling Protocol

I established a protocol for responding to agent questions to maintain workflow momentum.

**Decision**: Immediate response to questions with decision documentation

**Question Response Workflow**:

1. **Detection**: Check `questions_pending[]` in STATUS.yaml during periodic monitoring
2. **Assessment**: Evaluate question urgency and complexity:
   - **Simple clarification** (e.g., "Should WebSocket service support rooms?"): Answer immediately based on requirements
   - **Technology decision** (e.g., "FCM vs APNs for push notifications?"): Quick research (5-10 minutes) to inform answer
   - **Scope question** (e.g., "Should I implement retry logic in Planning phase?"): Redirect to appropriate phase ("No, defer to Execution phase")
3. **Response**: Update STATUS.yaml with answer and rationale
4. **Documentation**: Log decision in `workflow-state.yaml` under `questions_resolved[]` for future reference

**Example Question Handling** (from actual workflow):

**Question**: "Should we use Firebase Cloud Messaging (FCM) or Apple Push Notification service (APNs) or both?"
- **Asked by**: agent-002-notification-providers
- **Timestamp**: T+2:50 (2025-11-24T12:50:00Z)
- **Assessment**: Technology decision, requires platform distribution research
- **Research**: Quick check of e-commerce platform user distribution → 60% Android, 40% iOS
- **Answer**: "Both - FCM for Android, APNs for iOS. Research shows 60% Android / 40% iOS user distribution."
- **Documented in**: `workflow-state.yaml` under `questions_resolved[]`
- **Response time**: 5 minutes (within IMMEDIATE threshold)

### 5.4 Archive Trigger

I defined when to archive completed agent outputs to keep the active workspace clean.

**Decision**: Archive immediately after agent completion and validation

**Archive Workflow**:

1. **Trigger**: Agent status changes to `completed` in STATUS.yaml
2. **Validation**: Verify agent met success criteria (see Section 4.5 for agent-001 example)
3. **Archive Creation**:
   - Create timestamped subdirectory: `archive/{phase}-{YYYYMMDD}-{HHMM}/`
   - Move agent outputs from `active/` to archive subdirectory
   - Update `workflow-state.yaml` with archive path
4. **Phase Completion Check**:
   - If all agents for current phase complete → mark phase as `completed`
   - If questions remain or additional agents needed → keep phase as `active`

**Archive Directory Example** (agent-001):
```
archive/planning-20251124-1130/
├── agent-001-system-design.md          # Primary output
├── shared/
│   ├── architecture.md                 # Architecture diagram
│   └── decisions.md                    # Technology decision records
└── metadata.yaml                       # Agent execution metadata (tokens used, duration, questions asked)
```

**Archive Timestamp Convention**: `{phase}-{YYYYMMDD}-{HHMM}` format
- Example: `planning-20251124-1130` → Planning phase completed on 2025-11-24 at 11:30 AM
- Rationale: Chronological sorting in filesystem, easy to identify latest archive per phase

**Phase Transition**:
- After archiving agent-001 (Planning phase), I will:
  1. Mark `phases.planning.status = "completed"`
  2. Set `current_phase.name = "research"`
  3. Launch agents-002 and 003 in parallel (Research phase)

### 5.5 Interruption Detection

I established indicators that would signal an unexpected interruption vs normal completion.

**Decision**: Monitor for abnormal termination signals

**Interruption Indicators**:

| Indicator | Detection | Meaning |
|-----------|-----------|---------|
| **Agent process terminated** | STATUS.yaml shows agent as `active` but no recent updates (>5 minutes) AND agent process not running | System crash, OOM kill, or manual termination |
| **Incomplete outputs** | Agent marked `completed` but deliverables missing (e.g., architecture.md doesn't exist) | Agent terminated before finalizing outputs |
| **Partial file writes** | Files exist but have `-INCOMPLETE` or `-TODO` suffixes | Agent was writing outputs when interrupted |
| **Workflow state stale** | `workflow-state.yaml` updated_at timestamp >30 minutes old while agent should be active | Orchestrator crash or filesystem issues |

**Interruption Response** (see Section 6 in `2-handling-interruption.md` for details):
1. Preserve all filesystem state (do NOT delete or reset)
2. Document interruption in `workflow-state.yaml` notes
3. Create snapshot of current state in `snapshots/at-interruption/`
4. When resuming: Read workflow-state.yaml to determine phase, identify completed vs incomplete work, resume or restart agent as appropriate

**Non-Interruption Scenarios**:
- Agent completes and STATUS.yaml is updated to `completed` → Normal completion, proceed to archive
- Agent takes longer than estimated but continues progressing → Normal variance, not an interruption
- Agent asks question and pauses waiting for answer → Normal workflow, not an interruption

---

## 6. Next Steps (Post-Planning Launch)

**Timestamp**: T+0:00 (2025-11-24T10:00:00Z)

### 6.1 Immediate Actions

I have launched agent-001-system-design and will now monitor its progress.

**Actions Taken**:
- ✅ Workflow ID established: `notification-system-20251124`
- ✅ Directory structure created: `.development/workflows/notification-system-20251124/`
- ✅ workflow-state.yaml initialized with 5-phase structure and token budgets
- ✅ agent-001-system-design launched for Planning phase
- ✅ STATUS.yaml created with agent-001 as active
- ✅ Monitoring schedule set: Check STATUS.yaml at T+0:20, T+0:40, T+1:00

**Waiting For**:
- agent-001 to produce architecture.md with microservices design
- agent-001 to define 4 service boundaries (WebSocket, Push, Email, SMS)
- agent-001 to select technology stack (expecting Node.js, PostgreSQL, RabbitMQ, Redis)
- agent-001 completion (estimated T+1:30, 2025-11-24T11:30:00Z)

### 6.2 Planning Phase Success Criteria

I will validate agent-001 outputs against these criteria before proceeding to Research phase.

**Validation Checklist**:
- [ ] architecture.md exists in shared/ directory
- [ ] 4+ services identified with clear boundaries
- [ ] Technology stack decisions documented (language, database, message queue, caching)
- [ ] Latency requirements specified for each notification type
- [ ] No implementation code (only architecture and design)
- [ ] Token usage ≤25,000 (Planning phase budget)

**If all criteria met**: Archive agent-001 outputs, mark Planning phase complete, launch Research phase (agents-002 and 003 in parallel)

**If criteria not met**: Intervene based on what's missing (see Section 5.2 intervention triggers)

### 6.3 Transition to Research Phase (Anticipated)

Assuming agent-001 succeeds, I will transition to Research phase with parallel agents.

**Anticipated Transition** (T+1:45, 2025-11-24T11:45:00Z):

**Pre-Launch Preparation**:
1. Archive agent-001 outputs to `archive/planning-20251124-1130/`
2. Update workflow-state.yaml:
   - Mark Planning phase as `completed`
   - Set Research phase as `active`
   - Log tokens used in Planning (expecting ~18.5K of 25K budget)
3. Read architecture.md to extract notification types for Research phase agents

**Parallel Agent Launch**:
- **agent-002-notification-providers**:
  - Scope: Evaluate push (FCM, APNs), email (SendGrid, Mailgun), SMS (Twilio, Nexmo) providers
  - Budget: 15,000 tokens (50% of Research phase budget)
  - Expected duration: 45 minutes
  - Deliverable: Provider comparison matrix with recommendations
- **agent-003-websocket-patterns**:
  - Scope: Investigate WebSocket libraries (Socket.io vs ws), scaling patterns (Redis adapter), room management
  - Budget: 15,000 tokens (50% of Research phase budget)
  - Expected duration: 1 hour 15 minutes (longer due to pattern complexity)
  - Deliverable: WebSocket architecture design with scaling recommendations

**Rationale for parallel execution**: agent-002 and agent-003 have no dependencies on each other (providers vs patterns are independent research topics), so running in parallel saves ~45 minutes vs sequential execution.

### 6.4 Budget Tracking

I will continuously track token usage to ensure we stay within the 110K total budget.

**Current Status** (T+0:00):
- **Total budget**: 110,000 tokens
- **Allocated**: 110,000 tokens (Planning: 25K, Research: 30K, Design: 0K, Execution: 35K, Review: 20K)
- **Used**: 0 tokens (no agents completed yet)
- **Buffer remaining**: 37,000 tokens (unallocated safety margin)

**After Planning Phase** (anticipated T+1:30):
- **Total budget**: 110,000 tokens
- **Used**: ~18,500 tokens (agent-001)
- **Remaining for phases**: 91,500 tokens (Research: 30K, Design: 0K, Execution: 35K, Review: 20K, Buffer: 37K)
- **Savings from Planning**: 6,500 tokens (under budget by 26%)
- **Reallocation decision**: Shift 3K to Execution (highest risk phase), keep 3.5K in buffer

**Budget Alert Thresholds**:
- **Warning**: Cumulative usage reaches 90K (leaving only 20K buffer)
- **Critical**: Cumulative usage reaches 100K (leaving only 10K buffer)
- **Action**: If Critical threshold reached, assess remaining work and either: (1) Reduce scope (skip nice-to-haves), (2) Request user approval for budget increase, (3) Accept partial deliverables

### 6.5 Risk Mitigation

I have identified potential risks and established mitigation strategies.

**Risk Register**:

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Agent-001 overruns token budget** | Medium | Medium | Intervene at 22.5K tokens (90% of 25K), ask agent to finalize deliverables. Reallocate 5K from buffer if necessary. |
| **Architecture too vague for Research** | Low | High | Validation checklist (Section 6.2) catches this. Request revision before archiving. |
| **Research agents select incompatible providers** | Low | Medium | Both agents reference shared/architecture.md to align decisions. Orchestrator reviews for conflicts before Execution. |
| **Execution phase exceeds 35K budget** | Medium | High | Split agent-004 into multiple agents if needed (e.g., agent-004a: WebSocket+Push, agent-004b: Email+SMS). Use buffer allocation. |
| **Interruption during Execution** | Low | High | File-based state preservation (workflow-state.yaml, STATUS.yaml, agent outputs) ensures 0% data loss. Resume with continuation context (see `2-handling-interruption.md`). |
| **Design phase unexpectedly needed** | Medium | Low | Currently budgeted 0 tokens. Reallocate from 37K buffer if Planning reveals complex data models. |

**Mitigation Success Indicators**:
- All phases complete within allocated budgets → No risk materialized
- Buffer remains >20K at workflow completion → Adequate risk cushion
- No agent restarts required → Planning and scoping was accurate

---

## 7. Orchestrator State Summary

**Timestamp**: T+0:00 (2025-11-24T10:00:00Z)

### 7.1 Current State

**Workflow Status**: Active (Planning phase in progress)

**Active Agents**:
- agent-001-system-design (Planning phase, launched T+0:00, estimated completion T+1:30)

**Completed Agents**: None (workflow just started)

**Current Phase**: Planning (0% complete, waiting for agent-001)

**Token Usage**: 0 of 110,000 (0%)

**Questions Pending**: None (agent-001 just launched)

**Decisions Made**:
1. Use 5-phase workflow (Planning → Research → Design → Execution → Review)
2. Anticipate skipping Design phase (0 token budget)
3. Allocate 35K tokens to Execution (largest phase by deliverables)
4. Launch agent-001 for system architecture design
5. Monitor STATUS.yaml every 20 minutes during active phases

### 7.2 Next Checkpoint

**Next Monitoring Checkpoint**: T+0:20 (2025-11-24T10:20:00Z)

**What I'll Check**:
- STATUS.yaml for agent-001 progress (expecting `progress_percent` ~15-20%)
- Questions pending (expecting 0, but prepared to answer immediately)
- Current task (expecting "analyzing-requirements" or "evaluating-architecture-options")
- Token usage (expecting ~3-4K tokens used by T+0:20)

**Decision Points at T+0:20**:
- If agent-001 on track → Continue monitoring at T+0:40
- If agent-001 asks question → Answer immediately
- If agent-001 stuck (no progress) → Investigate and intervene
- If token usage high (>6K at T+0:20) → Assess scope and potentially narrow focus

### 7.3 Success Metrics

I will evaluate this workflow's success based on these metrics:

**Delivery Metrics**:
- ✅ **All 4 notification services implemented** (WebSocket, Push, Email, SMS)
- ✅ **Consistent architecture** across services (shared patterns, error handling)
- ✅ **Complete documentation** (API specs, configuration guides, integration tests)

**Efficiency Metrics**:
- ✅ **Token usage ≤110K** (within budget)
- ✅ **Active time ≤12 hours** (within expected effort)
- ✅ **Design phase skipped** (anticipated optimization)

**Quality Metrics**:
- ✅ **No agent restarts** (accurate scoping and prompting)
- ✅ **Questions answered within 10 minutes** (responsive orchestration)
- ✅ **Integration tests pass** (Review phase validates all services work together)

**Resilience Metrics** (if interruption occurs):
- ✅ **0% data loss** (file-based state preservation)
- ✅ **Resumption time <10% of total workflow** (continuation context efficiency)
- ✅ **Token savings vs restart >50%** (effective checkpoint resumption)

---

## Appendix A: File Paths Reference

**Workflow Directory** (relative to this example): `.development/workflows/notification-system-20251124/`

**Key Files**:
- **workflow-state.yaml**: `.development/workflows/notification-system-20251124/workflow-state.yaml`
- **STATUS.yaml**: `.development/workflows/notification-system-20251124/STATUS.yaml`
- **Shared architecture**: `.development/workflows/notification-system-20251124/shared/architecture.md`
- **Planning archive**: `.development/workflows/notification-system-20251124/archive/planning-20251124-1130/`

---

## Appendix B: Decision Log

| Decision ID | Decision | Rationale | Timestamp |
|-------------|----------|-----------|-----------|
| D-001 | Workflow ID = `notification-system-20251124` | Date-based naming for chronological ordering and easy identification | T+0:00 |
| D-002 | 5-phase workflow (Planning → Research → Design → Execution → Review) | Balances thoroughness with efficiency, allows skip optimization | T+0:00 |
| D-003 | Design phase budget = 0 tokens (anticipated skip) | Notification systems have straightforward data models, likely definable during Execution | T+0:00 |
| D-004 | Execution phase budget = 35,000 tokens (highest) | 4 services × ~1,000 lines each = largest deliverable volume | T+0:00 |
| D-005 | Research phase uses parallel agents (002, 003) | Provider research and WebSocket patterns are independent, parallel saves ~45 minutes | T+0:00 |
| D-006 | Monitor STATUS.yaml every 20 minutes | Balances responsiveness with non-intrusive monitoring | T+0:00 |
| D-007 | Launch agent-001 for Planning phase first | Planning has no prerequisites and establishes foundation for Research | T+0:00 |

---

**End of Initial Planning Script**

**Orchestrator**: Initial planning complete. agent-001-system-design launched at T+0:00 (2025-11-24T10:00:00Z). Next checkpoint: T+0:20 for progress review.

**Workflow State**: Active (Planning phase 0% complete)
**Token Budget**: 0 of 110,000 used (100% remaining)
**Next Phase**: Research (anticipated T+1:45 after Planning completes)
