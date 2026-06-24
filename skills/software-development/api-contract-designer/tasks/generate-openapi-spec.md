# Generate OpenAPI 3.1 Spec

יצירת OpenAPI 3.1 spec — הסטנדרט ל-REST API documentation.

## מבנה בסיסי

```yaml
openapi: 3.1.0
info:
  title: Acme Tasks API
  version: 1.0.0
  description: |
    API for the Acme task management system.
    Supports projects, tasks, team collaboration.
  contact:
    name: the user
    email: api@acme.example
  license:
    name: MIT
    url: https://opensource.org/licenses/MIT

servers:
  - url: https://api.acme.example/v1
    description: Production
  - url: https://staging-api.acme.example/v1
    description: Staging

tags:
  - name: projects
    description: Project management
  - name: tasks
    description: Task CRUD
  - name: auth
    description: Authentication endpoints
```

## Paths

```yaml
paths:
  /projects:
    get:
      tags: [projects]
      summary: List projects
      operationId: listProjects
      security:
        - bearerAuth: []
      parameters:
        - $ref: '#/components/parameters/PageSize'
        - $ref: '#/components/parameters/Cursor'
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ProjectList'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '429':
          $ref: '#/components/responses/RateLimited'

    post:
      tags: [projects]
      summary: Create a new project
      operationId: createProject
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateProjectInput'
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Project'
        '400':
          $ref: '#/components/responses/ValidationError'
```

## Components

```yaml
components:
  schemas:
    Project:
      type: object
      required: [id, name, ownerId, createdAt]
      properties:
        id:
          type: string
          format: uuid
        name:
          type: string
          minLength: 1
          maxLength: 100
        description:
          type: string
          maxLength: 1000
        ownerId:
          type: string
          format: uuid
        createdAt:
          type: string
          format: date-time
        archivedAt:
          type: string
          format: date-time
          nullable: true

    CreateProjectInput:
      type: object
      required: [name]
      properties:
        name:
          type: string
          minLength: 1
          maxLength: 100
        description:
          type: string
          maxLength: 1000

    Error:
      type: object
      required: [code, message]
      properties:
        code:
          type: string
          example: VALIDATION_ERROR
        message:
          type: string
          example: "name is required"
        field:
          type: string
          nullable: true
        requestId:
          type: string
          format: uuid

  parameters:
    PageSize:
      name: pageSize
      in: query
      schema:
        type: integer
        minimum: 1
        maximum: 100
        default: 20

    Cursor:
      name: cursor
      in: query
      schema:
        type: string

  responses:
    Unauthorized:
      description: Missing or invalid authentication
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'

    RateLimited:
      description: Rate limit exceeded
      headers:
        Retry-After:
          schema:
            type: integer
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'

    ValidationError:
      description: Input validation failed
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'

  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

## כלים ליצירה

### TypeScript → OpenAPI

```typescript
// zod-to-openapi
import { z } from 'zod';
import { extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi';

extendZodWithOpenApi(z);

const ProjectSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).max(100),
}).openapi('Project');

// Auto-generate OpenAPI from registered schemas
```

### OpenAPI → TypeScript types

```bash
npx openapi-typescript ./openapi.yaml -o ./src/types/api.ts
```

### OpenAPI → Backend validation

```typescript
// express-openapi-validator
import OpenApiValidator from 'express-openapi-validator';
app.use(OpenApiValidator.middleware({ apiSpec: './openapi.yaml' }));
```

### OpenAPI → Docs site

- **Swagger UI**: classic, embeddable
- **Redoc**: prettier, public docs
- **Stoplight Elements**: modern, GitHub-style

## verification

- [ ] כל endpoint מה-PRD מתועד
- [ ] כל schema עם required fields מסומנים
- [ ] error responses לכל endpoint
- [ ] security schemes מוגדרים
- [ ] examples בכל schema
- [ ] generated types עוברים compile
- [ ] docs נטענים בלי שגיאות

---

_footer: api-contract-designer/tasks/generate-openapi-spec.md · api-contract-designer v0.1.0_
