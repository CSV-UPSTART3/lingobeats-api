import re
import nltk
import spacy
import contractions
import unicodedata
from nltk.corpus import stopwords
from pathlib import Path

nltk.download('stopwords', quiet = True)
STOP_WORDS = set(stopwords.words('english'))
# print(STOP_WORDS)
# nlp = spacy.load("en_core_web_sm")

# 常見前綴省略對照表
LEADING_APOSTROPHE_MAP = {
    "'bout": "about",
    "’bout": "about",
    "'cause": "because",
    "’cause": "because",
    "'em": "them",
    "’em": "them",
    "'til": "until",
    "’til": "until",
    "'round": "around",
    "’round": "around"
}

# 正規化前綴撇號
def normalize_leading_apostrophe(word):
    # 若有直接在字典中對應
    if word.lower() in LEADING_APOSTROPHE_MAP:
        return LEADING_APOSTROPHE_MAP[word.lower()]

    # 否則處理像 ’neath → beneath 這類通用情形
    return re.sub(r"^[’']([a-z]+)$", r"\1", word)

# 正規化結尾撇號
def normalize_apostrophe_endings(word: str) -> str:
    # ...in' → ...ing
    new_word = re.sub(r"([a-zA-Z]+)in'$", r"\1ing", word)
    if new_word != word:
        return new_word

    # ...n' → ...ing (special case for words like gon')
    m = re.match(r"([a-zA-Z]{2,})n'$", word)
    if m:
        root = m.group(1)[:-1]   # remove the 'n'
        if len(root) >= 2:       # avoid weird words like on' → oing
            return root + "ing"

    # others remain the same
    return word

# 避免非英文字母之特殊字
def normalize_basic_ascii(token: str) -> str:
    # 先把各種彎引號換成直引號
    token = re.sub(r"[’‘`´]", "'", token)
    # Unicode 正規化 -> 拆音標
    token = unicodedata.normalize("NFKD", token)
    # 只保留 ASCII
    token = token.encode("ascii", "ignore").decode("ascii")
    return token

def clean_lyrics_text(text: str) -> str:
    # 移除方括號、括號內的段落標記
    text = re.sub(r"\[[^\]]*\]|\([^)]+\)", " ", text)
    # 只保留字母與引號、空白
    text = re.sub(r"[^A-Za-z'’‘`´ ]+", " ", text)
    # 多重空白合併
    text = re.sub(r"\s+", " ", text).strip()
    return text

def looks_like_word(token: str) -> bool:
    # 長度至少 3
    if len(token) < 3:
        return False
    # 至少要有一個母音 (a e i o u)，避免 th, nth, oop 這種奇怪片段
    # if not re.search(r"[aeiou]", token):
    #     return False
    return True

def filter_name_like_tokens(words, nlp):
    """
    用 spaCy 把看起來是人名或專有名詞的 token 找出來並過濾掉。
    """
    if not words:
        return words

    # 把目前的詞串成一句話給 spaCy 分析
    doc = nlp(" ".join(words))

    name_like = set()
    for token in doc:
        # PERSON：人名實體
        if token.ent_type_ == "PERSON":
            name_like.add(token.text.lower())
            continue

        # PROPN：專有名詞（名字、地名、作品名等）
        if token.pos_ == "PROPN":
            name_like.add(token.text.lower())
            continue

    # 把標記成人名 / 專有名詞的詞排除掉
    return [w for w in words if w.lower() not in name_like]

def lemmatize_with_spacy(words, nlp):
    if not words:
        return []

    doc = nlp(" ".join(words))
    lemmas = []
    for token in doc:
        lemma = token.lemma_.lower()
        if lemma in STOP_WORDS:
            continue
        if not looks_like_word(lemma):
            continue
        lemmas.append(lemma)
    return lemmas

def preprocess(words):
    # 確保 spaCy 模型已安裝
    local_model_path = Path(__file__).parent / "en_core_web_sm" / "en_core_web_sm-3.8.0"
    try:
        nlp = spacy.load(local_model_path)
    except Exception as e:
        raise RuntimeError(f"Failed to load local spaCy model: {e}")
    
    """Expand contractions and remove stopwords"""
    cleaned = []
    for word in words:
        word = clean_lyrics_text(word)
        word = normalize_basic_ascii(word)        # 先轉成純 ASCII
        if not word: 
            continue

        expanded = contractions.fix(word) # e.g. you're -> you are
        # print(expanded)
        for sub in expanded.split(): # 拆成 ["you", "are"]
            sub = normalize_basic_ascii(sub) 
            sub = normalize_leading_apostrophe(sub)
            # Handle words like hidin'
            sub = normalize_apostrophe_endings(sub)

            sub_lower = sub.lower()
            if sub_lower in STOP_WORDS:
                continue
            if not looks_like_word(sub_lower):
                continue
            
            cleaned.append(sub_lower)
            
    cleaned = filter_name_like_tokens(cleaned, nlp)
    cleaned = lemmatize_with_spacy(cleaned, nlp) # Lemmatize
    return cleaned

if __name__ == "__main__":
    # print(preprocess(["you're"]))
    print(normalize_apostrophe_endings("hidin'"))
    print(normalize_leading_apostrophe("'bout"))