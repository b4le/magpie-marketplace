# Email Notification Service

## Service Overview

**Purpose**: Send transactional emails via SendGrid with dynamic template rendering and delivery tracking

**Use Cases**:
- Order confirmations and receipts
- Password reset and account verification
- Shipping notifications with tracking links
- Marketing campaigns and newsletters
- Administrative notifications

**Technology Stack**:
- Node.js 20+
- Express.js 4.18+
- SendGrid API (for email delivery)
- Handlebars 4.x (for template rendering)
- Bull 4.x (queue management with Redis)
- PostgreSQL (email history tracking)

**Port**: 3003

---

## Architecture

### Email Sending Flow

```
API Request              Email Service                SendGrid              Recipient
    │                         │                          │                     │
    ├──1. POST /send-email───>│                          │                     │
    │   (recipient, template,  │                         │                     │
    │    data)                 │                         │                     │
    │                          ├──2. Enqueue job─────────>│                     │
    │                          │   (Bull queue)           │                     │
    │<──3. 202 Accepted────────┤                          │                     │
    │   (job_id)               │                          │                     │
    │                          │                          │                     │
    │                      ┌───▼────┐                     │                     │
    │                      │ Worker │                     │                     │
    │                      │Process │                     │                     │
    │                      └───┬────┘                     │                     │
    │                          ├──4. Render template──────>│                     │
    │                          │   (Handlebars)           │                     │
    │                          ├──5. Send via API─────────>│                     │
    │                          │                          ├──6. Deliver────────>│
    │                          │<──7. Success─────────────┤                     │
    │                          │   (message_id)           │                     │
    │                          │                          │<──8. Opened/Clicked─┤
    │                          │<──9. Webhook─────────────┤   (tracking)        │
    │                          │   (delivery status)      │                     │
    │                          ├──10. Update DB           │                     │
    │                          │   (delivered_at)         │                     │
```

### Queue-Based Processing

**Why Queue?**
- Decouple API requests from slow email sending
- Retry failed sends automatically
- Rate limiting and throttling
- Batch processing for efficiency

**Bull Queue Architecture**:

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│   API       │       │    Redis    │       │   Worker    │
│  Endpoint   │──add─>│    Queue    │<─pop──│   Process   │
└─────────────┘       └─────────────┘       └──────┬──────┘
                            │                       │
                            │                       ▼
                      ┌─────▼─────┐         ┌─────────────┐
                      │  Failed   │         │  SendGrid   │
                      │   Queue   │         │     API     │
                      └───────────┘         └─────────────┘
```

### Template Rendering Pipeline

```
1. Load Template        2. Inject Data         3. Render HTML
   (from disk)            (Handlebars)           (final email)
        │                       │                      │
        ▼                       ▼                      ▼
┌────────────────┐    ┌────────────────┐    ┌────────────────┐
│ order-         │    │ {               │    │ <html>         │
│ confirmation.  │───>│   user: {...},  │───>│ <body>         │
│ hbs            │    │   order: {...}  │    │ Hello, John!   │
└────────────────┘    │ }               │    │ Order #999...  │
                      └────────────────┘    └────────────────┘
```

### Webhook Handling for Delivery Tracking

**SendGrid Event Webhook**:

```
SendGrid                              Email Service
   │                                        │
   ├──1. Email Delivered────────────────────>│
   │   POST /webhooks/sendgrid               │
   │   {event: "delivered", ...}             │
   │                                         ├──2. Update DB
   │                                         │   (delivered_at)
   ├──2. Email Opened──────────────────────>│
   │   {event: "open", ...}                  │
   │                                         ├──3. Update DB
   │                                         │   (opened_at)
   ├──3. Link Clicked──────────────────────>│
   │   {event: "click", ...}                 │
   │                                         ├──4. Update DB
   │                                         │   (clicked_at)
```

---

## API Endpoints

### 1. Send Email

```http
POST /send-email HTTP/1.1
Host: localhost:3003
Content-Type: application/json
Authorization: Bearer <API_KEY>

{
  "to": "john@example.com",
  "template": "order-confirmation",
  "subject": "Order Confirmation - #ORD-999",
  "data": {
    "user": {
      "firstName": "John",
      "lastName": "Doe"
    },
    "order": {
      "orderId": "ORD-999",
      "total": 149.99,
      "items": [
        {"name": "Product A", "quantity": 2, "price": 49.99},
        {"name": "Product B", "quantity": 1, "price": 50.01}
      ]
    }
  },
  "priority": "high"
}

