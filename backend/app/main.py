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

# Seedream-v4 Edit modelinin doğru endpoint’i:
FAL_API_URL = "https://fal.run/fal-ai/bytedance/seedream/v4/edit"

app = FastAPI(title="AI Image Editor Backend")

# ------------------------------------------------------
# CORS ayarları
# ------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # frontend URL'ini buraya ekleyebilirsin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------
# Basit in-memory job storage
# ------------------------------------------------------
jobs = {}

@app.get("/")
def root():
    return {"message": "Backend is running"}


# ------------------------------------------------------
# Fal.ai API isteği oluşturma
# ------------------------------------------------------
@app.post("/api/jobs")
async def create_job(
    prompt: str = Form(...),
    model: str = Form("image-to-image"),
    image: UploadFile = None
):
    """
    Seedream-v4 edit modeline prompt (ve opsiyonel görsel) gönderir.
    model = "image-to-image" → Görsel yüklenmeli
    model = "text-to-image" → Görsel olmadan üretim
    """
    job_id = str(uuid.uuid4())
    jobs[job_id] = {
        "status": "processing",
        "prompt": prompt,
        "model": model,
        "result_url": None
    }

    headers = {
        "Authorization": f"Key {FAL_API_KEY}"
    }

    form = aiohttp.FormData()
    form.add_field("prompt", prompt)

    # Görsel varsa ekle
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
                FAL_API_URL,
                headers=headers,
                data=form,
                timeout=aiohttp.ClientTimeout(total=120)
            ) as response:

                # Fal API yanıtını kontrol et
                if response.status != 200:
                    error_text = await response.text()
                    jobs[job_id] = {
                        "status": "failed",
                        "error": f"fal.ai error: {error_text}"
                    }
                    return JSONResponse(status_code=response.status, content=jobs[job_id])

                data = await response.json()
                result_url = (
                    data.get("image") or
                    data.get("output", {}).get("image_url") or
                    data.get("images", [{}])[0].get("url")
                )

                jobs[job_id] = {
                    "status": "done",
                    "result_url": result_url,
                    "prompt": prompt,
                    "model": model
                }

    except Exception as e:
        jobs[job_id] = {
            "status": "failed",
            "error": str(e),
            "model": model
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
