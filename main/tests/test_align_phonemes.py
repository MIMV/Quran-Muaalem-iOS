from quran_muaalem.decode import align_chunked_phonemes_sequence
from time import perf_counter


if __name__ == "__main__":
    start = perf_counter()

    pred = "abcd"
    ref = "abcde"
    out = align_chunked_phonemes_sequence(list(ref), list(pred))
    print(out)

    pred = "agcd"
    ref = "abcde"
    out = align_chunked_phonemes_sequence(list(ref), list(pred))
    print(out)

    print(f"Total time: {perf_counter() - start}")