HTTP/1.1 202 Accepted
Content-Type: application/json

{
  "jobId": "job-abc123",
  "status": "queued",
  "estimatedSendTime": "2025-11-24T13:45:05Z"
}
```

### 2. Send Batch Emails

```http
POST /send-batch HTTP/1.1
Host: localhost:3003
Content-Type: application/json
Authorization: Bearer <API_KEY>

{
  "template": "newsletter",
  "subject": "Monthly Newsletter - November 2025",
  "recipients": [
    {
      "email": "john@example.com",
      "data": {"firstName": "John", "customContent": "..."}
    },
    {
      "email": "jane@example.com",
      "data": {"firstName": "Jane", "customContent": "..."}
    }
  ],
  "priority": "normal"
}

HTTP/1.1 202 Accepted
Content-Type: application/json

{
  "batchId": "batch-xyz789",
  "totalEmails": 2,
  "status": "queued",
  "estimatedCompletion": "2025-11-24T13:50:00Z"
}
```

### 3. SendGrid Delivery Webhook

```http
POST /webhooks/sendgrid HTTP/1.1
Host: localhost:3003
Content-Type: application/json
X-SendGrid-Signature: <HMAC-SHA256-signature>

[
  {
    "email": "john@example.com",
    "event": "delivered",
    "sg_message_id": "msg-abc123",
    "timestamp": 1700846700,
    "smtp-id": "<abc123@sendgrid.net>"
  },
  {
    "email": "john@example.com",
    "event": "open",
    "sg_message_id": "msg-abc123",
    "timestamp": 1700846800,
    "useragent": "Mozilla/5.0..."
  }
]

HTTP/1.1 200 OK
```

**Event Types**:
- `delivered` - Email successfully delivered to recipient's inbox
- `open` - Recipient opened email (tracked via pixel)
- `click` - Recipient clicked link (tracked via redirect)
- `bounce` - Email bounced (hard or soft bounce)
- `dropped` - SendGrid dropped email (invalid address, spam)
- `deferred` - Temporary failure, will retry
- `spam_report` - Recipient marked as spam

---

## SendGrid Integration

### SendGrid API Setup

```javascript
const sgMail = require('@sendgrid/mail');

// Initialize with API key
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

// Set default sender
const defaultSender = {
  email: process.env.SENDGRID_FROM_EMAIL,
  name: process.env.SENDGRID_FROM_NAME
};
```

### Email Payload Format

```javascript
const emailPayload = {
  to: 'john@example.com',
  from: {
    email: 'notifications@example.com',
    name: 'Example Store'
  },
  subject: 'Order Confirmation - #ORD-999',
  html: '<html><body>...</body></html>', // Rendered template
  text: 'Plain text version...', // Fallback for non-HTML clients
  categories: ['order-confirmation', 'transactional'], // For analytics
  customArgs: {
    orderId: 'ORD-999',
    userId: 'user-12345'
  },
  trackingSettings: {
    clickTracking: { enable: true },
    openTracking: { enable: true }
  },
  mailSettings: {
    sandboxMode: { enable: process.env.NODE_ENV !== 'production' }
  }
};
```

### Sending via SendGrid

```javascript
async function sendViaProvider(email, htmlContent, textContent) {
  try {
    const msg = {
      to: email.to,
      from: email.from || defaultSender,
      subject: email.subject,
      html: htmlContent,
      text: textContent || stripHtml(htmlContent), // Auto-generate if not provided
      categories: email.categories || ['transactional'],
      customArgs: email.customArgs || {},
      trackingSettings: {
        clickTracking: { enable: true },
        openTracking: { enable: true }
      }
    };

    const response = await sgMail.send(msg);

    logger.info('Email sent via SendGrid', {
      to: email.to,
      subject: email.subject,
      messageId: response[0].headers['x-message-id']
    });

    return {
      status: 'sent',
      messageId: response[0].headers['x-message-id'],
      timestamp: new Date().toISOString()
    };
  } catch (error) {
    logger.error('SendGrid send failed', {
      error: error.message,
      code: error.code,
      to: email.to
    });

    throw error;
  }
}
```

### Personalization and Dynamic Content

**SendGrid Personalization** (for batch sends):

```javascript
const msg = {
  from: defaultSender,
  subject: 'Monthly Newsletter',
  html: templateHtml,
  personalizations: [
    {
      to: [{ email: 'john@example.com' }],
      dynamicTemplateData: {
        firstName: 'John',
        customContent: 'Content for John...'
      }
    },
    {
      to: [{ email: 'jane@example.com' }],
      dynamicTemplateData: {
        firstName: 'Jane',
        customContent: 'Content for Jane...'
      }
    }
  ]
};

