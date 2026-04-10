# Developer Quick Reference Guide

## File Structure at a Glance

```
app/
├── api/v1/endpoints/        ← Add new route files here
├── core/config.py           ← Change app settings
├── db/session.py            ← Database connection
├── schemas/schemas.py       ← Add new Pydantic models
├── services/                ← Add new business logic here
├── utils/                   ← Add helper functions here
└── models/                  ← (Optional) DB models if using ORM
```

---

## Common Tasks

### Adding a New API Endpoint

**Step 1**: Create router file in `app/api/v1/endpoints/`

```python
# app/api/v1/endpoints/new_feature.py
import logging
from fastapi import APIRouter, HTTPException, status, Depends

from app.schemas import NewFeatureSchema
from app.services.new_feature_service import NewFeatureService
from app.api.v1.dependencies import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/feature", tags=["Feature"])

@router.post("")
async def create_feature(
    data: NewFeatureSchema,
    current_user: dict = Depends(get_current_user)
):
    try:
        result = NewFeatureService.create(data, current_user)
        return result
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed")
```

**Step 2**: Create service file in `app/services/`

```python
# app/services/new_feature_service.py
from app.db import get_database, CollectionNames

class NewFeatureService:
    @staticmethod
    def create(data, user):
        db = get_database()
        collection = db[CollectionNames.USERS]  # or your collection
        # Business logic here
        return result
```

**Step 3**: Add schema in `app/schemas/schemas.py`

```python
from pydantic import BaseModel

class NewFeatureSchema(BaseModel):
    name: str
    description: str
```

**Step 4**: Include router in `main_refactored.py`

```python
from app.api.v1.endpoints import new_feature

app.include_router(new_feature.router)
```

---

### Adding Input Validation

```python
from pydantic import BaseModel, Field, validator

class UserInput(BaseModel):
    email: str = Field(..., regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
    age: int = Field(..., ge=18, le=120)
    name: str = Field(..., min_length=2, max_length=100)
    
    @validator('name')
    def name_alphanumeric(cls, v):
        if not v.replace(" ", "").isalnum():
            raise ValueError('Name must be alphanumeric')
        return v
```

---

### Accessing Current User

```python
@router.get("/profile")
async def get_profile(current_user: dict = Depends(get_current_user)):
    """current_user dict contains:
    - _id: user ID
    - email: user email
    - username: user username
    - userType: 'customer' or 'worker'
    - Any other fields in user document
    """
    email = current_user["email"]
    return {"user": email}
```

---

### Database Operations

```python
from app.db import get_database, CollectionNames

db = get_database()
users_collection = db[CollectionNames.USERS]

# Find one
user = users_collection.find_one({"email": email})

# Find many
users = list(users_collection.find({"userType": "worker"}))

# Insert
users_collection.insert_one({"email": email, "name": name})

# Update
users_collection.update_one(
    {"_id": user_id},
    {"$set": {"name": new_name}}
)

# Delete
users_collection.delete_one({"_id": user_id})
```

---

### Error Handling

```python
from fastapi import HTTPException, status

# Return 404
raise HTTPException(
    status_code=status.HTTP_404_NOT_FOUND,
    detail="Resource not found"
)

# Return 400
raise HTTPException(
    status_code=status.HTTP_400_BAD_REQUEST,
    detail="Invalid input"
)

# Return 403
raise HTTPException(
    status_code=status.HTTP_403_FORBIDDEN,
    detail="Not authorized"
)
```

---

### Logging

```python
import logging

logger = logging.getLogger(__name__)

# Different log levels
logger.debug("Debug message")
logger.info("Info message")
logger.warning("Warning message")
logger.error("Error message")
logger.critical("Critical message")
```

---

### Configuration

Access settings anywhere:

```python
from app.core import settings

# Use settings
database_url = settings.MONGODB_URL
secret_key = settings.SECRET_KEY
debug_mode = settings.DEBUG
```

---

### Helper Functions

