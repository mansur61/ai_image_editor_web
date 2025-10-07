from fastapi import FastAPI, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
import aiohttp
import os
import uuid
from dotenv import load_dotenv

load_dotenv()

FAL_API_KEY = os.getenv("FAL_API_KEY")
FAL_API_URL = "https://fal.run/fal-ai/bytedance/seedream/v4/edit"

app = FastAPI(title="AI Image Editor Backend")

# CORS ayarları
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Upload klasörü
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# In-memory job storage
jobs = {}

@app.get("/")
def root():
    return {"message": "Backend is running"}

@app.post("/api/jobs")
async def create_job(
    prompt: str = Form(...),
    model: str = Form("image-to-image"),
    image: UploadFile = None
):
    job_id = str(uuid.uuid4())
    jobs[job_id] = {"status": "processing", "prompt": prompt, "model": model, "result_url": None}

    headers = {
        "Authorization": f"Key {FAL_API_KEY}",
        "Content-Type": "application/json"
    }

    image_url = None
    if model == "image-to-image":
        if not image:
            jobs[job_id] = {"status": "failed", "error": "Image file required for image-to-image."}
            return JSONResponse(status_code=400, content=jobs[job_id])

        # Görseli kaydet
        file_id = str(uuid.uuid4())
        file_path = os.path.join(UPLOAD_DIR, f"{file_id}_{image.filename}")
        with open(file_path, "wb") as f:
            f.write(await image.read())

        image_url = f"http://localhost:8000/uploads/{file_id}_{image.filename}"

    # Fal.ai payload
    payload = {"prompt": prompt}
    if image_url:
        payload["image_urls"] = [image_url]

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(
                FAL_API_URL,
                headers=headers,
                json=payload,
                timeout=aiohttp.ClientTimeout(total=120)
            ) as response:

                if response.status != 200:
                    error_text = await response.text()
                    jobs[job_id] = {"status": "failed", "error": f"fal.ai error: {error_text}"}
                    return JSONResponse(status_code=response.status, content=jobs[job_id])

                data = await response.json()
                result_url = data.get("image") or data.get("output", {}).get("image_url") or data.get("images", [{}])[0].get("url")

                jobs[job_id] = {"status": "done", "result_url": result_url, "prompt": prompt, "model": model}

    except Exception as e:
        jobs[job_id] = {"status": "failed", "error": str(e), "model": model}

    return {"job_id": job_id}

@app.get("/api/jobs/{job_id}")
def get_job(job_id: str):
    job = jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"error": "Job not found"})
    return job

@app.get("/api/jobs")
def list_jobs():
    return jobs