await sgMail.send(msg);
```

**Handlebars Personalization** (our approach):

```javascript
// Render template per recipient
for (const recipient of recipients) {
  const html = handlebars.compile(templateContent)(recipient.data);
  await sendViaProvider({
    to: recipient.email,
    subject: subject,
    html: html
  });
}
```

---

## Template Rendering

### Handlebars Setup and Configuration

```javascript
const Handlebars = require('handlebars');
const fs = require('fs').promises;
const path = require('path');

// Template directory
const TEMPLATE_DIR = process.env.EMAIL_TEMPLATE_DIR || './templates/email';

// Template cache (in-memory for performance)
const templateCache = new Map();

// Register helpers
Handlebars.registerHelper('currency', (value) => {
  return `$${parseFloat(value).toFixed(2)}`;
});

Handlebars.registerHelper('formatDate', (date, format) => {
  return new Date(date).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });
});

Handlebars.registerHelper('uppercase', (str) => {
  return str.toUpperCase();
});

Handlebars.registerHelper('eq', (a, b) => {
  return a === b;
});
```

### Template Directory Structure

```
templates/email/
├── layouts/
│   └── main.hbs                 # Base HTML layout
├── partials/
│   ├── header.hbs               # Email header
│   ├── footer.hbs               # Email footer
│   └── button.hbs               # Reusable button component
├── order-confirmation.hbs        # Order confirmation template
├── password-reset.hbs            # Password reset template
├── shipping-notification.hbs     # Shipping notification
└── newsletter.hbs                # Newsletter template
```

**Example: layouts/main.hbs**

```handlebars
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{subject}}</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .button { background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; }
  </style>
</head>
<body>
  <div class="container">
    {{> header}}
    {{{body}}}
    {{> footer}}
  </div>
</body>
</html>
```

**Example: order-confirmation.hbs**

```handlebars
<h1>Order Confirmation</h1>

<p>Hi {{user.firstName}},</p>

<p>Thank you for your order! Your order <strong>#{{order.orderId}}</strong> has been confirmed.</p>

