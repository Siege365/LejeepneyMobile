# LeJeepney System - Admin & User Interaction Diagrams

> **For PowerPoint Presentation**  
> These diagrams illustrate how the admin panel and mobile app interact through the Laravel backend.

---

## Diagram 1: High-Level System Architecture

**Use this for:** Initial overview slide showing the big picture

```mermaid
flowchart LR
    subgraph ADMIN["<b>👨‍💼 ADMIN SIDE</b><br/><i>Web Browser</i>"]
        A1["<b>Admin Panel</b><br/>━━━━━━━━━━━<br/>Routes Management<br/>Landmarks Management<br/>Ticket Management<br/>System Settings<br/>Audit Logs"]
    end

    subgraph USER["<b>📱 USER SIDE</b><br/><i>Mobile App - Flutter</i>"]
        U1["<b>Mobile Features</b><br/>━━━━━━━━━━━<br/>Route Finder<br/>Landmark Explorer<br/>Fare Calculator<br/>Support Tickets<br/>Activity History"]
    end

    subgraph BACKEND["<b>🔧 BACKEND LAYER</b><br/><i>Laravel 12 + PHP 8.2</i>"]
        B1["<b>Web Routes</b><br/>Session Auth"]
        B2["<b>API Routes</b><br/>Sanctum Token"]
        B3["<b>Shared Controllers</b><br/>Business Logic"]
    end

    subgraph DATA["<b>💾 DATA LAYER</b><br/><i>MySQL Database</i>"]
        D1[("Routes<br/>Landmarks<br/>Tickets<br/>Users<br/>Settings<br/>Audit Logs")]
    end

    subgraph EXT["<b>🌐 EXTERNAL SERVICES</b>"]
        E1["EmailJS<br/><small>Email Notifications</small>"]
        E2["OpenRouteService<br/><small>Walking Directions</small>"]
        E3["OSRM<br/><small>Fallback Routes</small>"]
    end

    A1 <-->|"Session<br/>Cookie"| B1
    U1 <-->|"Bearer<br/>Token"| B2

    B1 --> B3
    B2 --> B3
    B3 <--> D1

    A1 -.->|"Send<br/>Email"| E1
    B2 -.->|"Walking<br/>Paths"| E2
    B2 -.->|"Fallback"| E3

    style ADMIN fill:#dbeafe,stroke:#1e40af,stroke-width:3px
    style USER fill:#d1fae5,stroke:#047857,stroke-width:3px
    style BACKEND fill:#fef3c7,stroke:#d97706,stroke-width:3px
    style DATA fill:#ede9fe,stroke:#6d28d9,stroke-width:3px
    style EXT fill:#fecaca,stroke:#b91c1c,stroke-width:3px

    style A1 fill:#3b82f6,stroke:#1e40af,color:#fff
    style U1 fill:#10b981,stroke:#047857,color:#fff
    style B1 fill:#f59e0b,stroke:#d97706,color:#000
    style B2 fill:#f59e0b,stroke:#d97706,color:#000
    style B3 fill:#fbbf24,stroke:#d97706,color:#000
    style D1 fill:#8b5cf6,stroke:#6d28d9,color:#fff
```

### Key Points:

- **Admin Side**: Web-based panel with session authentication
- **User Side**: Flutter mobile app with token-based authentication
- **Backend**: Shared Laravel backend serving both web and API routes
- **Database**: Single MySQL database storing all system data
- **External Services**: EmailJS for notifications, OpenRouteService/OSRM for routing

---

## Diagram 2: Detailed Component Architecture

**Use this for:** Technical architecture slide showing all components

