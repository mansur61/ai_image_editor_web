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
    headers = {
        "Authorization": f"Key {FAL_API_KEY}",
        "Content-Type": "application/json"
    }

    if model == "image-to-image" and image:
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
                        return JSONResponse(status_code=400, content={"error": f"Fal.ai error: {error_text}"})

                    data = await response.json()
                    result_url = data.get("image") or data.get("output", {}).get("image_url") or data.get("images", [{}])[0].get("url")

                    return {"job_id": job_id, "status": "done", "result_url": result_url}

        except Exception as e:
            return JSONResponse(status_code=500, content={"error": str(e)})

    else:
        return JSONResponse(status_code=400, content={"error": "Image file required for image-to-image."})
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
