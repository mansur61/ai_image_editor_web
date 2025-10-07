from fastapi import FastAPI, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import aiohttp
import os
import uuid
from dotenv import load_dotenv

load_dotenv()

# ------------------------------------------------------
# Fal.ai API ayarları
# ------------------------------------------------------
FAL_API_KEY = os.getenv("FAL_API_KEY")

# Seedream-v4 modelleri
IMAGE_TO_IMAGE_URL = "https://api.fal.ai/v1/models/seedream-v4/image-to-image"
TEXT_TO_IMAGE_URL = "https://api.fal.ai/v1/models/seedream-v4/text-to-image"

app = FastAPI(title="AI Image Editor Backend")

# ------------------------------------------------------
# CORS ayarları
# ------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # frontend URL eklenebilir
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------
# Basit in-memory job storage
# ------------------------------------------------------
jobs = {}

# ------------------------------------------------------
# Root endpoint
# ------------------------------------------------------
@app.get("/")
def root():
    return {"message": "Backend is running"}

# ------------------------------------------------------
# Job oluşturma (Image-to-Image)
# ------------------------------------------------------
@app.post("/api/jobs")
async def create_job(
    image: UploadFile = None, 
    prompt: str = Form(...),
    model: str = Form("image-to-image")  # opsiyonel: "text-to-image"
):
    """
    Seedream-v4 modeli ile görsel düzenleme veya text-to-image.
    `model` parametresi ile seçilebilir.
    """
    job_id = str(uuid.uuid4())
    jobs[job_id] = {"status": "processing", "result_url": None, "prompt": prompt, "model": model}

    # Hangi endpoint kullanılacak
    endpoint_url = IMAGE_TO_IMAGE_URL if model == "image-to-image" else TEXT_TO_IMAGE_URL

    headers = {
        "Authorization": f"Bearer {FAL_API_KEY}"
    }

    form = aiohttp.FormData()
    form.add_field("prompt", prompt)

    if model == "image-to-image":
        if not image:
            jobs[job_id] = {"status": "failed", "error": "Image file required for image-to-image."}
            return JSONResponse(status_code=400, content=jobs[job_id])
        form.add_field(
            "image",
            await image.read(),
            filename=image.filename,
            content_type=image.content_type
        )

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(
                endpoint_url,
                headers=headers,
                data=form,
                timeout=aiohttp.ClientTimeout(total=120)
            ) as response:

                if response.status != 200:
                    error_text = await response.text()
                    jobs[job_id] = {
                        "status": "failed",
                        "error": f"fal.ai error: {error_text}",
                    }
                    return JSONResponse(status_code=response.status, content=jobs[job_id])

                data = await response.json()
                # Modelden dönen görsel URL'sini al
                result_url = data.get("image") or data.get("output", {}).get("image_url")

                jobs[job_id] = {
                    "status": "done",
                    "result_url": result_url,
                    "prompt": prompt,
                    "model": model,
                }

    except Exception as e:
        jobs[job_id] = {
            "status": "failed",
            "error": str(e),
            "model": model,
        }

    return {"job_id": job_id}

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
