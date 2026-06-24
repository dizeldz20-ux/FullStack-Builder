---
name: zod-validation-patterns
description: Runtime validation patterns using Zod to enforce API contracts on both client and server boundaries.
---

# Zod Validation Patterns

אימות runtime ל-contracts. אל תסמוך על TypeScript types ב-runtime — הם נמחקים בקומפייל.

## הבעיה

```typescript
// ❌ רק TypeScript - לא באמת בודק ב-runtime
interface CreateProjectInput {
  name: string;
  description?: string;
}

function createProject(input: CreateProjectInput) {
  // מה אם input.name באמת number?
  // מה אם input.description הוא object?
}
```

## הפתרון: Zod

```typescript
import { z } from 'zod';

const CreateProjectInputSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(1000).optional(),
});

type CreateProjectInput = z.infer<typeof CreateProjectInputSchema>;

function createProject(input: unknown) {
  const validated = CreateProjectInputSchema.parse(input);
  // validated.name is guaranteed string 1-100 chars
  // validated.description is string or undefined
}
```

## patterns נפוצים

### Request validation (server)

```typescript
import { z } from 'zod';

const schemas = {
  createProject: z.object({
    body: z.object({
      name: z.string().min(1).max(100),
      description: z.string().max(1000).optional(),
    }),
  }),
  listProjects: z.object({
    query: z.object({
      pageSize: z.coerce.number().int().min(1).max(100).default(20),
      cursor: z.string().optional(),
    }),
  }),
};

// Express middleware
function validate(schema: z.ZodSchema) {
  return (req: any, res: any, next: any) => {
    const result = schema.safeParse({
      body: req.body,
      query: req.query,
      params: req.params,
    });
    if (!result.success) {
      return res.status(400).json({
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid input',
          details: result.error.flatten(),
        },
      });
    }
    req.validated = result.data;
    next();
  };
}

app.post('/projects', validate(schemas.createProject), (req, res) => {
  const { name, description } = req.validated.body;
  // safe to use
});
```

### Response validation (client)

```typescript
// הגנה מפני API breaking changes
const ProjectSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  ownerId: z.string().uuid(),
  createdAt: z.string().datetime(),
});

async function fetchProject(id: string): Promise<Project> {
  const res = await fetch(`/api/projects/${id}`);
  const data = await res.json();
  return ProjectSchema.parse(data);
  // זורק אם ה-API שינה shape
}
```

### Form validation (client-side)

```typescript
import { z } from 'zod';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';

const FormSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  description: z.string().max(1000).optional(),
});

type FormData = z.infer<typeof FormSchema>;

function ProjectForm() {
  const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
    resolver: zodResolver(FormSchema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register('name')} />
      {errors.name && <span>{errors.name.message}</span>}
    </form>
  );
}
```

### Env validation

```typescript
// src/env.ts
import { z } from 'zod';

const EnvSchema = z.object({
  DATABASE_URL: z.string().url(),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
});

export const env = EnvSchema.parse(process.env);
// קורס ב-startup אם env חסר - טוב!
```

### Branded types via Zod

```typescript
const UserIdSchema = z.string().uuid().brand<'UserId'>();
type UserId = z.infer<typeof UserIdSchema>;

const ProjectIdSchema = z.string().uuid().brand<'ProjectId'>();
type ProjectId = z.infer<typeof ProjectIdSchema>;

function getProject(id: ProjectId): Promise<Project> {
  // id מובטח ProjectId, לא UserId
}

// שימוש:
const userId = UserIdSchema.parse('550e8400-e29b-41d4-a716-446655440000');
const projectId = ProjectIdSchema.parse('660e8400-e29b-41d4-a716-446655440000');
// getProject(userId); // TS error - good!
```

## OpenAPI + Zod integration

```typescript
import { z } from 'zod';
import { extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi';

extendZodWithOpenApi(z);

const ProjectSchema = z.object({
  id: z.string().uuid().openapi({ example: '550e8400-e29b-41d4-a716-446655440000' }),
  name: z.string().min(1).max(100).openapi({ example: 'My Project' }),
  ownerId: z.string().uuid(),
  createdAt: z.string().datetime(),
}).openapi('Project');

// Generate OpenAPI from Zod:
import { generateDocument } from '@asteasolutions/zod-to-openapi';
const document = generateDocument(appSchemas);
```

## verification

- [ ] כל endpoint עם input → Zod schema
- [ ] response validation בכל API call (client)
- [ ] env validation ב-startup
- [ ] branded types ל-IDs
- [ ] error messages בעברית למשתמש, באנגלית ל-API
- [ ] `safeParse` לא `parse` (לא לזרוק בפרודקשן)

---

_footer: api-contract-designer/tasks/zod-validation-patterns.md · api-contract-designer v0.1.0_
