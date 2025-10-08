Flutter AI Görsel Düzenleme Web Uygulaması

Teslim Tarihi
8 Ekim 2025 Çarşamba (yerel saatle gün sonu)

Amaç
Bu proje, kullanıcıların yükledikleri görselleri yapay zekâ destekli olarak düzenleyebileceği bir web uygulaması geliştirmeyi hedefler.
Uygulama Flutter Web frontend ve FastAPI backend ile geliştirilmiş olup, Fal.ai API’si üzerinden görsel işleme gerçekleştirmektedir.

Kullanıcı akışı:
1. Görsel yükleme
2. Düzenleme isteğini metin (prompt) olarak girme
3. Fal.ai API üzerinden görselin işlenmesi
4. Düzenlenmiş görselin ekranda gösterimi

Frontend (Flutter Web)

Kullanılan Teknolojiler:
- Flutter Web
- HTTP paketleri (http veya dio) ile backend API çağrıları
- Responsive tasarım

Özellikler:
- Görsel Yükleme Alanı: Kullanıcıdan dosya alır
- Prompt (Metin Girişi) Kutusu: Düzenleme talimatlarını alır
- Düzenle / Oluştur Butonu: Backend’e isteği gönderir
- Sonuç Gösterimi: Düzenlenmiş görseli kullanıcıya sunar
- Görsel İndirme Butonu: Kullanıcı düzenlenmiş görseli indirebilir

Opsiyonel Bonus Özellikler:
- Önceki düzenleme geçmişi
- “Önce / Sonra” kaydırıcısı ile görsel karşılaştırması

Canlı Deploy:
- Frontend URL: **Vercel CLI ile deploy edilmiş**
- Backend ile HTTP REST API üzerinden iletişim

Backend (FastAPI)

Kullanılan Teknolojiler:
- Python 3.11+
- FastAPI
- aiohttp (async HTTP istekleri)
- python-dotenv (API anahtarı yönetimi)
- uvicorn (ASGI server)
- CORS Middleware

Mimari ve Endpointler:
Frontend <--> Backend (FastAPI) <--> Fal.ai API

Endpointler:
POST /api/jobs
→ Görsel ve prompt alır, fal.ai’ye gönderir ve yeni bir düzenleme işi oluşturur

GET /api/jobs/{job_id}
→ Belirli işin durumunu ve sonucunu döner

GET /api/jobs
→ Tüm işlerin listesi (sürüm geçmişi için)

Fal.ai Entegrasyonu:
- Model: seedream-v4 edit
- API Key gereklidir (.env dosyası ile sağlanır)
- Görsel işlemi: Upload edilen dosya base64 veri URI olarak Fal.ai’ye gönderilir

Deployment

Backend:
- Platform: Render.com (ücretsiz katman)
- CORS aktif
- Endpointler canlı ve erişilebilir

Frontend:
- Platform: Vercel
- Backend API ile entegrasyon

Kurulum (Lokal)

Backend:
1. Python 3.11+ kurulu olmalı
2. Proje klasörüne .env dosyası ekle:
   FAL_API_KEY=<fal.ai API Key>
3. Gereksinimleri yükle:
   pip install -r requirements.txt
4. Sunucuyu başlat:
   uvicorn main:app --reload
5. API test: http://localhost:8000

Frontend:
1. Flutter kurulu olmalı
2. Proje klasörüne gir:
   flutter pub get
   flutter run -d chrome
3. Tarayıcıda eriş: http://localhost:5000 (veya Flutter Web default port)

Mimari Genel Görünüm:
[Flutter Web UI] ---> [FastAPI Backend] ---> [Fal.ai API]
      |                    |                     |
      |--- Kullanıcı        |--- İş akışı       |--- Model işlem
      |    etkileşimi       |    yönetimi       |    (seedream-v4)

Bilinen Kısıtlar / Notlar:
- Render üzerindeki uploads klasörü geçici depolama için kullanılır; uzun süreli saklama yok,
fakat kullanılmadı her renderda veri kaybı olmaktadır. Base64 olarak verile fal.ai gönderildi.
- Base64 gönderim tercih edildi, fiziksel URL gerekmez
- Job history in-memory, veritabanı eklenmedi (opsiyonel) 
(supabase düşünüldü fakat mesaiden sonra müsait olamadım)

AI Araçları Kullanımı:
- ChatGPT kullanıldı 

Teslim Edilecekler:
- Frontend URL (Vercel) : https://fronted-56cbvp09e-mansur61s-projects.vercel.app/
- Backend URL (Render.com) : https://ai-image-editor-web.onrender.com
- GitHub Repo veya ZIP : https://github.com/mansur61/ai_image_editor_web/tree/master
 