<h2>Order Details</h2>
<table style="width: 100%; border-collapse: collapse;">
  <thead>
    <tr>
      <th style="text-align: left; border-bottom: 1px solid #ddd; padding: 8px;">Item</th>
      <th style="text-align: right; border-bottom: 1px solid #ddd; padding: 8px;">Qty</th>
      <th style="text-align: right; border-bottom: 1px solid #ddd; padding: 8px;">Price</th>
    </tr>
  </thead>
  <tbody>
    {{#each order.items}}
    <tr>
      <td style="padding: 8px;">{{this.name}}</td>
      <td style="text-align: right; padding: 8px;">{{this.quantity}}</td>
      <td style="text-align: right; padding: 8px;">{{currency this.price}}</td>
    </tr>
    {{/each}}
  </tbody>
  <tfoot>
    <tr>
      <td colspan="2" style="text-align: right; padding: 8px; font-weight: bold;">Total:</td>
      <td style="text-align: right; padding: 8px; font-weight: bold;">{{currency order.total}}</td>
    </tr>
  </tfoot>
</table>

<p style="margin-top: 20px;">
  {{> button text="View Order Details" url=(concat "https://example.com/orders/" order.orderId)}}
</p>

<p>Thanks for shopping with us!</p>
```

### Template Data Injection

```javascript
async function renderTemplate(templateName, data) {
  try {
    // Load template (with caching)
    const template = await loadTemplate(templateName);

    // Compile template
    const compiled = Handlebars.compile(template);

    // Inject data and render
    const html = compiled(data);

    logger.debug('Template rendered', {
      template: templateName,
      dataKeys: Object.keys(data)
    });

    return html;
  } catch (error) {
    logger.error('Template rendering failed', {
      template: templateName,
      error: error.message
    });

    throw new Error(`TEMPLATE_RENDER_ERROR: ${error.message}`);
  }
}

async function loadTemplate(templateName) {
  // Check cache first
  if (templateCache.has(templateName)) {
    return templateCache.get(templateName);
  }

  // Load from disk
  const templatePath = path.join(TEMPLATE_DIR, `${templateName}.hbs`);

  try {
    const content = await fs.readFile(templatePath, 'utf-8');

    // Cache template (invalidate on file change in dev)
    if (process.env.NODE_ENV === 'production') {
      templateCache.set(templateName, content);
    }

    return content;
  } catch (error) {
    throw new Error(`Template not found: ${templateName}`);
  }
}
```

**Example Usage**:

```javascript
const data = {
  user: {
    firstName: 'John',
    lastName: 'Doe',
    email: 'john@example.com'
  },
  order: {
    orderId: 'ORD-999',
    total: 149.99,
    items: [
      { name: 'Product A', quantity: 2, price: 49.99 },
      { name: 'Product B', quantity: 1, price: 50.01 }
    ]
  }
};

const html = await renderTemplate('order-confirmation', data);
```

### Template Partials and Layouts

**Registering Partials**:

```javascript
async function registerPartials() {
  const partialsDir = path.join(TEMPLATE_DIR, 'partials');

  const files = await fs.readdir(partialsDir);

  for (const file of files) {
    if (file.endsWith('.hbs')) {
      const partialName = path.basename(file, '.hbs');
      const partialContent = await fs.readFile(path.join(partialsDir, file), 'utf-8');

      Handlebars.registerPartial(partialName, partialContent);

      logger.debug('Registered partial', { name: partialName });
    }
  }
}

// Call on service startup
await registerPartials();
```

**Example Partial: button.hbs**

```handlebars
<a href="{{url}}" class="button" style="display: inline-block; background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
  {{text}}
</a>
```

**Using Layouts**:

```javascript
async function renderWithLayout(templateName, layoutName, data) {
  // Render main template
  const bodyHtml = await renderTemplate(templateName, data);

  // Render layout with body
  const layout = await loadTemplate(`layouts/${layoutName}`);
  const layoutCompiled = Handlebars.compile(layout);

  const finalHtml = layoutCompiled({
    ...data,
    body: bodyHtml
  });

  return finalHtml;
}

// Usage
const html = await renderWithLayout('order-confirmation', 'main', data);
```

### Template Testing

```javascript
const { describe, it, expect } = require('@jest/globals');

describe('Email Template Rendering', () => {
  it('should render order confirmation template', async () => {
    const data = {
      user: { firstName: 'John' },
      order: {
        orderId: 'ORD-999',
        total: 149.99,
        items: [{ name: 'Product A', quantity: 2, price: 49.99 }]
      }
    };

    const html = await renderTemplate('order-confirmation', data);

    expect(html).toContain('Hi John');
    expect(html).toContain('#ORD-999');
    expect(html).toContain('$149.99');
    expect(html).toContain('Product A');
  });

  it('should handle missing data gracefully', async () => {
    const data = {
      user: { firstName: 'Jane' }
      // Missing order data
    };

    const html = await renderTemplate('order-confirmation', data);

    expect(html).toContain('Hi Jane');
    // Should not crash, but may have empty sections
  });

  it('should apply currency helper', async () => {
    const data = {
      order: { total: 99.5 }
    };

    const template = '{{currency order.total}}';
    const compiled = Handlebars.compile(template);
    const result = compiled(data);

    expect(result).toBe('$99.50');
  });
});
```

### Template Versioning

**File-Based Versioning**:

```
templates/email/
├── order-confirmation.hbs          # v1 (default)
├── order-confirmation.v2.hbs       # v2 (new design)
└── order-confirmation.v3.hbs       # v3 (A/B test)
```

**Version Selection Logic**:

```javascript
async function renderTemplateVersion(templateName, version, data) {
  const versionedName = version > 1 ? `${templateName}.v${version}` : templateName;

  try {
    return await renderTemplate(versionedName, data);
  } catch (error) {
    logger.warn('Template version not found, falling back to default', {
      template: templateName,
      version,
      error: error.message
    });

    // Fallback to default version
    return await renderTemplate(templateName, data);
  }
}

// Usage: Gradual rollout or A/B testing
const version = user.isInBetaGroup ? 2 : 1;
const html = await renderTemplateVersion('order-confirmation', version, data);
```

**Database-Driven Versioning** (advanced):

```sql
CREATE TABLE email_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  version INT NOT NULL DEFAULT 1,
  content TEXT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (name, version)
);

-- Track which version sent to each user
CREATE TABLE email_template_usage (
  email_id UUID REFERENCES notifications(id),
  template_name VARCHAR(100),
  template_version INT,
  sent_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Email Queue Management

### Bull Queue Configuration

```javascript
const Queue = require('bull');
const Redis = require('ioredis');

// Redis connection for queue
const redisClient = new Redis(process.env.REDIS_URL);

// Create email queue
const emailQueue = new Queue('email-notifications', {
  redis: process.env.REDIS_URL,
  defaultJobOptions: {
    attempts: 3, // Retry up to 3 times
    backoff: {
      type: 'exponential',
      delay: 2000 // 2s, 4s, 8s
    },
    removeOnComplete: 100, // Keep last 100 completed jobs
    removeOnFail: 500 // Keep last 500 failed jobs
  }
});

// Queue event listeners
emailQueue.on('completed', (job, result) => {
  logger.info('Email job completed', {
    jobId: job.id,
    recipient: job.data.to,
    messageId: result.messageId
  });
});

emailQueue.on('failed', (job, err) => {
  logger.error('Email job failed', {
    jobId: job.id,
    recipient: job.data.to,
    error: err.message,
    attempts: job.attemptsMade
  });
});

emailQueue.on('stalled', (job) => {
  logger.warn('Email job stalled', {
    jobId: job.id,
    recipient: job.data.to
  });
});
```

### Job Processing and Retry Logic

```javascript
// Process email jobs (worker)
emailQueue.process(async (job) => {
  const { to, template, data, subject, priority } = job.data;

  logger.info('Processing email job', {
    jobId: job.id,
    to,
    template,
    attempt: job.attemptsMade + 1
  });

  try {
    // 1. Render template
    const html = await renderTemplate(template, data);

    // 2. Send via SendGrid
    const result = await sendViaProvider({
      to,
      subject,
      html,
      categories: [template],
      customArgs: {
        jobId: job.id,
        userId: data.user?.id
      }
    });

    // 3. Update database
    await updateEmailStatus(job.id, 'sent', result.messageId);

    return result;
  } catch (error) {
    logger.error('Email processing failed', {
      jobId: job.id,
      to,
      error: error.message,
      attempt: job.attemptsMade + 1
    });

    // Update database with failure
    await updateEmailStatus(job.id, 'failed', null, error.message);

    throw error; // Bull will retry based on attempts config
  }
});

// Add job to queue (from API endpoint)
async function enqueueEmail(emailData) {
  const job = await emailQueue.add(emailData, {
    priority: emailData.priority === 'high' ? 1 : 5,
    jobId: `email-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
  });

  logger.info('Email enqueued', {
    jobId: job.id,
    to: emailData.to,
    template: emailData.template
  });

  return {
    jobId: job.id,
    status: 'queued',
    estimatedSendTime: new Date(Date.now() + 5000).toISOString() // ~5s delay
  };
}
```

### Queue Monitoring and Metrics

```javascript
// Queue health check
async function getQueueHealth() {
  const [waiting, active, completed, failed, delayed] = await Promise.all([
    emailQueue.getWaitingCount(),
    emailQueue.getActiveCount(),
    emailQueue.getCompletedCount(),
    emailQueue.getFailedCount(),
    emailQueue.getDelayedCount()
  ]);

  return {
    waiting,
    active,
    completed,
    failed,
    delayed,
    total: waiting + active + delayed
  };
}

