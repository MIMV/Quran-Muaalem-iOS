"""Dependencies and helper functions for the Quran Muaalem API."""

import io
import logging
from dataclasses import asdict

import librosa
import torch
from fastapi import HTTPException, UploadFile
from quran_transcript import Aya, MoshafAttributes, quran_phonetizer

from quran_muaalem import Muaalem
from quran_muaalem.muaalem_typing import Sifa, Unit

logger = logging.getLogger(__name__)

# Constants
SAMPLING_RATE = 16000
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# Global model instance (loaded once at startup)
muaalem: Muaalem | None = None


def load_model() -> Muaalem:
    """Load the Muaalem model (called once at startup)."""
    global muaalem
    logger.info(f"Loading Muaalem model on device: {DEVICE}")
    muaalem = Muaalem(
        model_name_or_path="obadx/muaalem-model-v3_2",
        device=DEVICE,
    )
    logger.info("Muaalem model loaded successfully")
    return muaalem


def get_muaalem() -> Muaalem:
    """Get the global Muaalem model instance."""
    if muaalem is None:
        raise RuntimeError("Muaalem model not loaded. Call load_model() first.")
    return muaalem


def load_wave_from_upload(file: UploadFile, target_sr: int = SAMPLING_RATE) -> tuple:
    """
    Load audio from an uploaded file and resample to target sample rate.

    Args:
        file: The uploaded audio file
        target_sr: Target sample rate (default 16000 Hz)

    Returns:
        Tuple of (wave_array, sample_rate)
    """
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
    """
    Build MoshafAttributes with the specified parameters.

    Args:
        rewaya: Recitation style (default "hafs")
        madd_monfasel_len: Length of separated elongation
        madd_mottasel_len: Length of connected elongation
        madd_mottasel_waqf: Length of connected elongation when stopping
        madd_aared_len: Length of necessary elongation

    Returns:
        MoshafAttributes instance
    """
    return MoshafAttributes(
        rewaya=rewaya,
        madd_monfasel_len=madd_monfasel_len,
        madd_mottasel_len=madd_mottasel_len,
        madd_mottasel_waqf=madd_mottasel_waqf,
        madd_aared_len=madd_aared_len,
    )


def get_uthmani_from_aya(sura: int, aya: int) -> str:
    """
    Get the Uthmani script text for a specific verse.

    Args:
        sura: Sura number (1-114)
        aya: Aya number within the sura

    Returns:
        The Uthmani script text for the verse
    """
    try:
        aya_obj = Aya(sura, aya)
        aya_info = aya_obj.get()

        # Try different attribute names based on quran-transcript API
        uthmani_text = getattr(aya_info, "uthmani", None) or getattr(
            aya_info, "uthmani_script", None
        )

        if not uthmani_text:
            raise ValueError("Could not resolve Uthmani text for this aya")

        return uthmani_text
    except Exception as e:
        logger.exception(f"Error fetching aya {sura}:{aya}")
        raise HTTPException(
            status_code=400, detail=f"Could not fetch verse {sura}:{aya}: {str(e)}"
        ) from e


def get_phonetizer_output(uthmani_text: str, moshaf: MoshafAttributes):
    """
    Convert Uthmani text to phonetic script.

    Args:
        uthmani_text: The Uthmani script text
        moshaf: MoshafAttributes instance

    Returns:
        QuranPhoneticScriptOutput from quran_phonetizer
    """
    try:
        return quran_phonetizer(uthmani_text, moshaf, remove_spaces=True)
    except Exception as e:
        logger.exception("Error running quran_phonetizer")
        raise HTTPException(
            status_code=500, detail=f"Phonetization failed: {str(e)}"
        ) from e


def serialize_phonemes(unit: Unit) -> dict:
    """
    Serialize a Unit (phonemes) to a JSON-compatible dict.

    Args:
        unit: The Unit dataclass containing phoneme predictions

    Returns:
        Dict with text, probs, and ids
    """
    probs = unit.probs
    ids = unit.ids

    # Convert tensors to lists if needed
    if hasattr(probs, "tolist"):
        probs = probs.tolist()
    if hasattr(ids, "tolist"):
        ids = ids.tolist()

    return {
        "text": unit.text,
        "probs": [float(p) for p in probs],
        "ids": [int(i) for i in ids],
    }


def serialize_sifat_list(sifat_list: list[Sifa]) -> list[dict]:
    """
    Serialize a list of Sifa dataclasses to JSON-compatible dicts.

    Args:
        sifat_list: List of Sifa dataclasses

    Returns:
        List of dicts with phonetic features
    """
    result = []
    for idx, sifa in enumerate(sifat_list):
        d = asdict(sifa)
        d["index"] = idx

        # Normalize any nested SingleUnit objects (convert prob/idx to proper types)
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


def build_response(
    out,
    phonetizer_out,
    moshaf: MoshafAttributes,
    uthmani_text: str,
    sura: int | None = None,
    aya: int | None = None,
) -> dict:
    """
    Build the JSON response from Muaalem output.

    Args:
        out: MuaalemOutput from the model
        phonetizer_out: QuranPhoneticScriptOutput from phonetizer
        moshaf: MoshafAttributes used
        uthmani_text: The Uthmani text analyzed
        sura: Optional sura number
        aya: Optional aya number

    Returns:
        Dict response matching AnalyzeResponse schema
    """
    return {
        "phonemes_text": out.phonemes.text,
        "phonemes": serialize_phonemes(out.phonemes),
        "sifat": serialize_sifat_list(out.sifat),
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
                "phonemes_text": str(getattr(phonetizer_out, "phonemes", "")),
            },
        },
    }

