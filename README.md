# Revenue Management System - Complete Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Installation & Setup](#installation--setup)
4. [Configuration](#configuration)
5. [Database Models](#database-models)
6. [Core Features](#core-features)
7. [API Endpoints](#api-endpoints)
8. [Security Features](#security-features)
9. [User Management](#user-management)
10. [Invoice & Payment Processing](#invoice--payment-processing)
11. [OTP Verification System](#otp-verification-system)
12. [Batch Operations](#batch-operations)
13. [Administrative Tools](#administrative-tools)

## System Overview

The **Revenue Management System** is a comprehensive Flask-based web application designed for Municipal Assembies to manage property rates, business operating permits, payments, and invoicing.

### Key Capabilities
- Property rate management
- Business occupant permit tracking
- Invoice generation and management
- Payment processing with OTP verification
- Bulk upload/export functionality
- Credit balance tracking
- Audit logging
- User authentication and authorization

### Technology Stack
- **Backend**: Flask (Python)
- **Database**: PostgreSQL/SQLite
- **ORM**: SQLAlchemy
- **Authentication**: Flask-Login
- **SMS**: Multiple providers (Twilio, Africa's Talking, Vonage)
- **Frontend**: Jinja2 templates, JavaScript
- **File Processing**: Pandas

## Architecture

### Application Structure
```
revenue_management_system/
├── app.py                 # Main application file
├── templates/             # HTML templates
├── static/               # CSS, JS, images
├── uploads/              # File uploads
├── logs/                 # Application logs
├── backups/              # Database backups
├── migrations/           # Database migrations
└── .env                  # Environment variables
```

### Design Patterns
- **MVC Architecture**: Models, Views (templates), Controllers (routes)
- **Repository Pattern**: Database operations abstracted
- **Factory Pattern**: Application initialization
- **Decorator Pattern**: Route protection (@login_required)

# Optional SMS providers
pip install twilio  # For Twilio SMS
pip install africastalking  # For Africa's Talking
pip install vonage  # For Vonage/Nexmo

**Initialize Database**
```bash
flask db init
flask db migrate -m "Initial migration"
flask db upgrade

**Run Application**
```bash
# Development
flask run

# Production (use gunicorn)
gunicorn -w 4 -b 0.0.0.0:8000 app:app

## Database Models

User Model
**Purpose**: Manages user authentication and authorization

Property Model
**Purpose**: Stores property information for rate billing

BusinessOccupant Model
**Purpose**: Manages business operating permits

Product Model
**Purpose**: Defines business permit rates based on categories
**Category Matching**: All 6 categories must match exactly to determine rate

PropertyInvoice Model
**Purpose**: Property rate invoices
**Invoice Number Format**: `INVNBPR-{property_id:05d}-{year}`
**Status Values**:
- `Unpaid`: No payments made
- `Partially Paid`: Some payments made
- `Paid`: Fully paid

BOPInvoice Model
**Purpose**: Business Operating Permit invoices
**Invoice Number Format**: `INVNBOP-{business_id}-{year}`
**Status Values**:
- `Unpaid`: No payments made
- `Partially Paid`: Some payments made
- `Paid`: Fully paid

Payment Model
**Purpose**: Records all payment transactions
**Payment Modes**:
- Cash
- MoMo (Mobile Money)
- Cheque
**Payment Types**:
- Full Amount: Pays entire outstanding balance
- Part Payment: Partial payment
- Overpayment: Payment exceeding balance (creates credit)

OTPVerification Model
**Purpose**: Manages OTP codes for payment verification
**Security Features**:
- 6-digit random code
- 5-minute expiration
- 3-attempt limit
- One-time use

InvoiceAdjustment Model
**Purpose**: Tracks invoice adjustments with approval workflow
**Adjustment Types**:
- Credit: Reduces invoice amount
- Penalty: Increases invoice amount
- Waiver: Reduces invoice amount
- Amount Adjustment: General adjustment
**Approval Rules**:
- >10% change OR >GHS 1000: Requires admin approval
- Otherwise: Auto-approved

AuditLog Model
**Purpose**: Comprehensive audit trail of all system actions

## Core Features

### 1. Property Management

#### Create Property
**Route**: `POST /property/create`

**Required Fields**:
- account_no (unique)
- owner_name
- electoral_area
- town
- block_no, parcel_no, division_no
- category, property_class, zone, use_code
- valuation_status
- rateable_value
- rate_impost (default: 0.001350)

**Process**:
1. Validate account number uniqueness
2. Create property record
3. Auto-generate initial invoice for current year

#### View Property
**Route**: `GET /property/<id>`

**Displays**:
- Property details
- All invoices (chronological)
- Credit balance analysis
- Arrears breakdown

#### Bulk Upload Properties
**Route**: `POST /property/bulk-upload`

**Supported Formats**: CSV, XLSX

**Update Modes**:
- `skip`: Skip existing accounts
- `update`: Update existing records
- `fail`: Fail on duplicates

**Process**:
1. Validate file format and size
2. Check for duplicate account numbers
3. Validate required fields
4. Create/update properties
5. Generate initial invoices

### 2. Business Occupant Management

#### Create Business
**Route**: `POST /business/create`

**Special Features**:
- Auto-generates 5-digit business_id
- Matches 6-level category hierarchy to Product
- Creates invoice if matching product found

**Category Matching Logic**:
```python
# All 6 categories must match exactly (including NULL)
product = Product.query.filter(
    Product.category1 == business.category1,
    Product.category2 == business.category2,
    # ... categories 3-6
).first()
```

#### Business Invoice Generation
**Two Methods**:

**1. Fee Fixing (Automatic)**:
- Matches business categories to Product table
- Uses product amount as invoice amount

**2. Fixed Amount (Manual)**:
- Admin enters specific amount
- No product matching required

### 3. Property Invoice Generation

#### Property Invoice Creation
**Route**: `POST /property/invoice/create/<property_id>`

**Amount Calculation Types**:

**1. Fee Fixing**:
```python
amount = property.rateable_value * property.rate_impost
```

**2. Fixed Amount**:
```python
amount = user_input_amount
```

**Generation Modes**:
- `generate_new`: Create new invoice (fails if year exists)
- `update_existing`: Update existing invoice for year

**Tax Calculation**:
```python
tax_amount = base_amount * (tax_rate / 100)
total_amount = base_amount + tax_amount
```

#### Business Invoice Creation
**Route**: `POST /business/invoice/create/<business_id>`

**Process**:
1. Select year and calculation method
2. Find matching product (if fee fixing)
3. Calculate amount
4. Generate unique invoice number
5. Set due date (default: 30 days)

### 4. Payment Processing

#### Payment Flow

**Step 1: Initiate Payment**
**Route**: `GET /invoice/{type}/<invoice_id>/pay`

**Displays**:
- Invoice details
- Outstanding balance
- Arrears breakdown
- Payment history

**Step 2: Send OTP**
**Route**: `POST /api/send-otp`

**Request**:
```json
{
  "phone_number": "0241234567",
  "invoice_id": 123,
  "invoice_type": "Property",
  "payment_amount": 500.00
}
```

**Response**:
```json
{
  "success": true,
  "otp_id": 456,
  "expires_in_minutes": 5,
  "provider": "africastalking"
}
```

**Step 3: Verify OTP**
**Route**: `POST /api/verify-otp`

**Request**:
```json
{
  "otp_id": 456,
  "otp_code": "123456"
}
```

**Step 4: Process Payment**
**Route**: `POST /invoice/{type}/<invoice_id>/process-payment`

**Required Fields**:
- otp_id (verified)
- payment_mode (Cash, MoMo, Cheque)
- payment_type (Full Amount, Part Payment, Overpayment)
- payment_amount
- gcr_number (required for all payments)
- paid_by (Owner, Others)

### 5. Credit Balance System

#### How Credits Work

**Credit Creation**:
```python
# Overpayment creates credit
invoice_amount = 1000.00
payment_amount = 1200.00
credit = 200.00
```

**Automatic Credit Application**:
**Credit Display**:
- Outstanding balance (before credit)
- Credit applied to current invoice
- Credit applied to arrears
- Remaining unused credit

### 6. Arrears Management

#### Arrears Calculation

**Process**:
1. Get all invoices up to current year
2. Calculate balance for each invoice
3. Apply accumulated credits chronologically
4. Separate current invoice from arrears
5. Sum arrears after credit application

**Display Components**:
- Total arrears (before credit)
- Credit applied to arrears
- Total arrears (after credit)
- Detailed breakdown by year

## Security Features

### 1. Authentication

#### Password Requirements
```python
def validate_password_strength(password):
    # Minimum 8 characters
    # At least 1 uppercase
    # At least 1 lowercase
    # At least 1 number
    # At least 1 special character
    return is_valid, message
```

#### Temporary Password System
**Flow**:
1. Admin creates user with auto-generated temporary password
2. Password shown once to admin
3. User logs in with temporary password
4. System forces password change
5. User cannot access system until password is changed

#### Password Reset
**Flow**:
1. User requests reset via email/phone
2. System generates secure token (1-hour expiration)
3. Reset link sent via email
4. User clicks link and sets new password
5. Token marked as used

### 2. Rate Limiting

```python
@limiter.limit("5 per minute")  # Login attempts
@limiter.limit("3 per hour")    # Password reset requests
@limiter.limit("200 per day")   # General API calls
```

### 3. Session Security

**Configuration**:
```python
SESSION_COOKIE_SECURE = True      # HTTPS only
SESSION_COOKIE_HTTPONLY = True    # No JavaScript access
SESSION_COOKIE_SAMESITE = 'Lax'   # CSRF protection
PERMANENT_SESSION_LIFETIME = timedelta(hours=2)
```

**Auto-lock Features**:
- 2-minute inactivity: Lock screen
- 15-minute inactivity: Automatic logout

### 4. File Upload Security

**Validation**:
```python
def validate_file_upload(file, max_size_mb, allowed_extensions):
    # 1. Check file extension
    # 2. Verify file size
    # 3. Check MIME type (using python-magic)
    # 4. Prevent path traversal
    return is_valid, message
```

**Allowed File Types**:
- Documents: CSV, XLSX, PDF
- Images: PNG, JPG, JPEG

**Maximum Size**: 1024MB (configurable)

### 5. SQL Injection Prevention

**Uses SQLAlchemy ORM**:
```python
# Safe - parameterized query
Property.query.filter_by(account_no=user_input).first()

# Unsafe - avoided
db.session.execute(f"SELECT * FROM property WHERE account_no = '{user_input}'")

## OTP Verification System

### SMS Providers

#### 1. Mock (Development)
**Configuration**:
```python
SMS_PROVIDER=mock
```

**Behavior**:
- Logs OTP to console and file
- No actual SMS sent
- Perfect for testing

**Output**:
```
=====================================
📱 MOCK SMS - OTP CODE
=====================================
To: +233241234567
OTP Code: 123456
Amount: GHS 500.00
=====================================
```

#### 2. Twilio
**Configuration**:
```bash
SMS_PROVIDER=twilio
TWILIO_ACCOUNT_SID=your-sid
TWILIO_AUTH_TOKEN=your-token
TWILIO_PHONE_NUMBER=+1234567890
```

**Features**:
- Global coverage
- High reliability
- $15 free trial credit

#### 3. Africa's Talking
**Configuration**:
```bash
SMS_PROVIDER=africastalking
AFRICASTALKING_USERNAME=sandbox  # or your username
AFRICASTALKING_API_KEY=your-key
```

**Features**:
- Best for African countries (Ghana, Kenya, Nigeria, etc.)
- Competitive pricing
- Sandbox for testing

#### 4. Vonage (Nexmo)
**Configuration**:
```bash
SMS_PROVIDER=vonage
VONAGE_API_KEY=your-key
VONAGE_API_SECRET=your-secret
VONAGE_SENDER_ID=AWMA
```

**Features**:
- Global coverage
- €2 free trial credit

### OTP Workflow
**1. Generate OTP**
**2. Send OTP**
**3. Store OTP**
**4. Verify OTP**

### Phone Number Formatting

**Ghana Phone Number Formats**:
```python
# Input formats accepted:
0241234567      → +233241234567
233241234567    → +233241234567
+233241234567   → +233241234567

## Batch Operations

### 1. Bulk Upload

#### Property Bulk Upload
**Route**: `POST /property/bulk-upload`

**CSV Template**:
```csv
account_no,owner_name,primary_contact,electoral_area,town,block_no,parcel_no,division_no,category,property_class,zone,use_code,valuation_status,rateable_value,rate_impost
AYWMA141001,John Doe,0241234567,LEGON,Accra,9,21,11,Commercial,Class 1,FIRST CLASS A,Mixed,Valued,370254.00,0.001350
```

**Update Modes**:

**Skip Mode** (default):
```python
# Existing accounts are skipped
if existing_property:
    skipped_count += 1
    continue
```

**Update Mode**:
```python
# Existing accounts are updated
if existing_property:
    existing_property.owner_name = new_value
    # ... update all fields
    updated_count += 1
```

**Fail Mode** (strict):
```python
# Fails if any duplicate found
if existing_accounts:
    flash('Duplicates found', 'error')
    return redirect(...)
```

#### Business Bulk Upload
**Route**: `POST /business/bulk-upload`

**CSV Template**:
```csv
business_name,business_primary_contact,owner_name,owner_primary_contact,electoral_area,town,division_no,property_account_no,account_no,category1,category2,category3,category4,category5,category6
ABC Restaurant,0241234567,Jane Smith,0241234567,LEGON,Accra,11,AYWMA141001,BOP001,Food Service,Small Scale,Indoor,,,
```

**Special Handling**:
- Auto-generates business_id
- Matches categories to Product
- Creates invoice only if product found

#### Product Bulk Upload
**Route**: `POST /product/bulk-upload`

**CSV Template**:
```csv
product_name,category1,category2,category3,category4,category5,category6,amount,rate_impost
Restaurant License - Small,Food Service,Small Scale,Indoor,,,500.00,0.001350
```

**Duplicate Detection**:
```python
# Product is duplicate if ALL these match:
# - category1-6 (exact match including NULL)
# - amount
# - rate_impost
# product_name is NOT checked for duplicates
```

### 2. Batch Invoice Generation

**Route**: `POST /api/batch-invoice/generate`

**Request**:
```json
{
  "year": 2024,
  "billType": "all",  // property, business, or all
  "runType": "normal",  // normal or force
  "amountType": "fee_fixing",  // fee_fixing or fixed_amount
  "fixedAmount": 500.00,  // if fixed_amount
  "electoralArea": "LEGON",  // or "all"
  "town": "Accra"  // or "all"
}
```

**Run Types**:

**Normal Run**:
- Skips properties/businesses with existing invoices
- Safe for annual invoice generation

**Force Run**:
- Overwrites existing invoices
- Use with caution
- Logs all changes

### 3. Batch Printing

**Route**: `POST /batch-print`

**Purpose**: Print multiple invoices in one document

**Process Flow**:

#### Step 1: Input Account Numbers
```python
# Input format (comma or newline separated)
AYWMA141001, AYWMA141002
BOP001
AYWMA141003
```

#### Step 2: Preview Invoices
**Route**: `GET /batch-print/preview`

**Displays**:
- Found invoices with details
- Account numbers not found
- Year filter applied
- Total amount summary

#### Step 3: Execute Batch Print
**Route**: `GET /batch-print/execute`

**Generates**:
- Single print-friendly page
- All invoices with comprehensive data
- Credit balance analysis for each
- Arrears breakdown
- Payment history

**Financial Data Included**:
```python
for each invoice:
    - Invoice details
    - Current year amount
    - Total paid (current year)
    - Arrears from previous years
    - Credit applied
    - Outstanding balance
    - Grand total due
```

### 4. Data Export

#### Export Properties
**Route**: `GET /export/properties`

**Output**: CSV file with all property records

**Fields Included**:
```csv
account_no,owner_name,primary_contact,email,electoral_area,town,
rateable_value,rate_impost,created_at
```

#### Export Businesses
**Route**: `GET /export/businesses`

**Output**: CSV with all business records

#### Export Payments
**Route**: `GET /export/payments`

**Output**: CSV with all payment transactions

**Fields**:
```csv
invoice_no,invoice_type,payment_mode,payment_type,
payment_amount,paid_by,payment_date,gcr_number,status
```

#### Export Products
**Route**: `GET /export/products`

**Output**: CSV with all product rates

## Administrative Tools

### 1. User Management

#### View All Users
**Route**: `GET /admin/users`

**Displays**:
- Username, email, phone
- Role (admin/user)
- Created date
- Temporary password status
- Actions (edit, delete, toggle role)

#### Create User
**Route**: `POST /admin/users/create`

**Process**:
1. Admin enters user details
2. System generates secure temporary password
3. Password displayed once to admin
4. User record created with `is_temp_password=True`
5. Temporary password stored in database (hashed)

**Temporary Password Generation**:
#### Edit User
**Route**: `POST /admin/user/<user_id>/edit`

**Fields**:
- Username
- Email
- Phone number
- Role
- Force password reset (checkbox)

**Force Password Reset**:
```python
if reset_password:
    user.is_temp_password = True
    # User must reset password on next login
```

#### Delete User
**Route**: `POST /admin/user/<user_id>/delete`

**Safeguards**:
- Admin cannot delete themselves
- Confirmation required
- Audit log created

#### Toggle User Role
**Route**: `POST /admin/user/<user_id>/toggle-role`

**Toggles**: admin ↔ user

**Restrictions**:
- Cannot modify own role
- Audit log created

### 2. Temporary Password Management

#### View Temporary Passwords
**Route**: `GET /admin/temp-passwords`

**Displays**:
- User details
- Created date
- Expiration date
- Used status
- Creator

**Features**:
- Passwords expire after 7 days
- Shows unused passwords
- Pagination

#### Cleanup Expired Passwords
**Route**: `POST /admin/temp-passwords/cleanup`

**Action**: Deletes expired and used temporary passwords

### 3. Audit Log Viewer

**Route**: `GET /admin/audit-logs`

**Displays**:
- Timestamp
- User
- Action performed
- Entity type and ID
- Details
- IP address

**Searchable/Filterable**:
- By user
- By date range
- By action type
- By entity

**Pagination**: 20 entries per page

### 4. Invoice Adjustments

#### Pending Adjustments
**Route**: `GET /admin/adjustments/pending`

**Displays**: All adjustments awaiting approval

**For Each Adjustment**:
- Invoice number
- Adjustment type
- Amount change
- Reason
- Created by
- Percentage change
- Actions (Approve/Reject)

#### Approve Adjustment
**Route**: `POST /admin/adjustment/<id>/approve`

**Process**:
1. Validate adjustment status
2. Apply adjustment to invoice
3. Update invoice amount
4. Mark as approved
5. Record approver and timestamp
6. Create audit log

#### Reject Adjustment
**Route**: `POST /admin/adjustment/<id>/reject`

**Process**:
1. Mark adjustment as rejected
2. Record rejection notes
3. Invoice remains unchanged
4. Create audit log

### 6. OTP Management

#### View OTP Logs
**Route**: `GET /admin/otp-logs`

**Displays**:
- Phone number
- Invoice details
- OTP code (for debugging)
- Payment amount
- Verification status
- Attempts
- Expiration
- Created timestamp

**Pagination**: 50 entries per page

#### SMS Provider Status
**Route**: `GET /admin/sms-status`

**Shows**:
- Current provider
- Configuration status
- Credentials presence (boolean only)
- OTP expiry settings
- Email fallback status

**Example Display**:
```
Provider: africastalking
OTP Expiry: 5 minutes
Twilio Configured: ✓ (SID present, Token present)
Africa's Talking: ✓ (Username: sandbox, API Key present)
Vonage: ✗ (Not configured)
Email Fallback: ✓ (SMTP configured)

## User Workflows

### 1. First-Time User Login

**Scenario**: Admin creates new user account

**Flow**:
```
1. Admin creates user → System generates temp password
2. Admin shares temp password with user (securely)
3. User logs in with username + temp password
4. System redirects to /change-temp-password
5. User enters temp password + new password
6. System validates password strength
7. Password updated, temp flag removed
8. User redirected to dashboard
```

**Password Requirements**:
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 number
- At least 1 special character

### 2. Property Invoice Creation & Payment

**Flow**:
```
1. Property exists in system
2. User navigates to Property → Create Invoice
3. User selects:
   - Year
   - Generation type (new/update)
   - Amount type (fee fixing/fixed)
   - Invoice date / due date
   - Tax rate (optional)
   - Description
4. System calculates amount
5. Invoice created
6. User navigates to Invoice → Pay
7. User enters payment details:
   - Payment mode (Cash/MoMo/Cheque)
   - Payment type (Full/Part/Overpayment)
   - Payer information
   - GCR number (required)
8. System sends OTP to phone
9. User enters OTP code
10. System verifies OTP
11. Payment processed
12. Invoice status updated
13. Receipt available for printing
```

### 3. Business Invoice with Product Matching

**Flow**:
```
1. Business created with 6 categories
2. System searches Product table for exact match:
   - category1 = business.category1
   - category2 = business.category2
   - ... (all 6 must match, including NULL)
3. If match found:
   - Invoice auto-generated
   - Amount = product.amount
4. If no match:
   - Business created without invoice
   - Warning shown to user
   - Admin must add product or use fixed amount
```

### 4. Handling Overpayments & Credits

**Scenario**: Customer pays GHS 1,500 for GHS 1,000 invoice

**Flow**:
```
1. Invoice Amount: GHS 1,000
2. Payment Type: Overpayment
3. Payment Amount: GHS 1,500
4. System calculates:
   - Invoice fully paid: GHS 1,000
   - Credit created: GHS 500
5. Invoice marked as "Paid"
6. Credit automatically applied to:
   - Oldest unpaid invoice first
   - Then next oldest, etc.
7. If credit remains after all invoices:
   - Displayed as "Available Credit"
   - Applied to future invoices
```

**Credit Application Order**:
```python
# Example: Property with 3 invoices
2022: GHS 800 (unpaid)
2023: GHS 900 (unpaid)
2024: GHS 1,000 (overpaid by GHS 500)

# Credit (GHS 500) auto-applies:
2022: GHS 800 - GHS 500 = GHS 300 (still owed)
2023: GHS 900 (no credit left)
2024: GHS 0 (fully paid)

# Display shows:
Total Arrears: GHS 1,200 (GHS 300 + GHS 900)
Credit Applied: GHS 500
Outstanding Arrears: GHS 700
```

### 5. Invoice Adjustment Workflow

**Scenario**: Customer disputes invoice amount

**Flow**:
```
1. User navigates to Invoice → Create Adjustment
2. User enters:
   - Adjustment type (Credit/Penalty/Waiver)
   - Amount
   - Reason (dropdown)
   - Description (text)
   - Supporting document (optional)
3. System calculates:
   - New amount
   - Percentage change
4. If change > 10% OR amount > GHS 1,000:
   - Adjustment marked "Pending"
   - Requires admin approval
   Else:
   - Adjustment auto-approved
   - Invoice updated immediately
5. Admin reviews pending adjustments
6. Admin approves or rejects with notes
7. If approved:
   - Invoice amount updated
   - Status changed to "Approved"
8. Audit log created
```

### 6. Forgot Password Recovery

**Flow**:
```
1. User clicks "Forgot Password" on login page
2. User enters email or phone number
3. System:
   - Generates secure token (1-hour expiration)
   - Creates PasswordResetToken record
   - Sends email with reset link
4. User clicks link in email
5. System validates token:
   - Not expired
   - Not already used
6. User enters new password (twice)
7. System validates password strength
8. Password updated
9. Token marked as used
10. User redirected to login
11. User logs in with new password
```

**Dev Mode**: Reset link logged to console instead of email

---

## Utility Functions

### 1. Number to Words Conversion

**Function**: `convert_currency_to_words(amount)`

**Purpose**: Convert numeric amounts to words for invoices/receipts

**Example**:
```python
convert_currency_to_words(1523.75)
# Returns: "One Thousand Five Hundred Twenty-Three Ghana Cedis and Seventy-Five Pesewas only"

convert_currency_to_words(1000.00)
# Returns: "One Thousand Ghana Cedis only"

convert_currency_to_words(0.50)
# Returns: "Fifty Pesewas only"
```

**Usage in Templates**:
```jinja2
{{ invoice.total_amount|in_words }}
```

### 2. Phone Number Formatting

**Function**: `format_phone_number(phone)`

**Purpose**: Standardize Ghana phone numbers to international format

**Transformations**:
```python
format_phone_number("0241234567")
# Returns: (True, "+233241234567", None)

format_phone_number("233241234567")
# Returns: (True, "+233241234567", None)

format_phone_number("+233241234567")
# Returns: (True, "+233241234567", None)

format_phone_number("invalid")
# Returns: (False, None, "Invalid phone number format")
```

### 3. Invoice Number Generation

#### Property Invoices
**Function**: `generate_property_invoice_no(property_id, year)`

**Format**: `INVNBPR-{property_id:05d}-{year}`

**Examples**:
```python
generate_property_invoice_no(1, 2024)
# Returns: "INVNBPR-00001-2024"

generate_property_invoice_no(12345, 2024)
# Returns: "INVNBPR-12345-2024"
```

#### Business Invoices
**Function**: `generate_business_invoice_no(business_id, year)`

**Format**: `INVNBOP-{business_id}-{year}`

**Examples**:
```python
generate_business_invoice_no("00001", 2024)
# Returns: "INVNBOP-00001-2024"
```

### 4. Business ID Generation

**Function**: `generate_business_id()`

**Purpose**: Generate unique 5-digit business identifier

**Logic**:
```python
def generate_business_id():
    last_business = BusinessOccupant.query.order_by(
        BusinessOccupant.id.desc()
    ).first()
    
    if last_business:
        next_id = last_business.id + 1
    else:
        next_id = 1
    
    return f"{next_id:05d}"  # e.g., "00001", "00042", "12345"
```

### 5. Transaction Management

**Function**: `transaction_scope()`

**Purpose**: Ensure database consistency with automatic rollback

**Usage**:
```python
with transaction_scope():
    property = Property(...)
    db.session.add(property)
    
    invoice = PropertyInvoice(...)
    db.session.add(invoice)
    
    # If any error occurs, both operations rolled back
    # If successful, both operations committed
```

### 6. File Validation

**Function**: `validate_file_upload(file, max_size_mb, allowed_extensions)`

**Checks**:
1. File selected
2. Valid extension
3. File size within limit
4. File not empty
5. MIME type matches extension (security)

**Example**:
```python
is_valid, message = validate_file_upload(
    file=request.files['document'],
    max_size_mb=16,
    allowed_extensions={'pdf', 'jpg', 'png'}
)

if not is_valid:
    flash(message, 'error')
```

### 7. Audit Logging

**Function**: `log_action(action, entity_type, entity_id, details)`

**Purpose**: Create comprehensive audit trail

**Usage**:
```python
log_action(
    'Payment processed',
    'PropertyInvoice',
    invoice.id,
    f'Amount: GHS {amount:,.2f}, GCR: {gcr_number}'
)
```

**Features**:
- Automatic user detection
- IP address capture
- Timestamp recording
- Works outside request context (for CLI commands)

### 8. Product Matching

**Function**: `find_product_by_categories(cat1, cat2, cat3, cat4, cat5, cat6)`

**Purpose**: Find product rate matching all 6 business categories

**Logic**:
```python
def find_product_by_categories(cat1, cat2, cat3, cat4, cat5, cat6):
    query = Product.query
    
    # Each category must match exactly (including NULL)
    for i, cat_value in enumerate([cat1, cat2, cat3, cat4, cat5, cat6], 1):
        col = getattr(Product, f'category{i}')
        
        if cat_value is None:
            query = query.filter(col.is_(None))
        else:
            query = query.filter(col == cat_value)
    
    return query.first()
```

**Important**: All 6 categories must match. If category5 is NULL in business but "Indoor" in product, it's not a match.

### 9. Credit Balance Calculation

**Function**: `get_available_credit_balance(entity_type, entity_id, up_to_year)`

**Purpose**: Calculate total credit/overpayment balance

**Process**:
```python
# 1. Get all invoices up to year
# 2. Calculate total invoiced
# 3. Calculate total paid
# 4. Credit = total_paid - total_invoiced
# 5. Return credit if positive, else 0
```

**Usage**:
```python
credit = get_available_credit_balance('Property', property.id, 2024)
print(f"Available credit: GHS {credit:,.2f}")
```

### 10. Numeric Parsing

**Function**: `parse_numeric_value(value)`

**Purpose**: Safely parse numeric values from CSV (handles commas, currency symbols)

**Example**:
```python
parse_numeric_value("GHS 1,523.75")
# Returns: 1523.75

parse_numeric_value("N/A")
# Returns: 0.0

parse_numeric_value(None)
# Returns: 0.0
```

---

## Template Context Processors

### Available Functions in All Templates
**Usage Examples**:

```jinja2
<!-- Format currency -->
{{ invoice.amount|format_currency }}
<!-- Output: GHÂµ 1,523.75 -->

<!-- Get user details -->
{% set creator = get_user(property.created_by) %}
{{ creator.username }}

<!-- Check invoice balance -->
{% set balance = get_invoice_balance(invoice, 'Property') %}
{% if balance > 0 %}
  Outstanding: {{ balance|format_currency }}
{% endif %}

<!-- Year range for dropdowns -->
{% for year in get_year_range(2020, 2025) %}
  <option value="{{ year }}">{{ year }}</option>
{% endfor %}

<!-- Default dates -->
<input type="date" value="{{ today_date() }}">
<input type="date" value="{{ default_due_date(30) }}">

<!-- Pending adjustments count -->
{% if pending_count() > 0 %}
  <span class="badge">{{ pending_count() }}</span>
{% endif %}
```

---

## Error Handling

### Global Exception Handler

```python
@app.errorhandler(Exception)
def handle_exception(e):
    request_id = getattr(g, 'request_id', 'unknown')
    
    # Log error
    app.logger.error(
        f'Unhandled exception in request {request_id}: {str(e)}',
        exc_info=True
    )
    
    # Development: Show full error
    if app.debug:
        raise e
    
    # Production: User-friendly message
    flash('An unexpected error occurred. Please try again.', 'error')
    return redirect(url_for('index'))
```

### Specific Error Handlers

```python
@app.errorhandler(404)
def not_found_error(error):
    return render_template('errors/404.html'), 404

@app.errorhandler(500)
def internal_error(error):
    db.session.rollback()
    return render_template('errors/500.html'), 500

@app.errorhandler(413)
def request_entity_too_large(error):
    flash('File too large. Maximum size is 16MB.', 'error')
    return redirect(request.url), 413

@app.errorhandler(429)
def ratelimit_handler(e):
    flash('Too many requests. Please wait.', 'error')
    return render_template('errors/429.html'), 429
```

