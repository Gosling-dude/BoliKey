#!/usr/bin/env python3
"""Builds the on-device language model from authored and CC-licensed sources.

Inputs
  Data/hinglish/lexicon.psv   hand-authored Hinglish vocabulary and spelling variants
  Data/hinglish/verbs.psv     verb table, expanded into conjugated forms here
  Data/hinglish/corpus.txt    hand-written conversational Hinglish messages
  Data/hinglish/nosuggest.txt recognised but never proposed words
  Data/english/corpus.txt     hand-written conversational English messages
  Data/raw/*                  see Tools/fetch_sources.sh and NOTICE.md

Outputs, in Packages/BoliKeyKit/Sources/LanguageCore/Resources
  words.tsv    word, flags, hindi count, english count, canonical, devanagari, gloss
  ngrams.tsv   model (h/e/d), order, context, next word, count
  chargrams.tsv  character trigram log likelihood per language, for out of vocabulary words

Standard library only, so anyone can rebuild it with the system python3.
"""
import collections
import math
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "Packages/BoliKeyKit/Sources/LanguageCore/Resources")
RAW = os.path.join(ROOT, "Data/raw")

# Pruning limits. These decide the size of the shipped model.
EN_VOCAB = 32000
EN_SENTENCE_LIMIT = 400000
EN_BIGRAM_MIN, EN_TRIGRAM_MIN = 8, 8
EN_BIGRAMS_PER_WORD, EN_TRIGRAMS_PER_CTX = 8, 4
HI_DEVA_VOCAB = 9000
WORD_RE = re.compile(r"[a-z]+(?:'[a-z]+)?")
END = "</s>"
DEVA_RE = re.compile(r"[ऀ-ॿ]+")


