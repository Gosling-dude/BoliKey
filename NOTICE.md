# Third-party data notices

BoliKey's language model is built by `Tools/build_language_data.py`. Raw downloads are not stored in this
repository, only the derived counts in `Packages/BoliKeyKit/Sources/LanguageCore/LanguageData`.

| Data | Source | Licence | Used for |
|---|---|---|---|
| English word frequencies (`en_50k`, 2018) | [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords), derived from OpenSubtitles | CC BY-SA 4.0 | English vocabulary and word frequency |
| English and Hindi example sentences | [Tatoeba](https://tatoeba.org) | CC BY 2.0 FR | English and Devanagari n-gram counts |
| English dictionary check | `/usr/share/dict/web2` (Webster's Second, 1934) | Public domain | Filtering names and foreign words from the frequency list |

All files in `Data/hinglish` and `Data/english` are written for this project.

**Licensing note for a commercial release:** the CC BY-SA licence on the frequency list has share-alike terms for
derived data. Get these terms reviewed before an App Store release, or replace the list with a licensed one.
The Google Web Trillion Word Corpus lists were deliberately not used, because their LDC origin discourages commercial use.