```mermaid
graph TB
    subgraph "👨‍💼 ADMIN SIDE"
        A1[Admin User]
        A2[Web Browser]
        A3[Admin Panel<br/>Laravel Blade + Tailwind]

        A1 -->|Login via Browser| A2
        A2 -->|Session-based Auth| A3

        A3 -->|Manage Routes| A4[Route Management]
        A3 -->|Manage Landmarks| A5[Landmark Management]
        A3 -->|Handle Tickets| A6[Customer Service]
        A3 -->|View Logs| A7[Audit Trail]
        A3 -->|Update Settings| A8[App Settings]
    end

    subgraph "📱 USER SIDE"
        U1[Mobile User]
        U2[Flutter Mobile App<br/>Android/iOS]

        U1 -->|Uses App| U2

        U2 -->|Search Routes| U4[Route Finder]
        U2 -->|Browse Places| U5[Landmark Explorer]
        U2 -->|Calculate Fare| U6[Fare Calculator]
        U2 -->|Submit Issue| U7[Support Tickets]
        U2 -->|View History| U8[Recent Activities]
    end

    subgraph "🔧 LARAVEL BACKEND"
        B1[API Layer<br/>/api/v1/*]
        B2[Web Layer<br/>/dashboard, /routes]
        B3[Controllers]
        B4[Eloquent ORM]
        B5[MySQL Database]

        B1 -->|Process Requests| B3
        B2 -->|Process Requests| B3
        B3 -->|Query Data| B4
        B4 -->|CRUD Operations| B5
    end

    subgraph "💾 DATABASE TABLES"
        D1[(routes)]
        D2[(landmarks)]
        D3[(support_tickets)]
        D4[(ticket_replies)]
        D5[(ticket_notifications)]
        D6[(recent_activities)]
        D7[(app_settings)]
        D8[(users)]
        D9[(activity_logs)]

        B5 -.-> D1
        B5 -.-> D2
        B5 -.-> D3
        B5 -.-> D4
        B5 -.-> D5
        B5 -.-> D6
        B5 -.-> D7
        B5 -.-> D8
        B5 -.-> D9
    end

    subgraph "🌐 EXTERNAL SERVICES"
        E1[EmailJS<br/>Client-side Email]
        E2[OpenRouteService<br/>Walking Routes]
        E3[OSRM<br/>Fallback Walking Routes]
    end

    %% Admin to Backend
    A4 -->|POST /routes| B2
    A5 -->|POST /landmarks| B2
    A6 -->|POST /tickets/:id/reply| B2
    A7 -->|GET /audit-logs| B2
    A8 -->|PUT /settings| B2

    %% User to Backend
    U4 -->|GET /api/v1/routes| B1
    U5 -->|GET /api/v1/landmarks| B1
    U6 -->|POST /api/v1/routes/find| B1
    U7 -->|POST /api/v1/tickets| B1
    U8 -->|GET /api/v1/recent-activities| B1

    %% Admin to External
    A6 -.->|Send Email| E1

    %% Backend to External
    B1 -.->|Walking Directions| E2
    B1 -.->|Fallback| E3

    %% Authentication
    A3 -->|Session Cookie| B2
    U2 -->|Bearer Token<br/>Laravel Sanctum| B1

    %% Key Flows
    B3 -->|Create Notification| D5
    D5 -->|Poll Updates| U2
    A6 -->|Reply to Ticket| D4
    D4 -->|Notify User| D5

    style A3 fill:#3b82f6,stroke:#1e40af,color:#fff
    style U2 fill:#10b981,stroke:#047857,color:#fff
    style B1 fill:#f59e0b,stroke:#d97706,color:#fff
    style B2 fill:#f59e0b,stroke:#d97706,color:#fff
    style B5 fill:#8b5cf6,stroke:#6d28d9,color:#fff
    style E1 fill:#ef4444,stroke:#b91c1c,color:#fff
    style E2 fill:#06b6d4,stroke:#0891b2,color:#fff
    style E3 fill:#06b6d4,stroke:#0891b2,color:#fff
```

### Database Tables:

- **routes**: Jeepney route data with path coordinates
- **landmarks**: Points of interest with images and descriptions
- **support_tickets**: User-submitted help requests
- **ticket_replies**: Admin/user conversation threads
- **ticket_notifications**: Real-time notification queue
- **recent_activities**: User activity history
- **app_settings**: System configuration (fares, etc.)
- **users**: Admin and mobile user accounts
- **activity_logs**: Admin action audit trail

---

## Diagram 3: Interaction Sequence Flows

**Use this for:** Demonstrating specific use cases and data flow

```mermaid
sequenceDiagram
    participant Admin as 👨‍💼 Admin Panel
    participant Backend as 🔧 Laravel Backend
    participant DB as 💾 Database
    participant API as 📡 API Layer
    participant Mobile as 📱 Mobile App
    participant Email as 📧 EmailJS

    Note over Admin,Mobile: SCENARIO 1: Admin Creates Route
    Admin->>Backend: POST /routes (Route data + path coordinates)
    Backend->>DB: Insert into routes table
    Backend->>DB: Log activity (activity_logs)
    Backend-->>Admin: Route created successfully

    Mobile->>API: GET /api/v1/routes
    API->>DB: SELECT * FROM routes
    DB-->>API: Return all routes
    API-->>Mobile: Routes available immediately

    Note over Admin,Mobile: SCENARIO 2: User Submits Support Ticket
    Mobile->>API: POST /api/v1/tickets (Issue description)
    API->>DB: INSERT into support_tickets (status: pending)
    API->>DB: CREATE ticket_notification
    API-->>Mobile: Ticket created (#12345)

    Admin->>Backend: GET /dashboard
    Backend->>DB: Get pending tickets count
    DB-->>Backend: 1 new ticket
    Backend-->>Admin: Show notification badge

    Admin->>Backend: View ticket #12345
    Admin->>Backend: POST /tickets/12345/reply + Send Email
    Backend->>DB: INSERT ticket_reply (sender: admin)
    Backend->>DB: CREATE ticket_notification (type: admin_message)
    Backend->>Email: Send branded email to user
    Email-->>Mobile: Email notification received
    Backend-->>Admin: Reply sent

    Mobile->>API: GET /api/v1/tickets/12345/notifications
    API->>DB: Get notifications for ticket
    DB-->>API: New admin reply available
    API-->>Mobile: Show in-app notification "Admin replied"

    Note over Admin,Mobile: SCENARIO 3: Admin Updates Fare Settings
    Admin->>Backend: PUT /settings (base_fare: 13.00 → 15.00)
    Backend->>DB: UPDATE app_settings (key: base_fare)
    Backend->>DB: Log change in activity_logs
    Backend-->>Admin: Settings saved

    Mobile->>API: POST /api/v1/routes/find (origin, destination)
    API->>DB: GET app_settings (base_fare, fare_per_km)
    DB-->>API: base_fare = 15.00
    API->>API: Calculate fare with new rate
    API-->>Mobile: Route + Fare (₱18.60 with new rate)

    Note over Admin,Mobile: SCENARIO 4: Admin Adds Landmark
    Admin->>Backend: POST /landmarks (Name, coords, images)
    Backend->>DB: INSERT into landmarks
    Backend->>DB: Log activity
    Backend-->>Admin: Landmark published

    Mobile->>API: GET /api/v1/landmarks
    API->>DB: SELECT * FROM landmarks
    DB-->>API: All landmarks including new one
    API-->>Mobile: Landmark appears in list
```

