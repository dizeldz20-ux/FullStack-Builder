# Design GraphQL Schema

תכנון GraphQL schema — מ-User Stories ל-SDL מוכן לקוד.

## מתי להשתמש

- יש relations מורכבות בין resources (3+ joins)
- Clients צריכים fields שונים מאותו resource (mobile vs web)
- Real-time / subscriptions נדרשים
- המוצר internal API עם clients מרובים

**אל תשתמש אם**: API פשוט, resources בודדים, CRUD בלבד — REST/OpenAPI עדיף.

## ה-flow

### 1. זהה entities מה-PRD

```graphql
# Example: User Stories → Entities
# "User can create a project" → Project entity
# "User invites team members" → TeamMember entity
# "Project has tasks" → Task entity
# "Task has comments" → Comment entity
```

### 2. הגדר types

```graphql
# scalars מובנים: String, Int, Float, Boolean, ID
# scalars מותאמים: DateTime, EmailAddress, URL, JSON

scalar DateTime

type User {
  id: ID!
  email: String!
  name: String!
  createdAt: DateTime!
  projects(first: Int = 20, after: String): ProjectConnection!
}

type Project {
  id: ID!
  name: String!
  owner: User!
  members(first: Int = 20): [TeamMember!]!
  tasks(first: Int = 50, status: TaskStatus): [Task!]!
  createdAt: DateTime!
}

enum TaskStatus {
  TODO
  IN_PROGRESS
  DONE
  ARCHIVED
}

type Task {
  id: ID!
  title: String!
  status: TaskStatus!
  assignee: User
  project: Project!
  comments(first: Int = 20): [Comment!]!
}
```

### 3. הגדר Query root

```graphql
type Query {
  me: User!                                # current user
  user(id: ID!): User                      # public profile
  project(id: ID!): Project                # single project
  projects(first: Int = 20, after: String): ProjectConnection!
  searchTasks(query: String!, limit: Int = 10): [Task!]!
}
```

### 4. הגדר Mutation root

```graphql
type Mutation {
  createProject(input: CreateProjectInput!): CreateProjectPayload!
  updateProject(id: ID!, input: UpdateProjectInput!): UpdateProjectPayload!
  deleteProject(id: ID!): DeleteProjectPayload!

  createTask(input: CreateTaskInput!): CreateTaskPayload!
  updateTaskStatus(id: ID!, status: TaskStatus!): UpdateTaskPayload!

  inviteTeamMember(projectId: ID!, email: String!): InvitePayload!
}

# Convention: input types per mutation, payload types per mutation
input CreateProjectInput {
  name: String!
  description: String
}

type CreateProjectPayload {
  project: Project
  userErrors: [UserError!]!
}

type UserError {
  field: [String!]
  message: String!
  code: String!
}
```

### 5. הוסף Subscription (אם צריך real-time)

```graphql
type Subscription {
  taskUpdated(projectId: ID!): Task!
  newComment(taskId: ID!): Comment!
  projectActivity(projectId: ID!): ActivityEvent!
}
```

## patterns חשובים

### Connection pattern (pagination)

```graphql
type ProjectConnection {
  edges: [ProjectEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type ProjectEdge {
  cursor: String!
  node: Project!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
```

### Error handling

```graphql
# תמיד userErrors ב-payload, לא throws
type CreateTaskPayload {
  task: Task
  userErrors: [UserError!]!
}

# nullability conventions:
# - List returns [] (never null)
# - Single object returns null if not found (use ! sparingly)
```

### Auth directives

```graphql
directive @auth(requires: Role!) on FIELD_DEFINITION
directive @owner(resource: String!) on FIELD_DEFINITION

type Mutation {
  deleteProject(id: ID!): DeleteProjectPayload! @auth(requires: USER)
  updateBilling(id: ID!): UpdateBillingPayload! @auth(requires: ADMIN)
}
```

## כלים

- **Schema-first**: כתוב `.graphql` files, codegen ל-types
- **Code-first**: כתוב types ב-TypeScript, GraphQL נוצר
- **Hygraph / Hasura**: מוכן, פחות שליטה
- **Apollo Server / Yoga**: הכי פופולרי
- **Pothos / Nexus**: TypeScript-first SDL

## verification

לפני שעוברים לקוד:

- [ ] כל User Story מה-PRD מכוסה ב-query/mutation
- [ ] אין N+1 queries (DataLoader patterns)
- [ ] Auth מוגדר לכל field רגיש
- [ ] Pagination על כל list
- [ ] userErrors pattern עקבי
- [ ] nullability conventions עקביות

---

_footer: api-contract-designer/tasks/design-graphql-schema.md · api-contract-designer v0.1.0_
