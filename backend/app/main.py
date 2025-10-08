import base64
from fastapi import FastAPI, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import aiohttp
import os
import uuid
from typing import List, Optional
from dotenv import load_dotenv

load_dotenv()

FAL_API_KEY = os.getenv("FAL_API_KEY")
FAL_API_URL = "https://fal.run/fal-ai/bytedance/seedream/v4/edit"

app = FastAPI(title="AI Image Editor Backend")

# ------------------------------------------------------
# CORS ayarları
# ------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # frontend domaini ekleyebilirsiniz
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------
# Basit in-memory job storage
# ------------------------------------------------------
jobs = {}

# ------------------------------------------------------
# Root
# ------------------------------------------------------
@app.get("/")
def root():
    return {"message": "Backend is running"}

# ------------------------------------------------------
# Job oluşturma endpoint (çoklu dosya / URL)
# ------------------------------------------------------
@app.post("/api/jobs")
async def create_job(
    prompt: str = Form(...),
    model: str = Form("image-to-image"),
    images: List[UploadFile] = None,  # ✅ Çoklu resim
    image_urls: str = Form(None)       # Opsiyonel URL string
):
    job_id = str(uuid.uuid4())
    jobs[job_id] = {"status": "processing", "prompt": prompt, "model": model, "result_urls": []}

    payload_images = []

    if images:
        for img in images:
            bytes_ = await img.read()
            b64 = base64.b64encode(bytes_).decode("utf-8")
            payload_images.append(f"data:{img.content_type};base64,{b64}")
    if image_urls:
        payload_images.append(image_urls)

    if not payload_images:
        jobs[job_id]["status"] = "failed"
        jobs[job_id]["error"] = "No images provided"
        return {"job_id": job_id, **jobs[job_id]}

    headers = {"Authorization": f"Key {FAL_API_KEY}", "Content-Type": "application/json"}
    payload = {"prompt": prompt, "model": model, "image_urls": payload_images}

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(FAL_API_URL, headers=headers, json=payload) as resp:
                data = await resp.json()
                result_images = data.get("images", [])
                urls = [img.get("url") for img in result_images if img.get("url")]
                jobs[job_id]["status"] = "done"
                jobs[job_id]["result_urls"] = urls
                return {"job_id": job_id, **jobs[job_id]}
    except Exception as e:
        jobs[job_id]["status"] = "failed"
        jobs[job_id]["error"] = str(e)
        return {"job_id": job_id, **jobs[job_id]}
# ------------------------------------------------------
# Job durumu sorgulama
# ------------------------------------------------------
@app.get("/api/jobs/{job_id}")
def get_job(job_id: str):
    job = jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"error": "Job not found"})
    return job

# ------------------------------------------------------
# Tüm jobları listeleme
# ------------------------------------------------------
@app.get("/api/jobs")
def list_jobs():
    return jobs
