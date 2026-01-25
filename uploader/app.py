import os
import uuid
import secrets
from datetime import datetime, timezone
from urllib.parse import quote

from flask import Flask, request, jsonify, render_template_string
import firebase_admin
from firebase_admin import credentials, firestore, storage

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_ACCOUNT_PATH = os.path.join(BASE_DIR, "serviceAccountKey.json")

cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)

firebase_admin.initialize_app(cred, {
    "storageBucket": "satellite-maps-b761c.firebasestorage.app"
})

db = firestore.client()
bucket = storage.bucket()

app = Flask(__name__)

def _ext(filename: str) -> str:
    _, ext = os.path.splitext(filename or "")
    return ext.lower() if ext else ""


def upload_to_storage_and_get_firebase_url(file_storage, dest_path: str, content_type: str | None = None) -> str:
    """
    Upload do Firebase Storage + zwraca Firebase-style download URL:
    https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<path_encoded>?alt=media&token=<token>
    """
    blob = bucket.blob(dest_path)
    blob.content_type = content_type or file_storage.mimetype

    token = secrets.token_urlsafe(24)
    blob.metadata = (blob.metadata or {})
    blob.metadata["firebaseStorageDownloadTokens"] = token

    blob.upload_from_file(file_storage.stream, rewind=True)

    bucket_name = bucket.name
    encoded_path = quote(dest_path, safe="")
    return f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{encoded_path}?alt=media&token={token}"


def read_kv_metadata(prefix_key: str = "meta_key", prefix_value: str = "meta_value") -> dict:
    keys = request.form.getlist(f"{prefix_key}[]")
    values = request.form.getlist(f"{prefix_value}[]")

    extra = {}
    for k, v in zip(keys, values):
        k = (k or "").strip()
        v = (v or "").strip()
        if not k:
            continue
        extra[k] = v
    return extra


METADATA_DESCRIPTIONS = {
    "title": "Tytuł mapy satelitarnej",
    "description": "Opis mapy",
    "source": "Źródło danych (np. Copernicus)",
    "acquisitionDate": "Data akwizycji danych",
    "region": "Region geograficzny",
}


def make_map_doc(
    file_name: str,
    storage_url: str,
    base_metadata: dict,
    uploaded_by: str | None,
    extra_metadata: dict,
) -> dict:
    doc = {
        "fileName": file_name,
        "storageUrl": storage_url,
        "isPublic": True,

        "uploadedAt": firestore.SERVER_TIMESTAMP,
        "uploadedBy": uploaded_by,

        "metadata": {
            "title": base_metadata["title"],
            "description": base_metadata["description"],
            "source": base_metadata["source"],
            "region": base_metadata["region"],
            "acquisitionDate": base_metadata["acquisitionDate"],
        },

        "metadataDescriptions": METADATA_DESCRIPTIONS,

        "generatedMetadata": {
            "viewCount": 0,
            "lastViewed": None,
        },
    }

    if extra_metadata:
        doc["extraMetadata"] = extra_metadata

    return doc

