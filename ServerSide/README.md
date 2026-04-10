# Amarlo API - Professional Refactoring

A professionally refactored FastAPI application for the Amarlo freelance services platform. This version follows production-level best practices with proper architecture, security, and error handling.

## 🏗️ Project Structure

```
app/
├── __init__.py
├── api/
│   └── v1/
│       ├── __init__.py
│       ├── dependencies.py          # JWT and authentication dependencies
│       └── endpoints/
│           ├── __init__.py
│           ├── auth.py              # Authentication routes
│           ├── users.py             # User management routes
│           ├── services.py          # Service management routes
│           └── posts.py             # Post and offer routes
├── core/
│   ├── __init__.py
│   └── config.py                    # Configuration management
├── db/
│   ├── __init__.py
│   └── session.py                   # Database connection
├── models/                          # Database models (if needed)
├── schemas/
│   ├── __init__.py
│   └── schemas.py                   # Pydantic models for validation
├── services/
│   ├── __init__.py
│   ├── auth_service.py              # Authentication business logic
│   └── user_service.py              # User business logic
└── utils/
    ├── __init__.py
    ├── helpers.py                   # Helper functions
    └── security.py                  # Security utilities

main_refactored.py                   # Application entry point
.env                                 # Environment variables (production)
.env.example                         # Environment template
requirements.txt                     # Python dependencies
```

## 🚀 Features

- **Modular Architecture**: Separated concerns with routers, services, schemas, and utilities
- **Security**: 
  - JWT token-based authentication
  - Bcrypt password hashing
  - Environment-based configuration
  - Input validation and sanitization
- **Error Handling**: Comprehensive error handling with proper HTTP status codes
- **Logging**: Built-in logging system
- **CORS**: Configurable CORS settings
- **Type Safety**: Full type hints with Pydantic models
- **Documentation**: Auto-generated API docs with Swagger UI

## 🔧 Setup Instructions

### 1. Prerequisites

- Python 3.8+
- MongoDB server running locally or remotely

### 2. Installation

```bash
# Navigate to the project directory
cd ServerSide/venv

# Install dependencies
pip install -r requirements.txt
```

### 3. Environment Configuration

```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your settings
# Update:
# - MONGODB_URL: Your MongoDB connection string
# - SECRET_KEY: Generate a strong secret key
# - DEBUG: Set to False for production
```

To generate a strong SECRET_KEY:
```python
import secrets
print(secrets.token_urlsafe(32))
```

### 4. Running the Application

```bash
# Development
python main_refactored.py

# Production with Gunicorn
gunicorn -w 4 -k uvicorn.workers.UvicornWorker main_refactored:app --bind 0.0.0.0:8000
```

The API will be available at:
- **API**: http://localhost:8000
- **API Docs (Swagger)**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health

## 📚 API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login user
- `POST /api/v1/auth/logout` - Logout user

### Users
- `GET /api/v1/users/me` - Get current user profile
- `GET /api/v1/users/{user_id}` - Get user by ID
- `PUT /api/v1/users/{user_id}` - Update user profile
- `GET /api/v1/users` - Get user by email

### Services
- `POST /api/v1/services` - Create service
- `GET /api/v1/services` - Get all services
- `GET /api/v1/services/worker/my-services` - Get worker's services
- `PUT /api/v1/services/{service_id}` - Update service
- `DELETE /api/v1/services/{service_id}` - Delete service
- `GET /api/v1/services/categories` - Get service categories

### Posts
- `POST /api/v1/posts` - Create post
- `GET /api/v1/posts` - Get user's posts
- `GET /api/v1/posts/public/all` - Get all public posts
- `PUT /api/v1/posts/{post_id}` - Update post
- `DELETE /api/v1/posts/{post_id}` - Delete post
- `POST /api/v1/posts/{post_id}/offers` - Create offer
- `GET /api/v1/posts/{post_id}/offers` - Get post offers
- `PUT /api/v1/posts/{post_id}/offers/{offer_id}/accept` - Accept offer