def read_lines(path):
    with open(path, encoding="utf8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line and not line.startswith("#"):
                yield line


class Entry:
    __slots__ = ("word", "canonical", "deva", "gloss", "weight", "is_canonical")

    def __init__(self, word, canonical, deva, gloss, weight, is_canonical):
        self.word, self.canonical, self.deva, self.gloss = word, canonical, deva, gloss
        self.weight, self.is_canonical = weight, is_canonical


def load_lexicon():
    entries = {}

    def add(word, canonical, deva, gloss, weight):
        word = word.strip().lower()
        if not word or " " in word:
            return
        is_canon = word == canonical
        cur = entries.get(word)
        # A word that is itself a canonical form is never demoted to a variant.
        if cur is None or (is_canon and not cur.is_canonical) or (is_canon == cur.is_canonical and weight > cur.weight):
            entries[word] = Entry(word, canonical, deva, gloss, weight, is_canon)

    rows = [l.split("|") for l in read_lines(os.path.join(ROOT, "Data/hinglish/lexicon.psv"))]
    for r in rows:
        if len(r) == 5:
            add(r[0], r[0], r[2], r[3], int(r[4]))
    for r in rows:
        if len(r) == 5:
            for v in r[1].split(","):
                add(v, r[0], r[2], r[3], max(1, int(r[4]) - 1))

    # (roman suffix, devanagari suffix, spelling variants of the suffix)
    consonant = [("na", "ना", []), ("ne", "ने", []), ("ni", "नी", []), ("ta", "ता", []), ("ti", "ती", []), ("te", "ते", []),
                 ("o", "ो", []), ("e", "े", []), ("unga", "ूँगा", ["uga"]), ("ungi", "ूँगी", ["ugi"]),
                 ("enge", "ेंगे", ["ege"]), ("oge", "ोगे", []), ("ogi", "ोगी", []), ("ega", "ेगा", []), ("egi", "ेगी", []),
                 ("iye", "िए", ["ie"]), ("u", "ूँ", ["un"]), ("ein", "ें", ["en"])]
    vowel_a = [("na", "ना", []), ("ne", "ने", []), ("ni", "नी", []), ("ta", "ता", []), ("ti", "ती", []), ("te", "ते", []),
               ("o", "ओ", []), ("ye", "ए", ["e"]), ("unga", "ऊँगा", ["uga"]), ("ungi", "ऊँगी", ["ugi"]),
               ("yenge", "एँगे", ["enge", "yege"]), ("oge", "ओगे", []), ("yega", "एगा", ["ega"]), ("yegi", "एगी", ["egi"]),
               ("iye", "इए", []), ("u", "ऊँ", ["un"])]
    other = [("na", "ना", []), ("ne", "ने", []), ("ni", "नी", []), ("ta", "ता", []), ("ti", "ती", []), ("te", "ते", []),
             ("yega", "एगा", ["ega"]), ("yegi", "एगी", ["egi"]), ("yenge", "एँगे", ["enge"]), ("oge", "ओगे", []),
             ("unga", "ऊँगा", ["uga"]), ("ungi", "ऊँगी", ["ugi"])]
    for r in (l.split("|") for l in read_lines(os.path.join(ROOT, "Data/hinglish/verbs.psv"))):
        stem, short, deva, gloss, cls, past, past_deva, weight = r
        weight = int(weight)
        if cls == "X" or " " in stem:
            continue
        table = {"C": consonant, "A": vowel_a}.get(cls, other)
        # The bare stem is itself an imperative: "kar", "bol", "dekh".
        add(stem, stem, deva, gloss, weight)
        if short != stem and len(short) > 1:
            add(short, stem, deva, gloss, max(1, weight - 1))
        for suf, deva_suf, alts in table:
            form = stem + suf
            canonical = form
            form_deva = deva + deva_suf
            add(form, canonical, form_deva, gloss, max(1, weight - 1))
            for alt in alts:
                add(stem + alt, canonical, form_deva, gloss, max(1, weight - 2))
            if short != stem and len(short) > 1:
                add(short + suf, canonical, form_deva, gloss, max(1, weight - 2))
                for alt in alts:
                    add(short + alt, canonical, form_deva, gloss, max(1, weight - 2))
        # Past tense, plus the conjunctive -kar and -ke forms.
        for suf, dsuf in (("a", "ा"), ("i", "ी"), ("e", "े")):
            if cls == "C":
                add(past + suf, past + suf, past_deva + dsuf, gloss, max(1, weight - 1))
        if cls == "C":
            add(stem + "ke", stem + "ke", deva + "के", gloss, 1)
    return entries


def tokenize(line):
    return WORD_RE.findall(line.lower().replace("’", "'"))


def ngram_counts(sentences, keep=lambda w: True, boundary="<s>"):
    uni, bi, tri = collections.Counter(), collections.Counter(), collections.Counter()
    for toks in sentences:
        prev2, prev1 = None, boundary
        for tok in toks:
            if not keep(tok):
                prev2, prev1 = None, None
                continue
            uni[tok] += 1
            if prev1 is not None:
                bi[(prev1, tok)] += 1
                if prev2 is not None:
                    tri[(prev2 + " " + prev1, tok)] += 1
            prev2, prev1 = prev1, tok
        # An end marker lets phrase prediction learn where a message naturally stops.
        if prev1 is not None:
            bi[(prev1, END)] += 1
            if prev2 is not None:
                tri[(prev2 + " " + prev1, END)] += 1
    return uni, bi, tri


def prune(counter, per_ctx, minimum):
    groups = collections.defaultdict(list)
    for (ctx, nxt), c in counter.items():
        if c >= minimum:
            groups[ctx].append((c, nxt))
    out = {}
    for ctx, rows in groups.items():
        rows.sort(key=lambda r: (-r[0], r[1]))
        for c, nxt in rows[:per_ctx]:
            out[(ctx, nxt)] = c
    return out


def english_sentences():
    path = os.path.join(RAW, "eng_sentences.tsv")
    if not os.path.exists(path):
        sys.exit("Data/raw is missing. Run Tools/fetch_sources.sh first.")
    # Tatoeba leans heavily on the placeholder characters Tom and Mary.
    names = re.compile(r"\b(Tom|Mary|Sami|Layla|Muiriel|Ziri|Yanni|Rima|John|Mennad|Baya|Skura)\b")
    kept = 0
    with open(path, encoding="utf8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3 or names.search(parts[2]):
                continue
            toks = tokenize(parts[2])
            if 2 <= len(toks) <= 14:
                yield toks
                kept += 1
                if kept >= EN_SENTENCE_LIMIT:
                    return


def build_english():
    freq = {}
    dict_words = set()
    if os.path.exists("/usr/share/dict/web2"):
        with open("/usr/share/dict/web2", encoding="utf8") as f:
            dict_words = {l.strip().lower() for l in f}
    for rank, line in enumerate(read_lines(os.path.join(RAW, "en_50k.txt"))):
        word, count = line.split(" ")
        if not re.fullmatch(r"[a-z]+", word) or rank > 50000:
            continue
        # Subtitle lists contain names and foreign words. Below the very common
        # band, keep only what a dictionary or a regular suffix can vouch for.
        if rank > 12000 and word not in dict_words:
            stem_ok = any(word.endswith(s) and word[: -len(s)] in dict_words for s in ("s", "es", "ed", "ing", "er", "ly", "d"))
            if not stem_ok:
                continue
        freq[word] = int(count)
        if len(freq) >= EN_VOCAB:
            break
    # Fragments of contractions from the subtitle tokeniser, and single letters.
    for junk in ("don", "didn", "doesn", "isn", "wasn", "couldn", "wouldn", "shouldn", "aren", "ll", "ve", "re", "t", "s", "d", "m",
                 "b", "c", "e", "f", "g", "h", "j", "k", "l", "n", "o", "p", "q", "r", "u", "v", "w", "x", "y", "z", "ain", "weren", "hasn", "haven", "hadn"):
        freq.pop(junk, None)
    return freq


def main():
    os.makedirs(OUT, exist_ok=True)
    lexicon = load_lexicon()
    nosuggest = {w.strip().lower() for w in read_lines(os.path.join(ROOT, "Data/hinglish/nosuggest.txt"))}

    def canonicalize(tok):
        e = lexicon.get(tok)
        return e.canonical if e else tok

    # --- Hinglish model ---
    hi_surface = collections.Counter()
    hi_sentences = []
    for line in read_lines(os.path.join(ROOT, "Data/hinglish/corpus.txt")):
        toks = tokenize(line)
        hi_surface.update(toks)
        hi_sentences.append([canonicalize(t) for t in toks])
    h_uni, h_bi, h_tri = ngram_counts(hi_sentences)

    # --- English model ---
    en_freq = build_english()
    en_sents = list(english_sentences())
    authored = [tokenize(l) for l in read_lines(os.path.join(ROOT, "Data/english/corpus.txt"))]
    # Authored sentences describe how people text, so they outweigh translation-style examples.
    en_sents.extend(authored * 12)
    contractions = collections.Counter()
    for toks in en_sents:
        contractions.update(t for t in toks if "'" in t)
    for w, c in contractions.items():
        if c >= 20 and len(w) <= 12:
            en_freq.setdefault(w, c * 30)
    en_vocab = set(en_freq) | set(contractions)
    _, e_bi, e_tri = ngram_counts(en_sents, keep=lambda w: w in en_vocab and w not in nosuggest)
    e_bi = prune(e_bi, EN_BIGRAMS_PER_WORD, EN_BIGRAM_MIN)
    e_tri = prune(e_tri, EN_TRIGRAMS_PER_CTX, EN_TRIGRAM_MIN)

    # --- Devanagari model ---
    deva_sents = []
    with open(os.path.join(RAW, "hin_sentences.tsv"), encoding="utf8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 3:
                toks = DEVA_RE.findall(parts[2])
                if toks:
                    deva_sents.append(toks)
    deva_extra = [e.deva for e in lexicon.values() if e.deva and " " not in e.deva]
    d_uni, d_bi, d_tri = ngram_counts(deva_sents)
    d_bi = prune(d_bi, 8, 2)
    d_tri = prune(d_tri, 4, 2)

    # --- words.tsv ---
    rows = {}

    def row(word):
        return rows.setdefault(word, {"hi": 0, "en": 0, "canon": "", "deva": "", "gloss": "", "flags": set()})

    for word, e in lexicon.items():
        r = row(word)
        # Weight is an authored prior; corpus evidence sits on top of it.
        r["hi"] = (4 ** e.weight) + 40 * hi_surface.get(word, 0) + (20 * h_uni.get(word, 0) if e.is_canonical else 0)
        r["canon"] = e.canonical if e.canonical != word else ""
        r["deva"], r["gloss"] = e.deva, e.gloss
        r["flags"].add("h")
    # Words seen in the Hinglish corpus that are not listed are mostly English loanwords.
    for word, c in hi_surface.items():
        if word not in lexicon:
            r = row(word)
            r["hi"] = max(r["hi"], 10 * c)
            r["flags"].add("l")
    for word, c in en_freq.items():
        r = row(word)
        r["en"] = c
        r["flags"].add("e")
    for word in nosuggest:
        row(word)["flags"].add("n")
    # Devanagari vocabulary, from the lexicon and from the sentence corpus.
    deva_vocab = collections.Counter()
    for word in deva_extra:
        deva_vocab[word] += 20
    deva_vocab.update(d_uni)
    for word, c in deva_vocab.most_common(HI_DEVA_VOCAB):
        r = row(word)
        r["hi"] = max(r["hi"], c)
        r["flags"].add("d")

    with open(os.path.join(OUT, "words.tsv"), "w", encoding="utf8") as f:
        for word in sorted(rows):
            r = rows[word]
            f.write("\t".join([word, "".join(sorted(r["flags"])), str(r["hi"]), str(r["en"]), r["canon"], r["deva"], r["gloss"]]) + "\n")

    # --- ngrams.tsv ---
    def h_trim(counter):
        return {k: c for k, c in counter.items() if c >= 1}

    with open(os.path.join(OUT, "ngrams.tsv"), "w", encoding="utf8") as f:
        for model, order, table in (("h", 2, h_trim(h_bi)), ("h", 3, h_trim(h_tri)), ("e", 2, e_bi), ("e", 3, e_tri), ("d", 2, d_bi), ("d", 3, d_tri)):
            for (ctx, nxt), c in sorted(table.items()):
                f.write(f"{model}\t{order}\t{ctx}\t{nxt}\t{c}\n")

    # --- chargrams.tsv: naive Bayes evidence for words no list has ever seen ---
    def trigrams(word):
        padded = f"^{word}$"
        return [padded[i : i + 3] for i in range(len(padded) - 2)]

    hi_grams, en_grams = collections.Counter(), collections.Counter()
    for word, e in lexicon.items():
        for g in trigrams(word):
            hi_grams[g] += 1 + e.weight
    for word, c in sorted(en_freq.items(), key=lambda kv: -kv[1])[:15000]:
        if word not in lexicon:
            for g in trigrams(word):
                en_grams[g] += 1 + int(math.log10(max(c, 10)))
    hi_total, en_total = sum(hi_grams.values()), sum(en_grams.values())
    vocab = set(hi_grams) | set(en_grams)
    with open(os.path.join(OUT, "chargrams.tsv"), "w", encoding="utf8") as f:
        f.write(f"#floor\t{math.log(1 / (hi_total + len(vocab))):.3f}\t{math.log(1 / (en_total + len(vocab))):.3f}\n")
        for g in sorted(vocab):
            hi, en = hi_grams[g], en_grams[g]
            if hi + en < 3:
                continue
            f.write(f"{g}\t{math.log((hi + 1) / (hi_total + len(vocab))):.3f}\t{math.log((en + 1) / (en_total + len(vocab))):.3f}\n")

    for name in ("words.tsv", "ngrams.tsv", "chargrams.tsv"):
        path = os.path.join(OUT, name)
        print(f"{name}: {os.path.getsize(path) / 1024:.0f} KB, {sum(1 for _ in open(path, encoding='utf8'))} lines")
    print(f"hinglish lexicon {len(lexicon)}, english {len(en_freq)}, deva sentences {len(deva_sents)}, english sentences {len(en_sents)}")


if __name__ == "__main__":
    main()