// Expose metrics endpoint
app.get('/metrics/queue', async (req, res) => {
  const health = await getQueueHealth();

  res.json({
    queue: 'email-notifications',
    ...health,
    timestamp: new Date().toISOString()
  });
});

// Alert if queue is backed up
setInterval(async () => {
  const health = await getQueueHealth();

  if (health.waiting > 1000) {
    await sendAlert('email_queue_backlog', {
      waiting: health.waiting,
      active: health.active
    });
  }

  if (health.failed > 100) {
    await sendAlert('email_high_failure_rate', {
      failed: health.failed
    });
  }
}, 60000); // Check every minute
```

### Dead Letter Queue for Failures

```javascript
// Move permanently failed jobs to dead letter queue
emailQueue.on('failed', async (job, err) => {
  if (job.attemptsMade >= job.opts.attempts) {
    logger.error('Email job permanently failed, moving to DLQ', {
      jobId: job.id,
      recipient: job.data.to,
      error: err.message
    });

    // Add to dead letter queue for manual review
    await deadLetterQueue.add({
      originalJobId: job.id,
      data: job.data,
      error: err.message,
      attempts: job.attemptsMade,
      failedAt: new Date().toISOString()
    });

    // Notify ops team
    await sendAlert('email_permanent_failure', {
      jobId: job.id,
      recipient: job.data.to,
      error: err.message
    });
  }
});

