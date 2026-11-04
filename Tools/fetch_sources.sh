#!/bin/sh
# Downloads the CC-licensed raw sources into Data/raw (git-ignored).
# Only derived counts are committed. See NOTICE.md for licences.
set -eu
cd "$(dirname "$0")/.."
mkdir -p Data/raw
curl -fsSL -o Data/raw/en_50k.txt https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/en/en_50k.txt
curl -fsSL -o Data/raw/eng_sentences.tsv.bz2 https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences.tsv.bz2
curl -fsSL -o Data/raw/hin_sentences.tsv.bz2 https://downloads.tatoeba.org/exports/per_language/hin/hin_sentences.tsv.bz2
bunzip2 -fk Data/raw/eng_sentences.tsv.bz2 Data/raw/hin_sentences.tsv.bz2
echo "Fetched raw sources into Data/raw"