UPLOAD_FORM_HTML = r"""
<!doctype html>
<html lang="pl">
  <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <title>Upload satellite map</title>
    <style>
      :root{
        --bg:#f4f6fb;
        --card:#ffffff;
        --text:#1d2433;
        --muted:#6b7280;
        --line:#e5e7eb;
        --accent:#3b82f6;
        --accent2:#10b981;
        --danger:#ef4444;
      }
      *{ box-sizing:border-box; }
      body{
        margin:0;
        font-family: Arial, sans-serif;
        background: var(--bg);
        color: var(--text);
      }
      .wrap{
        max-width: 920px;
        margin: 24px auto;
        padding: 0 14px 30px;
      }
      .header{
        margin-bottom: 14px;
      }
      .title{
        margin:0;
        font-size: 24px;
      }
      .subtitle{
        margin: 6px 0 0;
        color: var(--muted);
        font-size: 14px;
        line-height: 1.4;
      }
      .card{
        background: var(--card);
        border: 1px solid var(--line);
        border-radius: 10px;
        padding: 16px;
      }
      .grid{
        display:grid;
        grid-template-columns: 1fr 1fr;
        gap: 12px;
      }
      @media (max-width: 800px){
        .grid{ grid-template-columns: 1fr; }
      }
      label{
        display:block;
        font-weight: 700;
        font-size: 13px;
        margin-bottom: 6px;
      }
      .help{
        color: var(--muted);
        font-size: 12px;
        margin-top: 6px;
      }
      input[type="text"], input[type="date"], input[type="file"]{
        width: 100%;
        padding: 10px 10px;
        border-radius: 8px;
        border: 1px solid var(--line);
        background: #fff;
        color: var(--text);
        outline: none;
      }
      input[type="text"]:focus, input[type="date"]:focus, input[type="file"]:focus{
        border-color: rgba(59,130,246,.7);
        box-shadow: 0 0 0 3px rgba(59,130,246,.15);
      }
      .sectionTitle{
        margin: 0 0 10px;
        font-size: 14px;
        font-weight: 800;
      }
      .divider{
        height:1px;
        background: var(--line);
        margin: 14px 0;
      }
      .metaRow{
        display:grid;
        grid-template-columns: 1fr 1.4fr auto;
        gap: 10px;
        align-items: center;
        margin-top: 10px;
      }
      @media (max-width: 800px){
        .metaRow{ grid-template-columns: 1fr; }
      }
      .btnRow{
        display:flex;
        gap:10px;
        flex-wrap: wrap;
        justify-content: flex-end;
        margin-top: 16px;
      }
      button{
        border: 1px solid var(--line);
        border-radius: 8px;
        padding: 10px 12px;
        font-weight: 700;
        cursor: pointer;
        background: #fff;
      }
      button:disabled{
        opacity: .65;
        cursor: not-allowed;
      }
      .btnPrimary{
        border-color: rgba(59,130,246,.4);
        background: rgba(59,130,246,.1);
        color: #1e3a8a;
      }
      .btnSecondary{
        background: #fff;
        color: var(--text);
      }
      .btnDanger{
        border-color: rgba(239,68,68,.35);
        background: rgba(239,68,68,.08);
        color: #7f1d1d;
      }
      .status{
        display:none;
        margin-top: 14px;
        padding: 12px 12px;
        border-radius: 8px;
        border: 1px solid var(--line);
        background: #fafafa;
      }
      .status.ok{
        border-color: rgba(16,185,129,.35);
        background: rgba(16,185,129,.10);
        color: #065f46;
      }
      .status.err{
        border-color: rgba(239,68,68,.35);
        background: rgba(239,68,68,.10);
        color: #7f1d1d;
      }
      .status pre{
        margin:10px 0 0;
        white-space: pre-wrap;
        word-break: break-word;
        color: inherit;
        font-size: 12px;
      }
      .spinner{
        width: 14px;
        height: 14px;
        border-radius: 50%;
        border: 2px solid rgba(0,0,0,.15);
        border-top-color: rgba(0,0,0,.45);
        display:inline-block;
        animation: spin .8s linear infinite;
        vertical-align: -2px;
      }
      @keyframes spin{
        to{ transform: rotate(360deg); }
      }
      .badge{
        display:inline-block;
        padding: 5px 8px;
        font-size: 12px;
        border-radius: 999px;
        border: 1px solid var(--line);
        color: var(--muted);
        background: #fff;
        margin-top: 6px;
      }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="header">
        <h1 class="title">Upload mapy satelitarnej</h1>
        <p class="subtitle">
          Formularz do dodawania map i metadanych do Firestore/Storage.
        </p>
      </div>

      <div class="card">
        <form id="uploadForm" enctype="multipart/form-data">
          <div class="sectionTitle">Dane podstawowe (wymagane)</div>
          <div class="grid">
            <div>
              <label>Plik mapy *</label>
              <input type="file" name="file" required />
            </div>

            <div>
              <label>uploadedBy *</label>
              <input type="text" name="uploadedBy" required placeholder="np. UID użytkownika" />
            </div>

            <div>
              <label>Tytuł *</label>
              <input type="text" name="title" required />
            </div>

            <div>
              <label>Źródło *</label>
              <input type="text" name="source" required />
            </div>

            <div>
              <label>Region *</label>
              <input type="text" name="region" required />
            </div>

            <div>
              <label>Data pozyskania *</label>
              <input type="date" name="acquisitionDate" required />
            </div>

            <div style="grid-column: 1 / -1;">
              <label>Opis *</label>
              <input type="text" name="description" required />
            </div>
          </div>

          <div class="divider"></div>

          <div class="sectionTitle">Dodatkowe metadane (opcjonalne)</div>
          <div class="help">Dodaj pary klucz → wartość. Puste klucze są ignorowane.</div>

          <div id="fields"></div>

          <div class="btnRow">
            <button class="btnSecondary" type="button" id="addBtn">Dodaj pole</button>
            <button class="btnDanger" type="button" id="clearBtn">Wyczyść formularz</button>
            <button class="btnPrimary" type="submit" id="submitBtn">
              <span id="submitIcon">Wyślij</span>
            </button>
          </div>

          <div id="status" class="status"></div>
        </form>
      </div>
    </div>

    <script>
      const form = document.getElementById("uploadForm");
      const fields = document.getElementById("fields");
      const addBtn = document.getElementById("addBtn");
      const clearBtn = document.getElementById("clearBtn");
      const submitBtn = document.getElementById("submitBtn");
      const submitIcon = document.getElementById("submitIcon");
      const statusBox = document.getElementById("status");

      function setStatus(type, title, details) {
        statusBox.className = "status " + (type === "ok" ? "ok" : "err");
        statusBox.style.display = "block";
        const safeDetails = details ? "<pre>" + escapeHtml(details) + "</pre>" : "";
        statusBox.innerHTML = "<strong>" + escapeHtml(title) + "</strong>" + safeDetails;
      }

      function clearStatus() {
        statusBox.style.display = "none";
        statusBox.innerHTML = "";
      }

      function escapeHtml(str) {
        return String(str)
          .replaceAll("&", "&amp;")
          .replaceAll("<", "&lt;")
          .replaceAll(">", "&gt;")
          .replaceAll('"', "&quot;")
          .replaceAll("'", "&#039;");
      }

      function addField(keyVal = "", valueVal = "") {
        const row = document.createElement("div");
        row.className = "metaRow";

        const key = document.createElement("input");
        key.type = "text";
        key.name = "meta_key[]";
        key.placeholder = "klucz";
        key.value = keyVal;

        const value = document.createElement("input");
        value.type = "text";
        value.name = "meta_value[]";
        value.placeholder = "wartość";
        value.value = valueVal;

        const remove = document.createElement("button");
        remove.type = "button";
        remove.className = "btnSecondary";
        remove.textContent = "Usuń";
        remove.onclick = () => row.remove();

        row.appendChild(key);
        row.appendChild(value);
        row.appendChild(remove);

        fields.appendChild(row);
      }

      function clearForm() {
        form.reset();
        fields.innerHTML = "";
        addField();
        clearStatus();
      }

      addBtn.addEventListener("click", () => addField());
      clearBtn.addEventListener("click", clearForm);

      addField();

      form.addEventListener("submit", async (e) => {
        e.preventDefault();
        clearStatus();

        const fileInput = form.querySelector('input[name="file"]');
        if (!fileInput || !fileInput.files || fileInput.files.length === 0) {
          setStatus("err", "Brak pliku", "Wybierz plik mapy.");
          return;
        }

        submitBtn.disabled = true;
        submitIcon.innerHTML = '<span class="spinner"></span> Wysyłanie...';

        try {
          const formData = new FormData(form);

          const resp = await fetch("/upload", {
            method: "POST",
            body: formData,
          });

          const text = await resp.text();
          let payload = null;
          try { payload = JSON.parse(text); } catch (_) {}

          if (!resp.ok) {
            const msg = payload?.error || "Wystąpił błąd wysyłania.";
            setStatus(
              "err",
              "Nie udało się wysłać",
              msg + (payload?.missing ? ("\nBrakuje: " + payload.missing.join(", ")) : "")
            );
            return;
          }

          const id = payload?.id ?? "(brak id)";
          const fileName = payload?.fileName ?? "(brak fileName)";
          const url = payload?.storageUrl ?? "(brak storageUrl)";

          setStatus("ok", "Wysłano ✅", "ID: " + id + "\nfileName: " + fileName + "\nstorageUrl: " + url);
        } catch (err) {
          setStatus("err", "Błąd połączenia", String(err));
        } finally {
          submitBtn.disabled = false;
          submitIcon.textContent = "Wyślij";
        }
      });
    </script>
  </body>
</html>
"""