// Dead letter queue (for manual intervention)
const deadLetterQueue = new Queue('email-dlq', {
  redis: process.env.REDIS_URL,
  defaultJobOptions: {
    removeOnComplete: false, // Keep all DLQ items
    removeOnFail: false
  }
});

// Manual retry from DLQ
async function retryFromDLQ(dlqJobId) {
  const dlqJob = await deadLetterQueue.getJob(dlqJobId);

  if (!dlqJob) {
    throw new Error('DLQ job not found');
  }

  // Re-add to main queue
  const newJob = await emailQueue.add(dlqJob.data.data);

  // Remove from DLQ
  await dlqJob.remove();

  logger.info('Job retried from DLQ', {
    dlqJobId,
    newJobId: newJob.id
  });

  return newJob.id;
}
```

---

## Error Handling

### Invalid Email Addresses

```javascript
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validateEmailAddress(email) {
  if (!emailRegex.test(email)) {
    throw new Error('INVALID_EMAIL_ADDRESS');
  }

  // Additional validation: Check for disposable domains
  const disposableDomains = ['tempmail.com', 'guerrillamail.com'];
  const domain = email.split('@')[1];

  if (disposableDomains.includes(domain)) {
    logger.warn('Disposable email domain detected', { email, domain });
    // Optionally reject or flag for review
  }

  return true;
}

// Use in API endpoint
app.post('/send-email', async (req, res) => {
  const { to, template, data, subject } = req.body;

  try {
    validateEmailAddress(to);

    const result = await enqueueEmail({ to, template, data, subject });

    res.status(202).json(result);
  } catch (error) {
    if (error.message === 'INVALID_EMAIL_ADDRESS') {
      return res.status(400).json({
        error: 'INVALID_EMAIL_ADDRESS',
        message: 'The provided email address is invalid'
      });
    }

    throw error;
  }
});
```

### SendGrid API Errors

```javascript
async function handleSendGridError(error, job) {
  const { code, response } = error;

  // Rate limit (429)
  if (code === 429 || response?.statusCode === 429) {
    logger.warn('SendGrid rate limit hit', {
      jobId: job.id,
      retryAfter: response?.headers['retry-after']
    });

    // Retry with delay
    throw new Error('RATE_LIMITED'); // Bull will retry with backoff
  }

  // Authentication error (401)
  if (code === 401 || response?.statusCode === 401) {
    logger.error('SendGrid authentication failed', {
      jobId: job.id,
      error: 'Invalid API key'
    });

    await sendAlert('sendgrid_auth_failure', {
      message: 'Check SENDGRID_API_KEY configuration'
    });

    throw new Error('AUTHENTICATION_FAILED'); // Do not retry
  }

  // Invalid request (400)
  if (code === 400 || response?.statusCode === 400) {
    logger.error('SendGrid invalid request', {
      jobId: job.id,
      error: response?.body?.errors
    });

    // Do not retry (bad data)
    await updateEmailStatus(job.id, 'failed', null, 'Invalid request data');
    return; // Don't throw (no retry)
  }

  // Service unavailable (503)
  if (code === 503 || response?.statusCode === 503) {
    logger.warn('SendGrid service unavailable', {
      jobId: job.id
    });

    throw new Error('SERVICE_UNAVAILABLE'); // Retry
  }

  // Unknown error
  logger.error('SendGrid unknown error', {
    jobId: job.id,
    code,
    statusCode: response?.statusCode,
    error: error.message
  });

  throw error; // Retry
}
```

### Template Rendering Errors

```javascript
async function renderTemplateWithErrorHandling(templateName, data) {
  try {
    return await renderTemplate(templateName, data);
  } catch (error) {
    if (error.message.includes('Template not found')) {
      logger.error('Template not found', {
        template: templateName,
        availableTemplates: await listAvailableTemplates()
      });

      throw new Error(`TEMPLATE_NOT_FOUND: ${templateName}`);
    }

    if (error.message.includes('Parse error')) {
      logger.error('Template syntax error', {
        template: templateName,
        error: error.message
      });

      throw new Error(`TEMPLATE_SYNTAX_ERROR: ${error.message}`);
    }

    // Missing data in template
    if (error.message.includes('Cannot read property')) {
      logger.error('Template data missing', {
        template: templateName,
        error: error.message,
        providedKeys: Object.keys(data)
      });

      // Use fallback template or generic message
      return await renderTemplate('generic-notification', {
        message: 'You have a new notification'
      });
    }

    throw error;
  }
}
```

### Queue Processing Failures

```javascript
// Handle queue processing errors
emailQueue.on('error', (error) => {
  logger.error('Queue error', {
    error: error.message,
    stack: error.stack
  });

  sendAlert('email_queue_error', {
    error: error.message
  });
});

