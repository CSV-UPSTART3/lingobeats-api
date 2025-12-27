import sys, json
# import spacy
from cefrpy import CEFRAnalyzer
from preprocessor import preprocess

def main():
    analyzer = CEFRAnalyzer()
    # print(analyzer.get_average_word_level_CEFR("believe"))
    # print(analyzer.get_average_word_level_float("believe"))

    # 讀取 Ruby 傳進來的字串（以逗號分隔）
    raw = sys.argv[1] if len(sys.argv) > 1 else ""
    # print(f"Raw input: {raw}", file=sys.stderr)
    words = [w.strip() for w in raw.split(" ") if w.strip()]
    # print(words, file=sys.stderr)
    words = preprocess(words)

    # 針對每個詞分析 CEFR 等級
    # result = {word: str(analyzer.get_average_word_level_CEFR(word)) for word in words}
    result = []
    for surface, lemma in words:
        level = analyzer.get_average_word_level_CEFR(lemma)
        result.append({
            "origin_word": surface,
            "lemma": lemma,
            "level": str(level) if level else None
        })

    # 印出 JSON 給 Ruby
    print(json.dumps(result))


if __name__ == "__main__":
    main()