@app.get("/")
def index():
    return render_template_string(UPLOAD_FORM_HTML)

@app.post("/upload")
def upload():
    if "file" not in request.files:
        return jsonify({"error": "Brak pliku mapy"}), 400

    file = request.files["file"]
    if not file.filename:
        return jsonify({"error": "Pusty filename"}), 400

    required_fields = ["title", "description", "source", "region", "acquisitionDate", "uploadedBy"]
    missing = [f for f in required_fields if not request.form.get(f)]
    if missing:
        return jsonify({"error": "Brak wymaganych metadanych", "missing": missing}), 400

    try:
        acquisition_date = datetime.strptime(request.form["acquisitionDate"], "%Y-%m-%d")
        acquisition_dt = acquisition_date.replace(tzinfo=timezone.utc)
    except ValueError:
        return jsonify({"error": "Niepoprawny format daty (oczekiwany YYYY-MM-DD)"}), 400

    base_metadata = {
        "title": request.form["title"].strip(),
        "description": request.form["description"].strip(),
        "source": request.form["source"].strip(),
        "region": request.form["region"].strip(),
        "acquisitionDate": acquisition_dt,
    }

    uploaded_by = request.form["uploadedBy"].strip()

    extra_metadata = read_kv_metadata()

    file_name = f"{uuid.uuid4()}{_ext(file.filename)}"
    storage_path = f"satellite_maps/{file_name}"
    storage_url = upload_to_storage_and_get_firebase_url(file, storage_path)

    doc_id = os.path.splitext(file_name)[0]

    doc = make_map_doc(
        file_name=file_name,
        storage_url=storage_url,
        base_metadata=base_metadata,
        uploaded_by=uploaded_by,
        extra_metadata=extra_metadata,
    )

    db.collection("satellite_maps").document(doc_id).set(doc)

    return jsonify({
        "id": doc_id,
        "fileName": file_name,
        "storageUrl": storage_url,
        "isPublic": True,
        "uploadedBy": uploaded_by,
        "extraMetadata": extra_metadata,
        "saved": True,
    }), 201

@app.post("/maps/<doc_id>/view")
def increment_view(doc_id: str):
    db.collection("satellite_maps").document(doc_id).update({
        "generatedMetadata.viewCount": firestore.Increment(1),
        "generatedMetadata.lastViewed": firestore.SERVER_TIMESTAMP,
    })
    return jsonify({"ok": True, "id": doc_id})


if __name__ == "__main__":
    app.run(debug=True)