```python
from app.utils import (
    generate_id,
    hash_password,
    verify_password,
    create_access_token,
    encode_file_to_base64,
    sanitize_string
)

# Generate ID
new_id = generate_id()

# Password operations
hashed = hash_password("mypassword")
is_valid = verify_password("mypassword", hashed)

# JWT token
token = create_access_token({"sub": "user@email.com"})

# File operations
base64_file = encode_file_to_base64(file_content)

# String sanitization
clean_string = sanitize_string(user_input, max_length=100)
```

---

### Security Best Practices

✅ **DO:**
- Use FastAPI Depends for authentication
- Validate all input with Pydantic
- Hash passwords with hash_password()
- Use environment variables for secrets
- Log errors but not sensitive data
- Sanitize error messages
- Use HTTPS in production

❌ **DON'T:**
- Hardcode secrets in code
- Skip input validation
- Store plaintext passwords
- Print user data in logs
- Expose stack traces to clients
- Use DEBUG=True in production
- Trust user input directly

---

### Response Format

Use Pydantic models for consistent responses:

```python
from app.schemas import UserOut

@router.get("/user/{user_id}", response_model=UserOut)
async def get_user(user_id: str):
    # Return will be validated against UserOut model
    return {
        "id": user_id,
        "username": "john",
        "email": "john@example.com",
        # ... other fields
    }
```

---

### Async Operations

All endpoints are async (FastAPI default):

```python
@router.get("/endpoint")
async def my_endpoint():
    # Use await for async operations
    result = await some_async_function()
    return result
```

---

### Testing Locally

```bash
# Health check
curl http://localhost:8000/health

# Register user
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "number": "1234567890",
    "gender": "male",
    "city": "NYC",
    "userType": "customer",
    "password": "SecurePass123"
  }'

# Login
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "SecurePass123"
  }'

# Use token
curl http://localhost:8000/api/v1/users/me \
  -H "Authorization: Bearer <token_here>"
```

---

### Debugging Tips

1. **Enable Debug Logging**
   ```python
   # In .env
   LOG_LEVEL=DEBUG
   ```

2. **Check Application Logs**
   ```bash
   tail -f logs/app.log
   ```

3. **Access Swagger UI**
   ```
   http://localhost:8000/docs
   ```

4. **Print Debug Info**
   ```python
   logger.debug(f"User data: {current_user}")
   ```

5. **Check Database**
   ```bash
   mongosh
   use flutter-app2
   db.users.findOne()
   ```

---

### Common Patterns

**Service Layer Pattern:**
```python
# In Service
class MyService:
    @staticmethod
    def do_something(data):
        # Business logic
        return result

# In Router
@router.post("")
async def endpoint(data):
    result = MyService.do_something(data)
    return result
```

**Dependency Injection Pattern:**
```python
@router.get("")
async def endpoint(
    current_user: dict = Depends(get_current_user),
    data: MySchema = None
):
    # current_user is automatically injected
    pass
```

**Error Handling Pattern:**
```python
try:
    result = do_something()
    return result
except ValueError as e:
    logger.warning(f"Validation error: {str(e)}")
    raise HTTPException(status_code=400, detail=str(e))
except Exception as e:
    logger.error(f"Unexpected error: {str(e)}")
    raise HTTPException(status_code=500, detail="Internal error")
```

---

### Performance Tips

1. Add indexes to frequently queried fields
2. Use pagination for large datasets
3. Cache frequently accessed data
4. Batch database operations
5. Use proper HTTP status codes
6. Set appropriate timeouts

---

### Common Errors & Solutions

| Error | Solution |
|-------|----------|
| Import not found | Check __init__.py files |
| DB connection fails | Verify MONGODB_URL in .env |
| 401 Unauthorized | Check Authorization header format |
| 403 Forbidden | Check user permissions/ownership |
| CORS error | Update CORS_ORIGINS in .env |

---

### File Naming Conventions

- Routers: `app/api/v1/endpoints/feature_name.py`
- Services: `app/services/feature_name_service.py`
- Schemas: Add to `app/schemas/schemas.py`
- Utils: Add to `app/utils/` as needed

---

This structure makes it easy to:
- ✅ Find code quickly
- ✅ Add new features
- ✅ Maintain code
- ✅ Scale application
- ✅ Collaborate with team

Happy coding! 🚀
