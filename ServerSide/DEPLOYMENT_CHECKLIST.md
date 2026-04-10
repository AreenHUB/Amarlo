# Production Deployment Checklist

Use this checklist when deploying the refactored Amarlo API to production.

## Pre-Deployment

- [ ] **Review Code**: All code reviewed and tested
- [ ] **Update Dependencies**: Run `pip install -r requirements.txt` with production versions
- [ ] **Generate SECRET_KEY**: Use `secrets.token_urlsafe(32)` for strong key
- [ ] **Backup MongoDB**: Ensure database is backed up
- [ ] **Test Locally**: Run tests locally before deployment
- [ ] **Security Scan**: Run security scanning tools
- [ ] **Update Documentation**: Ensure docs are current

## Configuration

- [ ] **Create .env file**: Copy from .env.example and fill in production values
- [ ] **DATABASE URL**: Set MONGODB_URL to production MongoDB
- [ ] **SECRET_KEY**: Set unique, strong SECRET_KEY
- [ ] **DEBUG MODE**: Set DEBUG=False
- [ ] **CORS ORIGINS**: Set only your frontend domain(s)
- [ ] **LOG LEVEL**: Set LOG_LEVEL=INFO or WARNING
- [ ] **Host/Port**: Configure HOST and PORT correctly

## Security

- [ ] **HTTPS enabled**: All traffic uses HTTPS/TLS
- [ ] **Firewall rules**: MongoDB only accessible from app server
- [ ] **API Keys**: If needed, implement API key authentication
- [ ] **Rate Limiting**: Consider adding rate limiting
- [ ] **SQL Injection**: Verify input validation (already done with Pydantic)
- [ ] **CORS**: Check CORS configuration isn't too permissive
- [ ] **Headers**: Add security headers (X-Frame-Options, etc.)
- [ ] **Authentication**: Verify JWT token handling

## Database

- [ ] **MongoDB Connection**: Test connection string works
- [ ] **Indexes**: Consider adding indexes for frequently queried fields
- [ ] **Backups**: Set up automated backups
- [ ] **Monitoring**: Set up database monitoring
- [ ] **Collections Created**: Verify all collections exist

## Application

- [ ] **Dependencies installed**: `pip install -r requirements.txt`
- [ ] **Logging configured**: Logs directory exists and is writable
- [ ] **Health check works**: `curl http://localhost:8000/health`
- [ ] **API docs accessible**: Swagger UI at `/docs`
- [ ] **Error handling**: Test error responses
- [ ] **Graceful shutdown**: app handles SIGTERM signals

## Deployment Method

### Option 1: Uvicorn + Gunicorn
```bash
# Install production server
pip install gunicorn uvicorn

# Run with 4 workers
gunicorn -w 4 -k uvicorn.workers.UvicornWorker main_refactored:app \
  --bind 0.0.0.0:8000 \
  --access-logfile - \
  --error-logfile - \
  --log-level info
```

### Option 2: Docker
```bash
# Dockerfile would contain:
FROM python:3.11
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app/ app/
COPY main_refactored.py .
CMD ["gunicorn", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "main_refactored:app"]
```

### Option 3: Systemd Service (Linux)
```ini
[Unit]
Description=Amarlo API Service
After=mongodb.service

[Service]
Type=notify
User=amarlo
WorkingDirectory=/opt/amarlo/api
ExecStart=/opt/amarlo/api/venv/bin/gunicorn -w 4 -k uvicorn.workers.UvicornWorker main_refactored:app --bind 0.0.0.0:8000
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## Post-Deployment

- [ ] **Health Check**: Verify health endpoint responds
- [ ] **Registration Test**: Test user registration endpoint
- [ ] **Login Test**: Test login and token generation
- [ ] **API Documentation**: Verify Swagger UI is accessible
- [ ] **Logs**: Check logs for any errors
- [ ] **Performance**: Monitor initial performance metrics
- [ ] **Monitoring**: Set up monitoring/alerting

## Monitoring

Set up monitoring for:
- [ ] **Application Uptime**: HTTP status codes
- [ ] **Response Times**: API latency
- [ ] **Error Rates**: 4xx and 5xx responses
- [ ] **Database**: Connection pool, response times
- [ ] **Server Resources**: CPU, Memory, Disk
- [ ] **Logs**: Error and warning levels

### Sample Monitoring Commands
```bash
# Check API health
curl -v http://localhost:8000/health

# Monitor logs
tail -f logs/app.log

# Check process
ps aux | grep gunicorn

# Monitor system
top
df -h
```

## Rollback Plan

If issues occur:
```bash
# 1. Stop current version
sudo systemctl stop amarlo-api
# or: kill <process_id>

# 2. Restore previous version
cd /app
git checkout main_refactored.py

# 3. Restart
sudo systemctl start amarlo-api

# 4. Verify
curl http://localhost:8000/health
```

## Performance Optimization (Future)

- [ ] **Add Redis caching**: Cache frequently accessed data
- [ ] **Enable compression**: Gzip responses
- [ ] **Add pagination**: Limit result sets
- [ ] **Index MongoDB**: Add indexes for common queries
- [ ] **Connection pooling**: Optimize DB connections
- [ ] **CDN**: Serve static content via CDN
- [ ] **Load balancer**: Distribute traffic across multiple instances

## Maintenance Tasks

Daily:
- [ ] Monitor logs for errors
- [ ] Check API health
- [ ] Verify database backups

Weekly:
- [ ] Update security patches
- [ ] Review error logs
- [ ] Performance analysis

Monthly:
- [ ] Security audit
- [ ] Dependency updates
- [ ] Database cleanup
- [ ] Capacity planning

## Support & Documentation

- README.md - Installation and usage
- MIGRATION_GUIDE.md - Migration from old version
- Code docstrings - API documentation
- /docs - Swagger UI (automated)
- /redoc - ReDoc documentation (automated)

## Emergency Contacts

- Database Team: [contact]
- DevOps Team: [contact]
- Security Team: [contact]

## Sign-Off

- [ ] **Developer**: Reviewed and approved
- [ ] **QA**: Tested and approved
- [ ] **DevOps**: Infrastructure ready
- [ ] **Security**: Security review passed
- [ ] **Manager**: Business approval

Date: ________________
Deployed By: ________________
