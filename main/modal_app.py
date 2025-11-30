"""
Quran Muaalem API - Modal Deployment

Deploy with:
    modal deploy modal_app.py

Run locally for testing:
    modal serve modal_app.py
"""

import modal

# Define the Modal app
app = modal.App("quran-muaalem-api")

# Model name constant
MODEL_NAME = "obadx/muaalem-model-v3_2"


def download_model():
    """Download and cache the model during image build."""
    from transformers import AutoFeatureExtractor
    from quran_muaalem.modeling.modeling_multi_level_ctc import Wav2Vec2BertForMultilevelCTC
    from quran_muaalem.modeling.multi_level_tokenizer import MultiLevelTokenizer

    print(f"Downloading model: {MODEL_NAME}")
    
    # Download all model components
    AutoFeatureExtractor.from_pretrained(MODEL_NAME)
    print("  ✓ Feature extractor downloaded")
    
    Wav2Vec2BertForMultilevelCTC.from_pretrained(MODEL_NAME)
    print("  ✓ Model weights downloaded")
    
    MultiLevelTokenizer(MODEL_NAME)
    print("  ✓ Tokenizer downloaded")
    
    print("All model components cached successfully!")


# Define the container image with all dependencies
# We pre-download the model during image build for faster cold starts
image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("ffmpeg", "libsndfile1", "git")
    .pip_install(
        "fastapi",
        "python-multipart",
        "librosa>=0.11.0",
        "numba>=0.61.2",
        "quran-muaalem",
        "quran-transcript",
        "torch>=2.0.0",
        "transformers>=4.30.0",
    )
    # Pre-download the model during image build (faster cold starts)
    .run_function(download_model)
)