// Handle stalled jobs (jobs that haven't completed in time)
emailQueue.on('stalled', async (job) => {
  logger.warn('Job stalled', {
    jobId: job.id,
    recipient: job.data.to,
    processedOn: job.processedOn
  });

  // Optionally re-queue or investigate
  const timeSinceProcessed = Date.now() - job.processedOn;

  if (timeSinceProcessed > 300000) { // 5 minutes
    logger.error('Job stalled for over 5 minutes, manual intervention required', {
      jobId: job.id
    });

    await sendAlert('email_job_stalled', {
      jobId: job.id,
      duration: timeSinceProcessed
    });
  }
});
```

---

## Configuration

### Environment Variables

```bash
# Server
EMAIL_SERVICE_PORT=3003
NODE_ENV=production

# SendGrid
SENDGRID_API_KEY=SG.xxxxxxxxxxxxxxxxxxxx
SENDGRID_FROM_EMAIL=notifications@example.com
SENDGRID_FROM_NAME="Example Store"
SENDGRID_WEBHOOK_SECRET=your-webhook-secret

# Templates
EMAIL_TEMPLATE_DIR=./templates/email
TEMPLATE_CACHE_ENABLED=true  # Cache templates in production

# Queue (Bull)
REDIS_URL=redis://localhost:6379
EMAIL_QUEUE_NAME=email-notifications
EMAIL_QUEUE_CONCURRENCY=5  # Process 5 jobs concurrently

# Retry Settings
EMAIL_MAX_ATTEMPTS=3
EMAIL_RETRY_BACKOFF=2000  # 2s, 4s, 8s

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/notifications

# Monitoring
QUEUE_ALERT_THRESHOLD_WAITING=1000
QUEUE_ALERT_THRESHOLD_FAILED=100
```

### Queue Settings

```javascript
const queueConfig = {
  concurrency: parseInt(process.env.EMAIL_QUEUE_CONCURRENCY) || 5,
  limiter: {
    max: 1000, // Max 1,000 jobs processed per duration
    duration: 60000 // Per minute (SendGrid limit: 100/sec burst, sustained lower)
  },
  defaultJobOptions: {
    attempts: parseInt(process.env.EMAIL_MAX_ATTEMPTS) || 3,
    backoff: {
      type: 'exponential',
      delay: parseInt(process.env.EMAIL_RETRY_BACKOFF) || 2000
    },
    removeOnComplete: 100,
    removeOnFail: 500
  }
};
```

### Template Cache Settings

```javascript
const templateCacheConfig = {
  enabled: process.env.TEMPLATE_CACHE_ENABLED === 'true',
  maxSize: 50, // Max 50 templates in cache
  ttl: 3600000 // 1 hour TTL (in dev, disable or use short TTL)
};

