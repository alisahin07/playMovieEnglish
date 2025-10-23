import re
import json
import requests

BASE_URL = "https://www.playphrase.me/#/search?q="
LANG_PARAM = "&language=en"

def clean_line(line):
    """501., (43) ve grade gibi bölümleri regex ile temizler"""
    line = re.sub(r'^\s*\d+\.\s*', '', line)      # baştaki numarayı sil (örnek: 501.)
    line = re.sub(r'\(\d+\)', '', line)           # (43) gibi parantezli sayıları sil
    line = re.sub(r'\bgrade\b', '', line, flags=re.IGNORECASE)  # grade kelimesini sil
    return line.strip()

def build_link(phrase):
    """Temizlenmiş metni URL haline getirir"""
    encoded = '+'.join(phrase.split())
    return f"{BASE_URL}{encoded}{LANG_PARAM}"

def check_link(url):
    """Linkin çalışıp çalışmadığını kontrol eder"""
    try:
        response = requests.get(url, timeout=8)
        return response.status_code == 200
    except Exception:
        return False

def main():
    # Kullanıcıdan JSON dosya adını al
    json_filename = input("Kaydedilecek JSON dosyasının adını girin (örnek: sonuclar.json): ").strip()
    if not json_filename.endswith(".json"):
        json_filename += ".json"

    with open("metin.txt", "r", encoding="utf-8") as f:
        lines = f.readlines()

    results = []
    for line in lines:
        phrase = clean_line(line)
        if not phrase:
            continue

        url = build_link(phrase)
        if check_link(url):
            results.append({"url": url, "title": phrase})
        else:
            print(f"❌ ÇALIŞMIYOR: {url}")

    # JSON olarak kaydet
    with open(json_filename, "w", encoding="utf-8") as outfile:
        json.dump(results, outfile, indent=4, ensure_ascii=False)

    print(f"\n✅ {len(results)} adet çalışan link {json_filename} dosyasına kaydedildi.")

if __name__ == "__main__":
    main()
