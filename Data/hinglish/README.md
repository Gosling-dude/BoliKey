# Hinglish language data

Everything in this folder is hand-authored for BoliKey and fed into `Tools/build_language_data.py`.

- `lexicon.psv`: vocabulary, spelling variants, Devanagari and glosses.
- `verbs.psv`: verb table, expanded into conjugated forms.
- `corpus.txt`: conversational messages, used to train the Hinglish n-gram model.
- `improvements.psv`: optional sentence-level improvements.
- `nosuggest.txt`: words that are recognised but never proposed.
