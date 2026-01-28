import os
import uuid
import secrets
from datetime import datetime, timezone
from urllib.parse import quote

from flask import Flask, request, jsonify, render_template
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


def read_kv_metadata(prefix_key: str, prefix_value: str) -> dict:
    """
    Czyta pary klucz->wartość z request.form:
      {prefix_key}[] oraz {prefix_value}[]
    """
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


def _parse_acquisition_date(date_str: str):
    try:
        acquisition_date = datetime.strptime(date_str, "%Y-%m-%d")
        return acquisition_date.replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def _required_nonempty(value: str | None) -> bool:
    return bool(value and value.strip())


@app.get("/")
def index():
    return render_template("upload.html")


@app.post("/upload")
def upload():
    """
    Obsługa:
    - single: request.files["file"] + pola jak dotychczas
    - batch: request.files.getlist("files[]") + pola indeksowane np. title_0, title_1, ...
    """
    mode = (request.form.get("mode") or "single").strip().lower()
    if mode not in ("single", "batch"):
        return jsonify({"error": "Nieznany tryb uploadu", "mode": mode}), 400

    if mode == "single":
        if "file" not in request.files:
            return jsonify({"error": "Brak pliku mapy"}), 400

        file = request.files["file"]
        if not file.filename:
            return jsonify({"error": "Pusty filename"}), 400

        required_fields = ["title", "description", "source", "region", "acquisitionDate", "uploadedBy"]
        missing = [f for f in required_fields if not _required_nonempty(request.form.get(f))]
        if missing:
            return jsonify({"error": "Brak wymaganych metadanych", "missing": missing}), 400

        acquisition_dt = _parse_acquisition_date(request.form["acquisitionDate"])
        if not acquisition_dt:
            return jsonify({"error": "Niepoprawny format daty (oczekiwany YYYY-MM-DD)"}), 400

        base_metadata = {
            "title": request.form["title"].strip(),
            "description": request.form["description"].strip(),
            "source": request.form["source"].strip(),
            "region": request.form["region"].strip(),
            "acquisitionDate": acquisition_dt,
        }

        uploaded_by = request.form["uploadedBy"].strip()
        extra_metadata = read_kv_metadata(prefix_key="meta_key", prefix_value="meta_value")

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
            "mode": "single",
            "results": [{
                "id": doc_id,
                "fileName": file_name,
                "storageUrl": storage_url,
                "isPublic": True,
                "uploadedBy": uploaded_by,
                "extraMetadata": extra_metadata,
                "saved": True,
            }]
        }), 201

    files = request.files.getlist("files[]")
    if not files:
        return jsonify({"error": "Brak plików (files[])"}), 400

    if not _required_nonempty(request.form.get("uploadedBy")):
        return jsonify({"error": "Brak uploadedBy"}), 400
    uploaded_by = request.form["uploadedBy"].strip()

    results = []
    errors = []

    for idx, file in enumerate(files):
        if not file or not file.filename:
            errors.append({"index": idx, "error": "Pusty plik lub filename"})
            continue

        required_fields = ["title", "description", "source", "region", "acquisitionDate"]
        missing = []
        per = {}
        for f in required_fields:
            key = f"{f}_{idx}"
            val = request.form.get(key)
            if not _required_nonempty(val):
                missing.append(key)
            else:
                per[f] = val.strip()

        if missing:
            errors.append({"index": idx, "error": "Brak wymaganych metadanych", "missing": missing})
            continue

        acquisition_dt = _parse_acquisition_date(per["acquisitionDate"])
        if not acquisition_dt:
            errors.append({"index": idx, "error": "Niepoprawny format daty (oczekiwany YYYY-MM-DD)", "field": f"acquisitionDate_{idx}"})
            continue

        base_metadata = {
            "title": per["title"],
            "description": per["description"],
            "source": per["source"],
            "region": per["region"],
            "acquisitionDate": acquisition_dt,
        }

        extra_metadata = read_kv_metadata(prefix_key=f"meta_key_{idx}", prefix_value=f"meta_value_{idx}")

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

        results.append({
            "index": idx,
            "id": doc_id,
            "fileName": file_name,
            "storageUrl": storage_url,
            "isPublic": True,
            "uploadedBy": uploaded_by,
            "extraMetadata": extra_metadata,
            "saved": True,
        })

    status = 201 if results and not errors else (207 if results and errors else 400)
    return jsonify({
        "mode": "batch",
        "savedCount": len(results),
        "errorCount": len(errors),
        "results": results,
        "errors": errors,
    }), status


@app.post("/maps/<doc_id>/view")
def increment_view(doc_id: str):
    db.collection("satellite_maps").document(doc_id).update({
        "generatedMetadata.viewCount": firestore.Increment(1),
        "generatedMetadata.lastViewed": firestore.SERVER_TIMESTAMP,
    })
    return jsonify({"ok": True, "id": doc_id})


if __name__ == "__main__":
    app.run(debug=True)
