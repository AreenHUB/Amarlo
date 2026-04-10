# """
# Main application entry point.
# Initializes FastAPI application with all routers, middleware, and configurations.
# """

# import logging
# import os
# from contextlib import asynccontextmanager

# from fastapi import FastAPI
# from fastapi.middleware.cors import CORSMiddleware
# from fastapi.responses import JSONResponse

# from app.core import settings, logger
# from app.db import MongoDB
# from app.api.v1.endpoints import auth, users, services, posts

# # Configure logging
# logging.basicConfig(
#     level=settings.LOG_LEVEL,
#     format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
# )

# # Create logger
# app_logger = logging.getLogger(__name__)


# @asynccontextmanager
# async def lifespan(app: FastAPI):
#     """
#     Manage application lifecycle.
#     Handles startup and shutdown events.
#     """
#     # Startup
#     try:
#         await MongoDB.connect_db()
#         app_logger.info("✓ Application started successfully")
#     except Exception as e:
#         app_logger.error(f"✗ Failed to start application: {str(e)}")
#         raise

#     yield

#     # Shutdown
#     try:
#         await MongoDB.close_db()
#         app_logger.info("✓ Application shut down successfully")
#     except Exception as e:
#         app_logger.error(f"✗ Error during shutdown: {str(e)}")


# # Create FastAPI application
# app = FastAPI(
#     title=settings.API_TITLE,
#     version=settings.API_VERSION,
#     description="Professional Amarlo API",
#     lifespan=lifespan,
#     debug=settings.DEBUG,
# )

# # Add CORS middleware
# app.add_middleware(
#     CORSMiddleware,
#     allow_origins=settings.CORS_ORIGINS,
#     allow_credentials=True,
#     allow_methods=["*"],
#     allow_headers=["*"],
# )


# # Include routers
# app.include_router(auth.router)
# app.include_router(users.router)
# app.include_router(services.router)
# app.include_router(posts.router)


# # Health check endpoint
# @app.get("/health")
# async def health_check():
#     """Health check endpoint."""
#     return {
#         "status": "healthy",
#         "api_version": settings.API_VERSION,
#         "environment": "production" if not settings.DEBUG else "development",
#     }


# # Root endpoint
# @app.get("/")
# async def home():
#     """Root endpoint."""
#     return {
#         "message": "Welcome to Amarlo API",
#         "version": settings.API_VERSION,
#         "docs": "/docs",
#     }


# # Global exception handler
# @app.exception_handler(Exception)
# async def global_exception_handler(request, exc):
#     """Global exception handler."""
#     app_logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)
#     return JSONResponse(status_code=500, content={"detail": "Internal server error"})


# if __name__ == "__main__":
#     import uvicorn

#     uvicorn.run(
#         "main_refactored:app",
#         host=settings.HOST,
#         port=settings.PORT,
#         reload=settings.DEBUG,
#         log_level=settings.LOG_LEVEL.lower(),
#     )


"""
Main application entry point.
Initializes FastAPI application with all routers, middleware, and configurations.
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core import settings, logger
from app.db import MongoDB
from app.api.v1.endpoints import auth, users, services, posts


app_logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle."""
    try:
        await MongoDB.connect_db()
        app_logger.info("✓ Application started successfully")
    except Exception as e:
        app_logger.error(f"✗ Failed to start application: {str(e)}")
        raise

    yield

    try:
        await MongoDB.close_db()
        app_logger.info("✓ Application shut down successfully")
    except Exception as e:
        app_logger.error(f"✗ Error during shutdown: {str(e)}")


app = FastAPI(
    title=settings.API_TITLE,
    version=settings.API_VERSION,
    description="Professional Amarlo API",
    lifespan=lifespan,
    debug=settings.DEBUG,
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(auth.router)
app.include_router(users.router)
app.include_router(services.router)
app.include_router(posts.router)


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "api_version": settings.API_VERSION,
        "environment": "production" if not settings.DEBUG else "development",
    }


@app.get("/")
async def home():
    return {
        "message": "Welcome to Amarlo API",
        "version": settings.API_VERSION,
        "docs": "/docs",
    }


@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    app_logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main_refactored:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level=settings.LOG_LEVEL.lower(),
    )
