# TypeScript Types From API Contract

המרת API contract → TypeScript types אוטומטית. אל תכתוב types ידנית.

## OpenAPI → TypeScript

### התקנה

```bash
npm install --save-dev openapi-typescript
```

### שימוש

```bash
# Build-time
npx openapi-typescript ./openapi.yaml -o ./src/types/api.ts

# Watch mode
npx openapi-typescript ./openapi.yaml -o ./src/types/api.ts --watch
```

### דוגמה: generated types

```typescript
// src/types/api.ts
export interface paths {
  '/projects': {
    parameters: { query?: { pageSize?: number; cursor?: string } };
    get: operations['listProjects'];
    post: operations['createProject'];
  };
}

export interface operations {
  listProjects: {
    responses: {
      200: { content: { 'application/json': components['schemas']['ProjectList'] } };
      401: components['responses']['Unauthorized'];
    };
  };
}

export interface components {
  schemas: {
    Project: {
      id: string;
      name: string;
      ownerId: string;
      createdAt: string;
    };
    CreateProjectInput: { name: string; description?: string };
  };
}
```

### שימוש בקוד

```typescript
import type { components, operations } from './types/api';

type Project = components['schemas']['Project'];
type CreateProjectInput = components['schemas']['CreateProjectInput'];

async function listProjects(): Promise<Project[]> {
  const res = await fetch('/api/projects', {
    headers: { Authorization: `Bearer ${getToken()}` },
  });
  const data: operations['listProjects']['responses'][200]['content']['application/json'] = await res.json();
  return data.items;
}
```

## GraphQL → TypeScript

### התקנה

```bash
npm install --save-dev @graphql-codegen/cli @graphql-codegen/typescript @graphql-codegen/typescript-operations
```

### config

```yaml
# codegen.yml
schema: ./schema.graphql
generates:
  ./src/types/graphql.ts:
    plugins:
      - typescript
      - typescript-operations
    config:
      avoidOptionals: true
      skipTypename: true
```

### שימוש

```bash
npx graphql-codegen --config codegen.yml
```

```typescript
// generated
export type Project = {
  id: string;
  name: string;
  owner: User;
  tasks: Array<Task>;
};

export type ListProjectsQuery = {
  projects: {
    edges: Array<{ node: Project; cursor: string }>;
    pageInfo: PageInfo;
  };
};
```

## patterns חשובים

### Branded types ל-IDs

```typescript
// מונע בלבול בין UserId ל-ProjectId
type Brand<T, B> = T & { __brand: B };
type UserId = Brand<string, 'UserId'>;
type ProjectId = Brand<string, 'ProjectId'>;

function getProject(id: ProjectId): Promise<Project> { /* ... */ }

// getProject(getUser().id); // TS error - good!
```

### API client עם types

```typescript
// typed-fetch.ts
import type { paths, operations } from './types/api';

type PathParams<P extends keyof paths> = paths[P]['parameters'];
type Op<P extends keyof paths, M extends keyof paths[P]> = paths[P][M] extends operations[OpName]
  ? paths[P][M]
  : never;

async function api<P extends keyof paths, M extends keyof paths[P]>(
  path: P,
  method: M,
  options?: { params?: PathParams<P>; body?: unknown }
) {
  // typed implementation
}

// usage:
const projects = await api('/projects', 'get');
const newProject = await api('/projects', 'post', {
  body: { name: 'New' },
});
```

### אל תשכפל types

❌ **לא**:
```typescript
// duplicate
interface Project {
  id: string;
  name: string;
}
```

✅ **כן**:
```typescript
import type { Project } from './types/api';
// re-use
```

## verification

- [ ] `npm run generate` עובר בלי שגיאות
- [ ] types מתעדכנים אוטומטית בכל שינוי ב-spec
- [ ] אין `any` בקוד שמשתמש ב-API
- [ ] branded types ל-IDs
- [ ] `tsc --noEmit` עובר נקי

---

_footer: api-contract-designer/tasks/typescript-types-from-contract.md · api-contract-designer v0.1.0_
