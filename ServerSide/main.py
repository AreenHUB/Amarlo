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

import json
import logging
from datetime import datetime
from contextlib import asynccontextmanager
from typing import Dict

from bson import ObjectId
from fastapi import FastAPI, Header, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core import settings, logger
from app.db import MongoDB, get_database, CollectionNames
from app.api.v1.endpoints import auth, users, services, posts
from app.schemas import (
    MessageCreate,
    MessageOut,
    ReviewCreate,
    Report,
    ServiceRequest,
)
from app.utils import decode_token, extract_token_from_header


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


# WebSocket endpoint for general connections
@app.websocket("/ws")
async def websocket_general(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            await websocket.send_text(f"Echo: {data}")
    except WebSocketDisconnect:
        pass


# In-memory chat websocket connections
chat_connections: Dict[str, WebSocket] = {}


# WebSocket endpoint for notifications
@app.websocket("/ws/notifications/{user_email}")
async def websocket_notifications(
    websocket: WebSocket, user_email: str, token: str = None
):
    await websocket.accept()
    try:
        # Basic token validation
        if not token:
            await websocket.close(code=1008)  # Policy violation
            return
        try:
            payload = decode_token(token)
            if payload.get("sub") != user_email:
                await websocket.close(code=1008)
                return
        except:
            await websocket.close(code=1008)
            return

        # Keep connection open (placeholder for future notifications)
        while True:
            data = await websocket.receive_text()
            # Echo for now
            await websocket.send_text(f"Echo: {data}")
    except WebSocketDisconnect:
        pass


@app.websocket("/ws/chat/{user_email}")
async def websocket_chat(websocket: WebSocket, user_email: str, token: str = None):
    await websocket.accept()
    try:
        if not token:
            await websocket.close(code=1008)
            return
        try:
            payload = decode_token(token)
            if payload.get("sub") != user_email:
                await websocket.close(code=1008)
                return
        except Exception:
            await websocket.close(code=1008)
            return

        chat_connections[user_email] = websocket

        while True:
            raw_message = await websocket.receive_text()
            data = json.loads(raw_message)
            if data.get("type") == "chat_message":
                recipient_email = data.get("recipient_email")
                message_text = data.get("message")

                if not recipient_email or not message_text:
                    await websocket.send_text(
                        json.dumps(
                            {"error": "recipient_email and message are required"}
                        )
                    )
                    continue

                db = get_database()
                messages_collection = db[CollectionNames.MESSAGES]
                message_doc = {
                    "sender_email": user_email,
                    "recipient_email": recipient_email,
                    "message": message_text,
                    "timestamp": datetime.utcnow(),
                    "read": False,
                }
                inserted = messages_collection.insert_one(message_doc)
                message_doc["_id"] = str(inserted.inserted_id)
                message_doc["timestamp"] = message_doc["timestamp"].isoformat()

                # Send to recipient if online
                recipient_socket = chat_connections.get(recipient_email)
                if recipient_socket is not None:
                    await recipient_socket.send_text(
                        json.dumps(
                            {
                                "type": "chat_message",
                                "sender_email": user_email,
                                "recipient_email": recipient_email,
                                "message": message_text,
                                "timestamp": message_doc["timestamp"],
                                "_id": message_doc["_id"],
                                "read": False,
                            }
                        )
                    )

                # Ack sender
                await websocket.send_text(
                    json.dumps(
                        {
                            "type": "chat_ack",
                            "message_id": message_doc["_id"],
                            "status": "sent",
                        }
                    )
                )
            else:
                await websocket.send_text(
                    json.dumps({"error": "Unsupported message type"})
                )
    except WebSocketDisconnect:
        pass
    finally:
        chat_connections.pop(user_email, None)


@app.get("/conversations/{user_email}")
async def get_conversations(user_email: str):
    db = get_database()
    messages_collection = db[CollectionNames.MESSAGES]
    query = {
        "$or": [
            {"sender_email": user_email},
            {"recipient_email": user_email},
        ]
    }
    messages = list(messages_collection.find(query).sort("timestamp", 1))

    conversations = {}
    for msg in messages:
        other_email = (
            msg["recipient_email"]
            if msg["sender_email"] == user_email
            else msg["sender_email"]
        )
        conversation = conversations.get(
            other_email,
            {
                "other_email": other_email,
                "other_username": None,
                "message": None,
                "unread_count": 0,
                "_id": None,
                "timestamp": None,
            },
        )

        conversation["other_username"] = other_email
        conversation["message"] = msg["message"]
        conversation["_id"] = str(msg["_id"])
        conversation["timestamp"] = (
            msg["timestamp"].isoformat()
            if hasattr(msg["timestamp"], "isoformat")
            else msg["timestamp"]
        )

        if msg["recipient_email"] == user_email and not msg.get("read", False):
            conversation["unread_count"] += 1

        conversations[other_email] = conversation

    return list(conversations.values())


@app.get("/messages/{user_email}/{recipient_email}")
async def get_messages(user_email: str, recipient_email: str):
    db = get_database()
    messages_collection = db[CollectionNames.MESSAGES]
    query = {
        "$or": [
            {"sender_email": user_email, "recipient_email": recipient_email},
            {"sender_email": recipient_email, "recipient_email": user_email},
        ]
    }
    messages = list(messages_collection.find(query).sort("timestamp", 1))
    result = []
    for msg in messages:
        result.append(
            {
                "_id": str(msg.get("_id")),
                "sender_email": msg.get("sender_email"),
                "recipient_email": msg.get("recipient_email"),
                "message": msg.get("message"),
                "timestamp": (
                    msg.get("timestamp").isoformat()
                    if hasattr(msg.get("timestamp"), "isoformat")
                    else msg.get("timestamp")
                ),
                "read": msg.get("read", False),
            }
        )
    return result


@app.get("/user-requests/{user_email}")
async def get_user_requests(user_email: str):
    db = get_database()
    requests_collection = db[CollectionNames.REQUESTS]
    requests = list(requests_collection.find({"user_email": user_email}))
    result = []
    for request in requests:
        request["_id"] = str(request.get("_id"))
        request["created_at"] = (
            request.get("created_at").isoformat()
            if hasattr(request.get("created_at"), "isoformat")
            else request.get("created_at")
        )
        result.append(request)
    return result


@app.get("/api/v1/user-requests/{user_email}")
async def get_user_requests_v1(user_email: str):
    return await get_user_requests(user_email)


@app.put("/messages/{message_id}/read")
async def mark_message_as_read(message_id: str):
    db = get_database()
    messages_collection = db[CollectionNames.MESSAGES]
    try:
        message_obj = messages_collection.find_one({"_id": ObjectId(message_id)})
        if not message_obj:
            return JSONResponse(
                status_code=404, content={"detail": "Message not found"}
            )

        messages_collection.update_one(
            {"_id": ObjectId(message_id)},
            {"$set": {"read": True}},
        )
        return {"message_id": message_id, "read": True}
    except Exception:
        return JSONResponse(status_code=400, content={"detail": "Invalid message ID"})


@app.post("/toggle-block/{target_email}")
async def toggle_block(
    target_email: str, authorization: str = Header(None, alias="Authorization")
):
    if not authorization:
        return JSONResponse(
            status_code=401, content={"detail": "Authorization header required"}
        )

    token = extract_token_from_header(authorization)
    try:
        payload = decode_token(token)
    except Exception:
        return JSONResponse(status_code=401, content={"detail": "Invalid token"})

    user_email = payload.get("sub")
    if not user_email:
        return JSONResponse(status_code=401, content={"detail": "Invalid token"})

    db = get_database()
    blocked_collection = db[CollectionNames.BLOCKED_USERS]
    existing = blocked_collection.find_one(
        {"user_email": user_email, "blocked_email": target_email}
    )

    if existing:
        blocked_collection.delete_one(
            {"user_email": user_email, "blocked_email": target_email}
        )
        return {"blocked": False}

    blocked_collection.insert_one(
        {
            "user_email": user_email,
            "blocked_email": target_email,
            "created_at": datetime.utcnow(),
        }
    )
    return {"blocked": True}


@app.get("/block-status/{target_email}")
async def block_status(
    target_email: str, authorization: str = Header(None, alias="Authorization")
):
    if not authorization:
        return JSONResponse(
            status_code=401, content={"detail": "Authorization header required"}
        )

    token = extract_token_from_header(authorization)
    try:
        payload = decode_token(token)
    except Exception:
        return JSONResponse(status_code=401, content={"detail": "Invalid token"})

    user_email = payload.get("sub")
    db = get_database()
    blocked_collection = db[CollectionNames.BLOCKED_USERS]
    existing = blocked_collection.find_one(
        {"user_email": user_email, "blocked_email": target_email}
    )
    return {"blocked": existing is not None}


@app.get("/workers/{worker_email}/balance")
async def get_worker_balance(worker_email: str):
    db = get_database()
    payments_collection = db[CollectionNames.PAYMENTS]
    payments = list(payments_collection.find({"worker_email": worker_email}))
    balance = sum(payment.get("amount", 0) for payment in payments)
    return {"worker_email": worker_email, "balance": balance}


@app.get("/users/{worker_email}/reviews")
async def get_worker_reviews(worker_email: str):
    db = get_database()
    reviews_collection = db[CollectionNames.REVIEWS]
    reviews = list(reviews_collection.find({"worker_email": worker_email}))
    result = []
    for review in reviews:
        result.append(
            {
                "_id": str(review.get("_id")),
                "reviewer_email": review.get("reviewer_email"),
                "reviewer_username": review.get("reviewer_username"),
                "worker_email": review.get("worker_email"),
                "rating": review.get("rating"),
                "comment": review.get("comment"),
                "created_at": (
                    review.get("created_at").isoformat()
                    if hasattr(review.get("created_at"), "isoformat")
                    else review.get("created_at")
                ),
            }
        )
    return result


@app.post("/users/{worker_email}/reviews", status_code=201)
async def add_worker_review(
    worker_email: str,
    review: ReviewCreate,
    authorization: str = Header(None, alias="Authorization"),
):
    token = extract_token_from_header(authorization)
    payload = decode_token(token)
    reviewer_email = payload.get("sub")

    if not reviewer_email:
        return JSONResponse(status_code=401, content={"detail": "Invalid token"})

    user = get_database()[CollectionNames.USERS].find_one({"email": reviewer_email})
    reviewer_username = user.get("username") if user else reviewer_email

    review_doc = {
        "reviewer_email": reviewer_email,
        "reviewer_username": reviewer_username,
        "worker_email": worker_email,
        "rating": review.rating,
        "comment": review.comment,
        "created_at": datetime.utcnow(),
    }
    db = get_database()
    reviews_collection = db[CollectionNames.REVIEWS]
    inserted = reviews_collection.insert_one(review_doc)
    review_doc["_id"] = str(inserted.inserted_id)
    review_doc["created_at"] = review_doc["created_at"].isoformat()
    return review_doc


@app.delete("/requests/{request_id}")
async def delete_request(
    request_id: str,
    authorization: str = Header(None, alias="Authorization"),
):
    if not authorization:
        return JSONResponse(
            status_code=401, content={"detail": "Authorization header required"}
        )

    token = extract_token_from_header(authorization)
    try:
        payload = decode_token(token)
    except Exception:
        return JSONResponse(status_code=401, content={"detail": "Invalid token"})

    user_email = payload.get("sub")
    if not user_email:
        return JSONResponse(status_code=401, content={"detail": "Invalid token"})

    db = get_database()
    requests_collection = db[CollectionNames.REQUESTS]

    try:
        # Find the request to ensure it belongs to the user
        request_obj = requests_collection.find_one({"_id": ObjectId(request_id)})
        if not request_obj:
            return JSONResponse(
                status_code=404, content={"detail": "Request not found"}
            )

        # Check if the user owns this request (customer) or is the worker (can reject)
        if (
            request_obj.get("user_email") != user_email
            and request_obj.get("worker_email") != user_email
        ):
            return JSONResponse(
                status_code=403,
                content={"detail": "Not authorized to delete this request"},
            )

        # Delete the request
        result = requests_collection.delete_one({"_id": ObjectId(request_id)})
        if result.deleted_count == 1:
            return {"message": "Request deleted successfully"}
        else:
            return JSONResponse(
                status_code=500, content={"detail": "Failed to delete request"}
            )
    except Exception as e:
        app_logger.error(f"Error deleting request: {str(e)}")
        return JSONResponse(status_code=400, content={"detail": "Invalid request ID"})


@app.delete("/api/v1/requests/{request_id}")
async def delete_request_v1(
    request_id: str,
    authorization: str = Header(None, alias="Authorization"),
):
    return await delete_request(request_id, authorization)


async def _fetch_requests_by_worker(worker_email: str):
    db = get_database()
    requests_collection = db[CollectionNames.REQUESTS]
    requests = list(requests_collection.find({"worker_email": worker_email}))
    for request in requests:
        request["_id"] = str(request.get("_id"))
    return requests


@app.get("/worker-requests/{worker_email}")
async def get_worker_requests(worker_email: str):
    return await _fetch_requests_by_worker(worker_email)


@app.get("/api/v1/worker-requests/{worker_email}")
async def get_worker_requests_v1(worker_email: str):
    return await _fetch_requests_by_worker(worker_email)


@app.post("/api/v1/requests", status_code=201)
async def create_service_request(
    request: ServiceRequest,
    authorization: str = Header(None, alias="Authorization"),
):
    try:
        app_logger.info(f"Received POST /api/v1/requests request")

        if not authorization:
            app_logger.warning("No authorization header provided")
            return JSONResponse(
                status_code=401, content={"detail": "Authorization header required"}
            )

        token = extract_token_from_header(authorization)
        app_logger.info(f"Extracted token: {token[:20]}...")

        try:
            payload = decode_token(token)
            app_logger.info(f"Decoded payload: {payload}")
        except Exception as e:
            app_logger.error(f"Token decode error: {e}")
            return JSONResponse(status_code=401, content={"detail": "Invalid token"})

        requester_email = payload.get("sub")
        if not requester_email:
            app_logger.warning("No email in token payload")
            return JSONResponse(status_code=401, content={"detail": "Invalid token"})

        app_logger.info(f"Creating request for user: {requester_email}")
        request_data = request.dict()
        app_logger.info(f"Request data: {request_data}")

        request_data["created_at"] = (
            request_data["created_at"].isoformat()
            if hasattr(request_data["created_at"], "isoformat")
            else request_data["created_at"]
        )
        request_data["status"] = request_data.get("status", "pending")

        db = get_database()
        requests_collection = db[CollectionNames.REQUESTS]
        inserted = requests_collection.insert_one(request_data)
        request_data["_id"] = str(inserted.inserted_id)

        app_logger.info(f"Request created successfully with ID: {request_data['_id']}")
        return request_data
    except Exception as e:
        app_logger.error(f"Error creating service request: {str(e)}")
        return JSONResponse(
            status_code=500, content={"detail": f"Internal server error: {str(e)}"}
        )
    reports_collection = db[CollectionNames.REPORTS]
    reports = list(reports_collection.find())
    result = []
    for report in reports:
        result.append(
            {
                "_id": str(report.get("_id")),
                "user_email": report.get("user_email"),
                "description": report.get("description"),
                "imageBase64": report.get("imageBase64"),
                "status": report.get("status", "pending"),
                "timestamp": (
                    report.get("timestamp").isoformat()
                    if hasattr(report.get("timestamp"), "isoformat")
                    else report.get("timestamp")
                ),
            }
        )
    return result


@app.post("/reports", status_code=201)
async def submit_report(report: Report):
    report_doc = report.dict()
    report_doc["status"] = "pending"
    report_doc["timestamp"] = datetime.utcnow()
    db = get_database()
    reports_collection = db[CollectionNames.REPORTS]
    inserted = reports_collection.insert_one(report_doc)
    report_doc["_id"] = str(inserted.inserted_id)
    report_doc["timestamp"] = report_doc["timestamp"].isoformat()
    return report_doc


@app.get("/users/{user_email}/completed-requests")
async def get_completed_user_requests(user_email: str):
    db = get_database()
    requests_collection = db[CollectionNames.REQUESTS]
    requests = list(
        requests_collection.find({"user_email": user_email, "status": "completed"})
    )
    for request in requests:
        request["_id"] = str(request.get("_id"))
    return requests


@app.get("/workers/{worker_email}/completed-requests")
async def get_completed_worker_requests(worker_email: str):
    db = get_database()
    requests_collection = db[CollectionNames.REQUESTS]
    requests = list(
        requests_collection.find({"worker_email": worker_email, "status": "completed"})
    )
    for request in requests:
        request["_id"] = str(request.get("_id"))
    return requests


@app.get("/posts")
async def get_all_posts():
    """Get all posts (non-versioned endpoint for frontend compatibility)."""
    try:
        db = get_database()
        posts_collection = db[CollectionNames.POSTS]
        posts = list(posts_collection.find({}))
        return posts
    except Exception as e:
        app_logger.error(f"Error fetching all posts: {str(e)}")
        return JSONResponse(
            status_code=500, content={"detail": "Failed to fetch posts"}
        )


@app.get("/users/me/offers")
async def get_user_offers(authorization: str = Header(None, alias="Authorization")):
    """Get offers for current user's posts."""
    try:
        if not authorization:
            return JSONResponse(
                status_code=401, content={"detail": "Authorization header required"}
            )

        token = extract_token_from_header(authorization)
        try:
            payload = decode_token(token)
        except Exception:
            return JSONResponse(status_code=401, content={"detail": "Invalid token"})

        user_email = payload.get("sub")
        if not user_email:
            return JSONResponse(status_code=401, content={"detail": "Invalid token"})

        db = get_database()
        posts_collection = db[CollectionNames.POSTS]

        # Find all posts by this user and collect their offers
        user_posts = list(posts_collection.find({"user_email": user_email}))
        all_offers = []

        for post in user_posts:
            offers = post.get("offers", [])
            for offer in offers:
                # Add post info to each offer
                offer_with_post = offer.copy()
                offer_with_post["post_id"] = post["_id"]
                offer_with_post["post_title"] = post.get("title", "")
                all_offers.append(offer_with_post)

        return all_offers
    except Exception as e:
        app_logger.error(f"Error fetching user offers: {str(e)}")
        return JSONResponse(
            status_code=500, content={"detail": "Failed to fetch offers"}
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
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level=settings.LOG_LEVEL.lower(),
    )
