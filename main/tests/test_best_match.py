from quran_muaalem.decode import align_predicted_sequence
from time import perf_counter


if __name__ == "__main__":
    start = perf_counter()
    # ref = "abcd"
    # pred = "abcde"
    # out = "".join(align_predicted_sequence(ref, pred))
    # print(out)
    #
    # ref = "abcd"
    # pred = "abfcd"
    # out = "".join(align_predicted_sequence(ref, pred))
    # print(out)

    ref = "abcd"
    pred = "abcde"
    out = align_predicted_sequence(ref, pred)
    print(out)

    ref = "abcd"
    pred = "bcd"
    out = align_predicted_sequence(ref, pred)
    print(out)

    # ref = "abcd"
    # pred = "aaabc"
    # out = "".join(align_predicted_sequence(ref, pred))
    # print(out)
    #
    # ref = "abcd"
    # pred = "aaabc"
    # out = "".join(align_predicted_sequence(ref, pred))
    # print(out)

    print(f"Total time: {perf_counter() - start}")