### Key Scenarios:

1. **Route Management**: Admin creates routes → Immediately available to mobile users
2. **Support Tickets**: Bidirectional communication with email notifications
3. **Settings Update**: Admin changes fare rates → Applied to all new calculations
4. **Content Publishing**: Admin adds landmarks → Real-time sync to mobile app

---

## Authentication Architecture

### Admin Panel (Web)

- **Method**: Session-based authentication with cookies
- **Guard**: Laravel `web` guard
- **Role**: Only users with `role = 'admin'` can access
- **Storage**: Database sessions table
- **Middleware**: `['auth', 'admin']`

### Mobile App (API)

- **Method**: Token-based authentication with Laravel Sanctum
- **Token Type**: Personal Access Token
- **Expiry**: 30 days (configurable)
- **Role**: Only users with `role = 'user'` can login
- **Rate Limit**: 60 requests per minute

### Role Separation

- Admin accounts **cannot** login via API (403 Forbidden)
- User accounts **cannot** access web panel (redirected to login)
- New admins can only be created by existing admins
- `role` field is protected from mass assignment

---

## How to Use These Diagrams in PowerPoint

### Method 1: Screenshot (Easiest)

1. Open this file in VS Code or GitHub
2. The diagrams will render automatically
3. Take screenshots and paste into PowerPoint

### Method 2: Mermaid Live Editor

1. Visit https://mermaid.live
2. Copy the Mermaid code from this file
3. Export as PNG or SVG
4. Insert into PowerPoint

### Method 3: VS Code Extension

1. Install "Markdown Preview Mermaid Support" extension
2. Preview this file (Ctrl+Shift+V)
3. Right-click diagram → Copy Image
4. Paste into PowerPoint

---

## Technology Stack Summary

| Layer               | Technology                              | Purpose                   |
| ------------------- | --------------------------------------- | ------------------------- |
| **Admin Frontend**  | Laravel Blade, Tailwind CSS, Leaflet.js | Web-based admin panel     |
| **Mobile Frontend** | Flutter (Dart), Provider, flutter_map   | Cross-platform mobile app |
| **Backend**         | Laravel 12, PHP 8.2                     | REST API + Web routes     |
| **Database**        | MySQL 8.0+                              | Data persistence          |
| **Authentication**  | Laravel Sanctum (API), Sessions (Web)   | Secure access control     |
| **External APIs**   | OpenRouteService, OSRM, EmailJS         | Walking routes, email     |

---

## Data Synchronization

### Real-Time Updates

- **Support Tickets**: Mobile app polls `/api/v1/tickets/{id}/notifications` every 30 seconds
- **Routes**: Refreshed when app launches or user manually refreshes
- **Landmarks**: Cached locally, synced on app start
- **Settings**: Fetched before each fare calculation

### Offline Support

- Routes and landmarks are cached in the mobile app
- Users can browse cached data without internet
- Calculations work offline using cached fare settings
- Support ticket submissions queue until online

---

## Security Features

### API Security

- Rate limiting (60 req/min per IP)
- Bearer token authentication
- Input validation and sanitization
- CORS protection
- SQL injection prevention (Eloquent ORM)

### Admin Security

- Session encryption
- CSRF protection
- Login throttling (5 attempts/min)
- Activity logging for audit trail
- Role-based access control

### Data Protection

- Passwords hashed with bcrypt
- API keys stored server-side only
- Sensitive data excluded from logs
- Secure storage for mobile tokens

---

**Document Created**: March 5, 2026  
**System**: LeJeepney - Davao City Jeepney Navigation System  
**Purpose**: PowerPoint presentation diagrams
