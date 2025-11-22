import sys, json
from cefrpy import CEFRAnalyzer
from preprocessor import preprocess

def main():
    analyzer = CEFRAnalyzer()
    # print(analyzer.get_average_word_level_CEFR("believe"))
    # print(analyzer.get_average_word_level_float("believe"))

    # 讀取 Ruby 傳進來的字串（以逗號分隔）
    raw = sys.argv[1] if len(sys.argv) > 1 else ""
    words = [w.strip() for w in raw.split(",") if w.strip()]
    words = preprocess(words)

    # 針對每個詞分析 CEFR 等級
    result = {word: str(analyzer.get_average_word_level_CEFR(word)) for word in words}

    # 印出 JSON 給 Ruby
    print(json.dumps(result))

if __name__ == "__main__":
    main()