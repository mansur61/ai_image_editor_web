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
    images: Optional[List[UploadFile]] = None,  # çoklu dosya
    image_urls: Optional[List[str]] = Form(None),  # çoklu URL
):
    job_id = str(uuid.uuid4())
    jobs[job_id] = {
        "status": "processing",
        "prompt": prompt,
        "model": model,
        "result_urls": [],
    }

    # ✅ Backend’e gönderilecek image_urls listesi
    final_image_urls = []

    # Dosyalar varsa base64 data URI oluştur
    if images:
        for img in images:
            img_bytes = await img.read()
            img_b64 = base64.b64encode(img_bytes).decode("utf-8")
            final_image_urls.append(f"data:{img.content_type};base64,{img_b64}")

    # URL’ler varsa ekle
    if image_urls:
        final_image_urls.extend([url for url in image_urls if url])

    if not final_image_urls:
        jobs[job_id]["status"] = "failed"
        jobs[job_id]["error"] = "No image or image_url provided."
        return {"job_id": job_id, **jobs[job_id]}

    payload = {
        "prompt": prompt,
        "model": model,
        "image_urls": final_image_urls,
    }

    headers = {
        "Authorization": f"Key {FAL_API_KEY}",
        "Content-Type": "application/json",
    }

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(
                FAL_API_URL,
                headers=headers,
                json=payload,
                timeout=aiohttp.ClientTimeout(total=180),
            ) as response:

                raw_text = await response.text()
                print("Raw backend response:", raw_text)

                if response.status != 200:
                    jobs[job_id]["status"] = "failed"
                    jobs[job_id]["error"] = f"Fal.ai error: {raw_text}"
                    return {"job_id": job_id, **jobs[job_id]}

                data = await response.json()

                # Birden fazla sonuç resmi varsa hepsini al
                result_urls = []
                if data.get("images"):
                    result_urls = [img.get("url") for img in data["images"] if img.get("url")]
                elif data.get("image"):
                    result_urls = [data["image"]]
                elif data.get("output", {}).get("image_url"):
                    result_urls = [data["output"]["image_url"]]

                jobs[job_id]["status"] = "done"
                jobs[job_id]["result_urls"] = result_urls
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
