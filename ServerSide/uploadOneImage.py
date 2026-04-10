import pymongo
import base64

# Connect to MongoDB
client = pymongo.MongoClient("mongodb://localhost:27017/")
db = client["test"]
collection = db["testimage"]

# Read the image file
with open("D:\\Flutter Projects\\P1\\thered_test\\test.jpg", "rb") as image_file:
    # Convert binary data to Base64 string
    base64_image = base64.b64encode(image_file.read()).decode("utf-8")

# Create a document with the Base64 string
image_document = {
    "name": "test.jpg",
    "data": base64_image
}

# Insert the document into the collection
collection.insert_one(image_document)

print("Image stored in MongoDB.")
