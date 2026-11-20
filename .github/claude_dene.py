"""Derlemeden once Claude baglantisini dener: uygulamanin gonderdigi istegin aynisini yollar.

Anahtar hicbir zaman yazdirilmaz. Sonuclar GitHub "annotation" olarak gorunur.
"""
import json
import os
import sys
import urllib.error
import urllib.request

ANAHTAR = os.environ.get("ANTHROPIC_API_KEY", "")
MODEL = os.environ.get("CLAUDE_MODEL", "claude-haiku-5-5")


def dene(ad, max_tokens, ek=None):
    govde = {
        "model": MODEL,
        "max_tokens": max_tokens,
        "system": "You write short reading passages for English learners. Reply with the passage only.",
        "output_config": {"effort": "low"},
        "messages": [{"role": "user", "content": "Write a short reading passage (about 40-50 words) at A2 level."}],
    }
    if ek:
        govde.update(ek)
    istek = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(govde).encode(),
        headers={"content-type": "application/json", "x-api-key": ANAHTAR, "anthropic-version": "2026-10-21"},
    )
    try:
        with urllib.request.urlopen(istek, timeout=90) as yanit:
            kod, veri = yanit.status, json.loads(yanit.read())
    except urllib.error.HTTPError as e:
        kod = e.code
        try:
            veri = json.loads(e.read())
        except Exception:
            veri = {}
    except Exception as e:  # ag hatasi
        print(f"::error title=Claude {ad}::Baglanti kurulamadi: {type(e).__name__}")
        return False

    if kod != 200:
        hata = (veri.get("error") or {}) if isinstance(veri, dict) else {}
        print(f"::error title=Claude {ad}::HTTP {kod} {hata.get('type', '')}: {str(hata.get('message', ''))[:300]}")
        return False

    bloklar = [b.get("type") for b in veri.get("content", [])]
    metin = " ".join(b.get("text", "") for b in veri.get("content", []) if b.get("type") == "text").strip()
    kullanim = veri.get("usage", {})
    ozet = (f"stop_reason={veri.get('stop_reason')} bloklar={bloklar} metin_uzunlugu={len(metin)} "
            f"output_tokens={kullanim.get('output_tokens')}")
    if not metin:
        print(f"::error title=Claude {ad}::Yanit bos geldi. {ozet}")
        return False
    print(f"::notice title=Claude {ad}::Calisiyor. {ozet}")
    return True


if not ANAHTAR:
    print("::error title=Claude anahtari yok::ANTHROPIC_API_KEY secret'i tanimli degil. "
          "GitHub > Settings > Secrets and variables > Actions altina ekleyin.")
    sys.exit(1)

sonuclar = [
    dene("kisa (max 400)", 400),
    dene("uzun (max 4096)", 4096),
    dene("dusunmesiz (max 400)", 400, {"thinking": {"type": "disabled"}}),
]
sys.exit(0 if all(sonuclar) else 1)