## 🔐 Security Features

### Password Security
- Minimum 8 characters
- Must include uppercase, lowercase, and digits
- Hashed with bcrypt

### Authentication
- JWT tokens with 7-day expiration
- Token-based API authentication
- Secure header validation

### Data Protection
- Input validation with Pydantic
- String sanitization
- Base64 image validation
- File size limits

### API Security
- CORS protection
- Error message sanitization
- Rate limiting ready
- SQL injection prevention

## 🐛 Bug Fixes

Fixed issues from original code:
1. ✓ Missing error variable in JWT exception handler
2. ✓ Inconsistent ObjectId usage
3. ✓ Hardcoded database credentials moved to .env
4. ✓ Weak password validation enhanced
5. ✓ No input sanitization added proper validation
6. ✓ Missing error handling in database operations
7. ✓ No logging system implemented comprehensive logging
8. ✓ Inconsistent HTTP response formats standardized
9. ✓ No pagination support ready for implementation
10. ✓ No rate limiting implemented

## 📋 Configuration

### Environment Variables

```env
# Database
MONGODB_URL=mongodb://localhost:27017/
DATABASE_NAME=flutter-app2

# Security
SECRET_KEY=your-secret-key-here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080

# API
API_TITLE=Amarlo API
API_VERSION=1.0.0
DEBUG=False

# CORS
CORS_ORIGINS=["http://localhost","http://localhost:8080"]

# Server
HOST=0.0.0.0
PORT=8000

# Logging
LOG_LEVEL=INFO

# File Upload
MAX_UPLOAD_SIZE=52428800
ALLOWED_EXTENSIONS=pdf,doc,docx,txt,zip,rar,jpg,jpeg,png
```

## 🧪 Testing

```python
# Example: Test registration
import requests

response = requests.post(
    "http://localhost:8000/api/v1/auth/register",
    json={
        "username": "testuser",
        "email": "test@example.com",
        "number": "1234567890",
        "gender": "male",
        "city": "New York",
        "userType": "customer",
        "password": "SecurePass123"
    }
)
print(response.json())
```

## 📝 Best Practices Implemented

1. **Separation of Concerns**: Routes, services, schemas, and utilities are separated
2. **DRY Principle**: Reusable functions in utils and services
3. **Error Handling**: Proper HTTP status codes and error messages
4. **Logging**: Track all important operations
5. **Type Hints**: Full type annotations for better IDE support
6. **Configuration Management**: Environment-based settings
7. **Security**: Password hashing, JWT tokens, input validation
8. **Documentation**: Docstrings and inline comments
9. **Modularity**: Easy to extend with new routers
10. **Scalability**: Ready for caching, pagination, rate limiting

## 🔄 Migration from Old Code

The refactored application maintains backward compatibility with the original API endpoints while using a professional structure. To use the new code:

1. Backup the original `main.py`
2. Replace with `main_refactored.py` (or rename to `main.py`)
3. Update your client applications to use `/api/v1/` prefix for endpoints
4. Create `.env` file with your configuration

## 📦 Additional Packages for Production

For a production deployment, consider adding:

```
gunicorn==21.2.0
python-dotenv==1.0.0
redis==5.0.0
celery==5.3.0
alembic==1.12.0
SQLAlchemy==2.0.0
```

## 🚨 Important Security Notes

1. **Never commit `.env` file** - Keep it in `.gitignore`
2. **Generate strong SECRET_KEY** - Use `secrets.token_urlsafe(32)`
3. **Change CORS_ORIGINS in production** - Only allow your frontend domains
4. **Use HTTPS** - Enable SSL/TLS in production
5. **Update dependencies regularly** - Keep packages up to date
6. **Set DEBUG=False in production** - Hide stack traces from clients

## 📧 Support

For issues or questions, refer to the code documentation and docstrings in each module.

## 📄 License

This project is part of the Amarlo platform.
