"""
Posts API router.
Handles post CRUD operations and offers.
"""

import logging
from datetime import datetime
from typing import List
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from app.schemas import PostCreate, PostUpdate, OfferCreate, OfferStatus
from app.db import get_database, CollectionNames
from app.utils import generate_id

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/posts", tags=["Posts"])


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_post(post: PostCreate, current_user: dict = None):
    """Create a new post."""
    try:
        db = get_database()
        posts_collection = db[CollectionNames.POSTS]

        post_doc = {
            "_id": generate_id(),
            **post.dict(),
            "user_email": current_user["email"],
            "created_at": datetime.utcnow(),
            "offers": [],
        }

        posts_collection.insert_one(post_doc)
        logger.info(f"Post created by {current_user['email']}")
        return post_doc

    except Exception as e:
        logger.error(f"Error creating post: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create post",
        )


@router.get("")
async def get_user_posts(current_user: dict = None):
    """Get posts created by current user."""
    try:
        db = get_database()
        posts_collection = db[CollectionNames.POSTS]

        posts = list(posts_collection.find({"user_email": current_user["email"]}))
        return posts

    except Exception as e:
        logger.error(f"Error fetching user posts: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch posts",
        )


@router.get("/public/all")
async def get_all_posts():
    """Get all public posts."""
    try:
        db = get_database()
        posts_collection = db[CollectionNames.POSTS]

        posts = list(posts_collection.find({}))
        return posts

    except Exception as e:
        logger.error(f"Error fetching all posts: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch posts",
        )


@router.put("/{post_id}")
async def update_post(post_id: str, post: PostUpdate, current_user: dict = None):
    """Update a post."""
    try:
        db = get_database()
        posts_collection = db[CollectionNames.POSTS]

        post_doc = posts_collection.find_one({"_id": post_id})

        if not post_doc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Post not found"
            )

        if post_doc["user_email"] != current_user["email"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized"
            )

        update_data = post.dict(exclude_unset=True)

        if update_data:
            posts_collection.update_one({"_id": post_id}, {"$set": update_data})

        updated_post = posts_collection.find_one({"_id": post_id})
        logger.info(f"Post updated: {post_id}")
        return updated_post

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating post: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update post",
        )


@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_post(post_id: str, current_user: dict = None):
    """Delete a post."""
    try:
        db = get_database()
        posts_collection = db[CollectionNames.POSTS]

        post_doc = posts_collection.find_one({"_id": post_id})

        if not post_doc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Post not found"
            )

        if post_doc["user_email"] != current_user["email"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized"
            )

        posts_collection.delete_one({"_id": post_id})
        logger.info(f"Post deleted: {post_id}")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting post: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete post",
        )


# ================== Offers Routes ==================


@router.post("/{post_id}/offers", status_code=status.HTTP_201_CREATED)
async def create_offer(post_id: str, offer: OfferCreate, current_user: dict = None):
    """Create an offer for a post."""
    try:
        db = get_database()
        posts_collection = db[CollectionNames.POSTS]

        post_doc = posts_collection.find_one({"_id": post_id})

        if not post_doc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Post not found"
            )

        offer_doc = {
            "_id": generate_id(),
            **offer.dict(),
            "worker_email": current_user["email"],
            "created_at": datetime.utcnow(),
        }

        posts_collection.update_one({"_id": post_id}, {"$push": {"offers": offer_doc}})

        logger.info(f"Offer created for post {post_id}")
        return offer_doc

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating offer: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create offer",
        )


@router.get("/{post_id}/offers")
async def get_post_offers(post_id: str, current_user: dict = None):
    """Get offers for a post."""
    try:
        db = get_database()
        posts_collection = db[CollectionNames.POSTS]

        post_doc = posts_collection.find_one({"_id": post_id})

        if not post_doc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Post not found"
            )

        if post_doc["user_email"] != current_user["email"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized"
            )

        return post_doc.get("offers", [])

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching offers: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch offers",
        )


@router.put("/{post_id}/offers/{offer_id}/accept")
async def accept_offer(post_id: str, offer_id: str, current_user: dict = None):
    """Accept an offer."""
    try:
        db = get_database()
        posts_collection = db[CollectionNames.POSTS]

        post_doc = posts_collection.find_one({"_id": post_id})

        if not post_doc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Post not found"
            )

        if post_doc["user_email"] != current_user["email"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized"
            )

        offers = post_doc.get("offers", [])
        for offer in offers:
            if offer["_id"] == offer_id:
                if offer.get("status") == "pending":
                    offer["status"] = "accepted"
                    posts_collection.update_one(
                        {"_id": post_id}, {"$set": {"offers": offers}}
                    )
                    logger.info(f"Offer {offer_id} accepted")
                    return {"message": "Offer accepted"}
                else:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Offer is not pending",
                    )

        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Offer not found"
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error accepting offer: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to accept offer",
        )
