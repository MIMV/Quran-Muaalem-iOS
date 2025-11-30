import logging
from dataclasses import asdict
import json
from pathlib import Path
from time import perf_counter


from quran_transcript import Aya, quran_phonetizer, MoshafAttributes
import torch
from librosa.core import load

from quran_muaalem import Muaalem, MuaalemOutput, explain_for_terminal


def load_cache(cache_dir: str | Path, file_path: str | Path, reload=False):
    if reload:
        return
    file_path = Path(file_path)
    cache_path = Path(cache_dir) / f"{file_path.stem}.pt"
    if cache_path.is_file():
        print("Loading Cache")
        cache = torch.load(cache_path, weights_only=False)
        # outs = [MuaalemOutput(**item) for item in cache]
        # return outs
        return cache


def save_cache(cache_dir: str | Path, file_path: str | Path, outs: list[MuaalemOutput]):
    file_path = Path(file_path)
    cach_dir = Path(cache_dir)
    cach_dir.mkdir(exist_ok=True)
    cache_path = Path(cache_dir) / f"{file_path.stem}.pt"
    # outs_dict = [asdict(o) for o in outs]
    torch.save(outs, cache_path)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    cache_dir = "./assets/test_cache"
    sampling_rate = 16000
    audio_path = "./assets/test.wav"
    device = "cpu"
    reload = True

    uthmani_ref = Aya(8, 75).get_by_imlaey_words(17, 9).uthmani
    moshaf = MoshafAttributes(
        rewaya="hafs",
        madd_monfasel_len=2,
        madd_mottasel_len=4,
        madd_mottasel_waqf=4,
        madd_aared_len=2,
    )
    phonetizer_out = quran_phonetizer(uthmani_ref, moshaf, remove_spaces=True)

    cache = load_cache(cache_dir, audio_path, reload=reload)
    if not cache:
        muaalem = Muaalem(device=device)
        wave, _ = load(audio_path, sr=sampling_rate, mono=True)
        outs = muaalem(
            [wave],
            [phonetizer_out],
            sampling_rate=sampling_rate,
        )
        save_cache(cache_dir, audio_path, outs)
    else:
        outs = cache

    for out in outs:
        print(out.phonemes)
        for sifa in out.sifat:
            print(json.dumps(asdict(sifa), indent=2, ensure_ascii=False))
            print("*" * 30)
        print("-" * 40)

    # Explaining Results
    explain_for_terminal(
        outs[0].phonemes.text,
        phonetizer_out.phonemes,
        outs[0].sifat,
        phonetizer_out.sifat,
    )