@app.cls(
    image=image,
    gpu="T4",  # Use T4 GPU (cheapest option, sufficient for 660M param model)
    scaledown_window=300,  # Keep warm for 5 minutes after last request
)
@modal.concurrent(max_inputs=10)  # Handle multiple requests concurrently
class MuaalemAPI:
    """Modal class that holds the Muaalem model and serves the FastAPI app."""

    @modal.enter()
    def load_model(self):
        """Load the model when the container starts (runs once)."""
        import logging
        import torch
        from quran_muaalem import Muaalem

        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)

        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.logger.info(f"Loading Muaalem model on device: {self.device}")

        # Model is pre-downloaded during image build, so this just loads from cache
        self.muaalem = Muaalem(
            model_name_or_path=MODEL_NAME,
            device=self.device,
        )
        self.sampling_rate = 16000
        self.logger.info("Muaalem model loaded successfully!")

    @modal.asgi_app()
    def serve(self):
        """Serve the FastAPI application."""
        import io
        import logging
        from dataclasses import asdict

        import librosa
        from fastapi import FastAPI, File, Form, HTTPException, UploadFile
        from fastapi.middleware.cors import CORSMiddleware
        from quran_transcript import Aya, MoshafAttributes, quran_phonetizer

        logger = logging.getLogger(__name__)

        # Create FastAPI app
        web_app = FastAPI(
            title="Quran Muaalem API",
            description="API for analyzing Quranic recitation using the Muaalem model. "
            "Detects phonetic features, tajweed rules, and pronunciation accuracy.",
            version="0.1.0",
        )

        # Add CORS middleware for browser access
        web_app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

        # Helper functions
        def load_wave_from_upload(file: UploadFile, target_sr: int = 16000):
            """Load audio from uploaded file and resample."""
            raw = file.file.read()
            if not raw:
                raise HTTPException(status_code=400, detail="Empty audio file")
            try:
                with io.BytesIO(raw) as bio:
                    wave, sr = librosa.load(bio, sr=target_sr, mono=True)
                return wave, sr
            except Exception as e:
                logger.exception("Error loading audio file")
                raise HTTPException(
                    status_code=400, detail=f"Invalid audio file: {str(e)}"
                ) from e

        def build_moshaf(
            rewaya: str = "hafs",
            madd_monfasel_len: int = 2,
            madd_mottasel_len: int = 4,
            madd_mottasel_waqf: int = 4,
            madd_aared_len: int = 2,
        ) -> MoshafAttributes:
            """Build MoshafAttributes with specified parameters."""
            return MoshafAttributes(
                rewaya=rewaya,
                madd_monfasel_len=madd_monfasel_len,
                madd_mottasel_len=madd_mottasel_len,
                madd_mottasel_waqf=madd_mottasel_waqf,
                madd_aared_len=madd_aared_len,
            )

        def get_uthmani_from_aya(sura: int, aya: int) -> str:
            """Get Uthmani script text for a specific verse."""
            try:
                aya_obj = Aya(sura, aya)
                aya_info = aya_obj.get()
                uthmani_text = getattr(aya_info, "uthmani", None) or getattr(
                    aya_info, "uthmani_script", None
                )
                if not uthmani_text:
                    raise ValueError("Could not resolve Uthmani text")
                return uthmani_text
            except Exception as e:
                logger.exception(f"Error fetching aya {sura}:{aya}")
                raise HTTPException(
                    status_code=400, detail=f"Could not fetch verse {sura}:{aya}: {str(e)}"
                ) from e

        def serialize_phonemes(unit) -> dict:
            """Serialize phonemes Unit to dict."""
            probs = unit.probs
            ids = unit.ids
            if hasattr(probs, "tolist"):
                probs = probs.tolist()
            if hasattr(ids, "tolist"):
                ids = ids.tolist()
            return {
                "text": unit.text,
                "probs": [float(p) for p in probs],
                "ids": [int(i) for i in ids],
            }

        def serialize_sifat_list(sifat_list) -> list:
            """Serialize list of Sifa to list of dicts."""
            result = []
            for idx, sifa in enumerate(sifat_list):
                d = asdict(sifa)
                d["index"] = idx
                for key, val in list(d.items()):
                    if isinstance(val, dict) and "prob" in val:
                        try:
                            val["prob"] = float(val["prob"])
                            if "idx" in val:
                                val["idx"] = int(val["idx"])
                        except Exception:
                            pass
                result.append(d)
            return result

        def serialize_expected_sifat(sifat_list) -> list:
            """Serialize expected sifat from phonetizer output."""
            result = []
            for idx, sifa in enumerate(sifat_list):
                # sifa is a SifaOutput from quran_transcript
                d = {
                    "index": idx,
                    "phonemes": sifa.phonemes,
                    "hams_or_jahr": sifa.hams_or_jahr,
                    "shidda_or_rakhawa": sifa.shidda_or_rakhawa,
                    "tafkheem_or_taqeeq": sifa.tafkheem_or_taqeeq,
                    "itbaq": sifa.itbaq,
                    "safeer": sifa.safeer,
                    "qalqla": sifa.qalqla,
                    "tikraar": sifa.tikraar,
                    "tafashie": sifa.tafashie,
                    "istitala": sifa.istitala,
                    "ghonna": sifa.ghonna,
                }
                result.append(d)
            return result

        def compute_phoneme_diff(expected: str, actual: str) -> list:
            """Compute diff between expected and actual phonemes."""
            import diff_match_patch as dmp
            dmp_obj = dmp.diff_match_patch()
            diffs = dmp_obj.diff_main(expected, actual)
            
            result = []
            for op, data in diffs:
                if op == 0:  # Equal
                    result.append({"type": "equal", "text": data})
                elif op == 1:  # Insert (user added extra)
                    result.append({"type": "insert", "text": data})
                elif op == -1:  # Delete (user missed)
                    result.append({"type": "delete", "text": data})
            return result

        def compare_sifat(actual_sifat, expected_sifat) -> list:
            """Compare actual sifat vs expected sifat and return differences."""
            errors = []
            
            # Map actual sifat by phoneme group for comparison
            min_len = min(len(actual_sifat), len(expected_sifat))
            
            for i in range(min_len):
                actual = actual_sifat[i]
                expected = expected_sifat[i]
                
                sifa_errors = []
                
                # Compare each attribute
                attrs = [
                    ("hams_or_jahr", "الهمس/الجهر"),
                    ("shidda_or_rakhawa", "الشدة/الرخاوة"),
                    ("tafkheem_or_taqeeq", "التفخيم/الترقيق"),
                    ("ghonna", "الغنة"),
                    ("qalqla", "القلقلة"),
                    ("safeer", "الصفير"),
                    ("tikraar", "التكرار"),
                    ("tafashie", "التفشي"),
                    ("istitala", "الاستطالة"),
                    ("itbaq", "الإطباق"),
                ]
                
                for attr_en, attr_ar in attrs:
                    actual_val = actual.get(attr_en)
                    expected_val = expected.get(attr_en)
                    
                    if actual_val and expected_val:
                        actual_text = actual_val.get("text") if isinstance(actual_val, dict) else actual_val
                        
                        if actual_text != expected_val:
                            sifa_errors.append({
                                "attribute": attr_en,
                                "attribute_ar": attr_ar,
                                "expected": expected_val,
                                "actual": actual_text,
                                "prob": actual_val.get("prob", 1.0) if isinstance(actual_val, dict) else 1.0,
                            })
                
                if sifa_errors:
                    errors.append({
                        "index": i,
                        "phoneme": actual.get("phonemes_group", ""),
                        "expected_phoneme": expected.get("phonemes", ""),
                        "errors": sifa_errors,
                    })
            
            return errors

        def get_phonemes_by_word(uthmani_text: str, phonetizer_out, moshaf: MoshafAttributes) -> list:
            """
            Map the FULL VERSE phonetizer output to individual words using Phonetic Alignment.
            
            We run the phonetizer on each word individually, then align the resulting
            sequence of phonemes with the full verse's phoneme sequence.
            
            This handles:
            - Silent letters (present in word, absent in full verse)
            - Assimilation (different chars)
            - Connecting letters (wasla)
            """
            words = uthmani_text.split()
            if not words or not phonetizer_out.sifat:
                return []
            
            full_sifat = phonetizer_out.sifat
            full_idx = 0
            result = []
            
            # Helper to simplify phoneme for comparison
            def simplify(text):
                # Remove diacritics and normalize
                text = text.replace('ۦ', 'ي').replace('ۥ', 'و').replace('aa', 'a').replace('uu', 'u').replace('ii', 'i')
                # Remove shadda-like doubling for simpler comparison (e.g. bb -> b)
                if len(text) > 1 and len(set(text)) == 1:
                    text = text[0]
                return ''.join(c for c in text if c not in 'ًٌٍَُِّْ')
            
            # Pre-calculate phonemes for all words to enable lookahead
            word_phonemes_list = []
            for word in words:
                try:
                    w_out = quran_phonetizer(word, moshaf, remove_spaces=True)
                    word_phonemes_list.append(w_out.sifat if w_out and w_out.sifat else [])
                except:
                    word_phonemes_list.append([])

            for word_idx, word in enumerate(words):
                start_full_idx = full_idx
                word_sifat = word_phonemes_list[word_idx]
                
                w_idx = 0
                while w_idx < len(word_sifat) and full_idx < len(full_sifat):
                    f_p = full_sifat[full_idx].phonemes
                    w_p = word_sifat[w_idx].phonemes
                    
                    # 1. Exact or Simple Match
                    if f_p == w_p or simplify(f_p) == simplify(w_p):
                        full_idx += 1
                        w_idx += 1
                        continue

                    # 1.b Check for Many-to-One Match (Full verse splits, Word combines)
                    # e.g. Full=["رَ", "ببِ"], Word=["رَببِ"]
                    # Check if f_p + next_f_p matches w_p
                    if full_idx + 1 < len(full_sifat):
                        next_f_p = full_sifat[full_idx + 1].phonemes
                        combined_f_p = f_p + next_f_p
                        if combined_f_p == w_p or simplify(combined_f_p) == simplify(w_p):
                            full_idx += 2 # Consume 2 full phonemes
                            w_idx += 1    # Consume 1 word phoneme
                            continue
                    
                    # 1.c Relaxed containment match
                    # If one contains the other (and length diff is small), assume match
                    # Also handles shadda: f_p="bb", w_p="b" -> simplify("bb")=="b" which is handled above
                    # But also "du" vs "d"
                    if (f_p in w_p or w_p in f_p) and abs(len(f_p) - len(w_p)) <= 2:
                        full_idx += 1
                        w_idx += 1
                        continue
                        
                    # 2. Lookahead: Word has extra silent phoneme? (e.g. Wasla 'ءَ', Silent 'اا')
                    # Check if current full phoneme matches NEXT word phoneme
                    if w_idx + 1 < len(word_sifat):
                        next_w_p = word_sifat[w_idx + 1].phonemes
                        if f_p == next_w_p or simplify(f_p) == simplify(next_w_p):
                            w_idx += 1 # Skip current word phoneme (it's silent/extra)
                            continue
                            
                    # 3. Lookahead: Full verse has extra phoneme? (Rare)
                    if full_idx + 1 < len(full_sifat):
                        next_f_p = full_sifat[full_idx + 1].phonemes
                        if next_f_p == w_p or simplify(next_f_p) == simplify(w_p):
                            full_idx += 1 # Skip current full phoneme
                            continue
                            
                    # 4. Mismatch - likely assimilation or boundary change
                    # If we are at the end of the word, check if f_p belongs to THIS word or NEXT word
                    if w_idx >= len(word_sifat) - 1:
                        should_consume = False
                        
                        # Only consume if we are NOT at the last word (last word takes everything)
                        if word_idx < len(words) - 1:
                            # Peek at next word's first phoneme
                            next_word_sifat = word_phonemes_list[word_idx + 1]
                            if next_word_sifat:
                                next_w_start = next_word_sifat[0].phonemes
                                
                                # Is f_p closer to current word end (w_p) or next word start (next_w_start)?
                                # Use basic string similarity (or containment)
                                
                                # Case A: f_p contains w_p (e.g. f_p="du", w_p="d") -> Belongs to current
                                if w_p in f_p:
                                    should_consume = True
                                    
                                # Case B: f_p matches next_w_start -> Belongs to next
                                elif next_w_start in f_p or f_p in next_w_start:
                                    should_consume = False
                                    
                                # Case C: Neither matches clearly? 
                                # If it's effectively a vowel mismatch (e.g. f_p="du", w_p="d", next="l")
                                # it's safer to consume if it shares ANY chars with w_p
                                elif any(c in f_p for c in w_p) and not any(c in f_p for c in next_w_start):
                                    should_consume = True
                            else:
                                # Next word has no phonemes? Just consume.
                                should_consume = True
                        else:
                            # Last word consumes everything
                            should_consume = True
                            
                        if should_consume:
                             full_idx += 1
                             w_idx += 1
                        else:
                            break # Stop consuming for this word, leave f_p for next word

                    else:
                        # In the middle of word, assume 1-to-1 mapping (assimilation)
                        full_idx += 1
                        w_idx += 1
                
                # For the very last word, ensure we consume all remaining full sifat
                if word_idx == len(words) - 1:
                    full_idx = len(full_sifat)
                
                # If we didn't consume anything (e.g. skipped silent letters), force at least one if available
                # Unless it's a silent word (rare)
                if full_idx == start_full_idx and full_idx < len(full_sifat) and word_sifat:
                     # Heuristic: take 1
                     full_idx += 1
                
                word_end = full_idx - 1 if full_idx > start_full_idx else start_full_idx
                word_sifat_count = full_idx - start_full_idx
                
                # Construct phonemes text from the FULL verse segments we mapped
                mapped_phonemes = "".join(s.phonemes for s in full_sifat[start_full_idx:full_idx])
                
                result.append({
                    "word_index": word_idx,
                    "word": word,
                    "phonemes": mapped_phonemes,
                    "sifat_start": start_full_idx,
                    "sifat_end": word_end,
                    "sifat_count": word_sifat_count,
                })
                
            return result

        def build_response(out, phonetizer_out, moshaf, uthmani_text, sura=None, aya=None):
            """Build JSON response from Muaalem output."""
            actual_sifat = serialize_sifat_list(out.sifat)
            expected_sifat = serialize_expected_sifat(phonetizer_out.sifat)
            expected_phonemes = str(getattr(phonetizer_out, "phonemes", ""))
            actual_phonemes = out.phonemes.text
            
            # Get word-by-word phoneme breakdown with sifat ranges
            # IMPORTANT: Uses the full verse's phonetizer output to ensure correct mapping
            phonemes_by_word = get_phonemes_by_word(uthmani_text, phonetizer_out, moshaf)
            
            return {
                "phonemes_text": actual_phonemes,
                "phonemes": serialize_phonemes(out.phonemes),
                "sifat": actual_sifat,
                "reference": {
                    "sura": sura,
                    "aya": aya,
                    "uthmani_text": uthmani_text,
                    "moshaf": {
                        "rewaya": moshaf.rewaya,
                        "madd_monfasel_len": moshaf.madd_monfasel_len,
                        "madd_mottasel_len": moshaf.madd_mottasel_len,
                        "madd_mottasel_waqf": moshaf.madd_mottasel_waqf,
                        "madd_aared_len": moshaf.madd_aared_len,
                    },
                    "phonetic_script": {
                        "phonemes_text": expected_phonemes,
                    },
                },
                # Expected sifat from phonetizer
                "expected_sifat": expected_sifat,
                # Phoneme diff (insertions, deletions, matches)
                "phoneme_diff": compute_phoneme_diff(expected_phonemes, actual_phonemes),
                # Sifat comparison errors
                "sifat_errors": compare_sifat(actual_sifat, expected_sifat),
                # NEW: Word-by-word phonemes with sifat index ranges
                # This makes mapping errors to words trivial!
                "phonemes_by_word": phonemes_by_word,
            }

        # Routes
        @web_app.get("/")
        async def root():
            """Health check endpoint."""
            return {"status": "ok", "message": "Quran Muaalem API is running", "device": self.device}

        @web_app.get("/health")
        async def health():
            """Health check for monitoring."""
            return {"status": "healthy", "device": self.device}

        @web_app.post("/api/analyze-by-verse")
        async def analyze_by_verse(
            audio: UploadFile = File(..., description="Audio file (wav, mp3, etc.)"),
            sura: int = Form(..., ge=1, le=114, description="Sura number (1-114)"),
            aya: int = Form(..., ge=1, description="Aya number within the sura"),
            rewaya: str = Form("hafs", description="Recitation style"),
            madd_monfasel_len: int = Form(2, description="Length of separated elongation"),
            madd_mottasel_len: int = Form(4, description="Length of connected elongation"),
            madd_mottasel_waqf: int = Form(4, description="Length of connected elongation when stopping"),
            madd_aared_len: int = Form(2, description="Length of necessary elongation"),
        ):
            """Analyze a recitation by verse reference (sura and aya)."""
            logger.info(f"Analyzing recitation for sura {sura}, aya {aya}")

            # Load audio
            wave, _ = load_wave_from_upload(audio, self.sampling_rate)

            # Build moshaf
            moshaf = build_moshaf(
                rewaya=rewaya,
                madd_monfasel_len=madd_monfasel_len,
                madd_mottasel_len=madd_mottasel_len,
                madd_mottasel_waqf=madd_mottasel_waqf,
                madd_aared_len=madd_aared_len,
            )

            # Get Uthmani text
            uthmani_text = get_uthmani_from_aya(sura, aya)
            logger.info(f"Uthmani text: {uthmani_text[:50]}...")

            # Convert to phonetic script
            try:
                phonetizer_out = quran_phonetizer(uthmani_text, moshaf, remove_spaces=True)
            except Exception as e:
                logger.exception("Error running quran_phonetizer")
                raise HTTPException(status_code=500, detail=f"Phonetization failed: {str(e)}") from e

            # Run Muaalem model
            try:
                outs = self.muaalem(
                    [wave],
                    [phonetizer_out],
                    sampling_rate=self.sampling_rate,
                )
            except Exception as e:
                logger.exception("Error running Muaalem model")
                raise HTTPException(status_code=500, detail=f"Model inference failed: {str(e)}") from e

            if not outs:
                raise HTTPException(status_code=500, detail="Model returned no output")

            return build_response(outs[0], phonetizer_out, moshaf, uthmani_text, sura, aya)

        @web_app.post("/api/analyze-by-text")
        async def analyze_by_text(
            audio: UploadFile = File(..., description="Audio file (wav, mp3, etc.)"),
            uthmani_text: str = Form(..., description="Uthmani script text to analyze against"),
            rewaya: str = Form("hafs", description="Recitation style"),
            madd_monfasel_len: int = Form(2, description="Length of separated elongation"),
            madd_mottasel_len: int = Form(4, description="Length of connected elongation"),
            madd_mottasel_waqf: int = Form(4, description="Length of connected elongation when stopping"),
            madd_aared_len: int = Form(2, description="Length of necessary elongation"),
        ):
            """Analyze a recitation by providing Uthmani text directly."""
            logger.info(f"Analyzing recitation for text: {uthmani_text[:50]}...")

            if not uthmani_text.strip():
                raise HTTPException(status_code=400, detail="uthmani_text cannot be empty")

            # Load audio
            wave, _ = load_wave_from_upload(audio, self.sampling_rate)

            # Build moshaf
            moshaf = build_moshaf(
                rewaya=rewaya,
                madd_monfasel_len=madd_monfasel_len,
                madd_mottasel_len=madd_mottasel_len,
                madd_mottasel_waqf=madd_mottasel_waqf,
                madd_aared_len=madd_aared_len,
            )

            # Convert to phonetic script
            try:
                phonetizer_out = quran_phonetizer(uthmani_text, moshaf, remove_spaces=True)
            except Exception as e:
                logger.exception("Error running quran_phonetizer")
                raise HTTPException(status_code=500, detail=f"Phonetization failed: {str(e)}") from e

            # Run Muaalem model
            try:
                outs = self.muaalem(
                    [wave],
                    [phonetizer_out],
                    sampling_rate=self.sampling_rate,
                )
            except Exception as e:
                logger.exception("Error running Muaalem model")
                raise HTTPException(status_code=500, detail=f"Model inference failed: {str(e)}") from e

            if not outs:
                raise HTTPException(status_code=500, detail="Model returned no output")

            return build_response(outs[0], phonetizer_out, moshaf, uthmani_text)

        return web_app


# Local entrypoint for testing
@app.local_entrypoint()
def main():
    print("To serve the API locally, run: modal serve modal_app.py")
    print("To deploy to Modal, run: modal deploy modal_app.py")

