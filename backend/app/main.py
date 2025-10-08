import base64
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
# Fal.ai dökümana göre API endpoint:
FAL_API_URL = "https://fal.ai/models/fal-ai/bytedance/seedream/v4/edit/api"

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
# Job oluşturma endpoint (memory üzerinden dosya gönderme)
# ------------------------------------------------------
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

    if model == "image-to-image":
        if not image:
            jobs[job_id]["status"] = "failed"
            jobs[job_id]["error"] = "Image file required for image-to-image."
            return {"job_id": job_id, **jobs[job_id]}

        # Görseli byte olarak oku
        image_bytes = await image.read()

        # Byte verisini base64 formatına dönüştür
        image_base64 = base64.b64encode(image_bytes).decode("utf-8")
        image_data_uri = f"data:{image.content_type};base64,{image_base64}"

        # JSON payload
        payload = {
            "prompt": prompt,
            "image_urls": [image_data_uri]
        }

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
                        jobs[job_id]["status"] = "failed"
                        jobs[job_id]["error"] = f"Fal.ai error: {error_text}"
                        return {"job_id": job_id, **jobs[job_id]}

                    data = await response.json()
                    result_url = data.get("image") or data.get("output", {}).get("image_url") or data.get("images", [{}])[0].get("url")
                    jobs[job_id]["status"] = "done"
                    jobs[job_id]["result_url"] = result_url

        except Exception as e:
            jobs[job_id]["status"] = "failed"
            jobs[job_id]["error"] = str(e)
            return {"job_id": job_id, **jobs[job_id]}

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
