import re
import nltk
import spacy
import contractions
import unicodedata
from nltk.corpus import stopwords

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

def normalize_apostrophe_endings(word):
    return re.sub(r"([a-zA-Z]+)in'$", r"\1ing", word)

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

def preprocess(words):
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
            if sub.lower() not in STOP_WORDS:
                cleaned.append(sub.lower())

            # Lemmatize
            # lemma = nlp(sub)[0].lemma_
            # if lemma.lower() not in STOP_WORDS:
            #     cleaned.append(lemma.lower())
    return cleaned

if __name__ == "__main__":
    # print(preprocess(["you're"]))
    print(normalize_apostrophe_endings("hidin'"))
    print(normalize_leading_apostrophe("'bout"))