// Implement LRU cache
const LRU = require('lru-cache');

const templateCache = new LRU({
  max: templateCacheConfig.maxSize,
  ttl: templateCacheConfig.ttl,
  updateAgeOnGet: true
});

// Clear cache on file change (in dev)
if (process.env.NODE_ENV !== 'production') {
  const chokidar = require('chokidar');

  chokidar.watch(TEMPLATE_DIR).on('change', (path) => {
    const templateName = path.match(/([^/]+)\.hbs$/)?.[1];
    if (templateName) {
      templateCache.delete(templateName);
      logger.debug('Template cache invalidated', { template: templateName });
    }
  });
}
```

---

## Testing & Monitoring

### Template Rendering Tests

```javascript
describe('Template Rendering', () => {
  it('should render all templates without errors', async () => {
    const templates = await listAvailableTemplates();

    for (const template of templates) {
      const mockData = getMockDataForTemplate(template);
      const html = await renderTemplate(template, mockData);

      expect(html).toBeTruthy();
      expect(html).not.toContain('undefined');
    }
  });

  it('should apply all custom helpers', () => {
    const tests = [
      { helper: 'currency', input: 99.5, expected: '$99.50' },
      { helper: 'uppercase', input: 'hello', expected: 'HELLO' },
      { helper: 'formatDate', input: '2025-11-24', expected: /November 24, 2025/ }
    ];

    tests.forEach(({ helper, input, expected }) => {
      const template = `{{${helper} value}}`;
      const compiled = Handlebars.compile(template);
      const result = compiled({ value: input });

      if (expected instanceof RegExp) {
        expect(result).toMatch(expected);
      } else {
        expect(result).toBe(expected);
      }
    });
  });
});
```

### Integration Tests with SendGrid Sandbox

```javascript
describe('SendGrid Integration', () => {
  beforeAll(() => {
    // Enable sandbox mode
    process.env.SENDGRID_SANDBOX_MODE = 'true';
  });

  it('should send email via SendGrid sandbox', async () => {
    const email = {
      to: 'test@example.com',
      subject: 'Test Email',
      html: '<p>Test content</p>',
      categories: ['test']
    };

    const result = await sendViaProvider(email, email.html);

    expect(result.status).toBe('sent');
    expect(result.messageId).toBeTruthy();
  });

  it('should handle SendGrid API errors', async () => {
    // Use invalid API key
    const originalKey = process.env.SENDGRID_API_KEY;
    process.env.SENDGRID_API_KEY = 'invalid-key';

    await expect(sendViaProvider({
      to: 'test@example.com',
      subject: 'Test',
      html: 'Test'
    })).rejects.toThrow('AUTHENTICATION_FAILED');

    process.env.SENDGRID_API_KEY = originalKey;
  });
});
```

### Delivery Tracking and Metrics

```javascript
async function trackEmailMetrics() {
  const metrics = await db.query(`
    SELECT
      COUNT(*) FILTER (WHERE status = 'sent') as sent,
      COUNT(*) FILTER (WHERE status = 'delivered') as delivered,
      COUNT(*) FILTER (WHERE status = 'opened') as opened,
      COUNT(*) FILTER (WHERE status = 'clicked') as clicked,
      COUNT(*) FILTER (WHERE status = 'failed') as failed,
      COUNT(*) FILTER (WHERE status = 'bounced') as bounced
    FROM notifications
    WHERE channel = 'email' AND created_at > NOW() - INTERVAL '24 hours'
  `);

  const stats = metrics.rows[0];

  stats.deliveryRate = (stats.delivered / stats.sent) * 100;
  stats.openRate = (stats.opened / stats.delivered) * 100;
  stats.clickRate = (stats.clicked / stats.opened) * 100;

  await publishMetrics('email_delivery', stats);

  return stats;
}

// Expose metrics endpoint
app.get('/metrics/email', async (req, res) => {
  const stats = await trackEmailMetrics();
  res.json(stats);
});
```

**Key Metrics**:
- Delivery rate: `delivered / sent * 100`
- Open rate: `opened / delivered * 100`
- Click-through rate: `clicked / opened * 100`
- Bounce rate: `bounced / sent * 100`
- Failed rate: `failed / sent * 100`
