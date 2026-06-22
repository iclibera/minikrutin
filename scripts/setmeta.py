import mk

VERSION_ID = "103901a5-aee7-4e39-a441-1480d87df3e3"
VER_LOC = "c65539ff-2ed1-40a1-848b-59ef92732fb3"
APPINFO = "40233852-4ae4-44fc-9eb0-5d42f3af63c4"
INFO_LOC = "98d7b2cb-fe9f-4255-a38b-ef28ebe42321"

DESCRIPTION = """MinikRutin, yeni ebeveynlerin bebeğinin günlük bakım düzenini kolayca takip etmesi için tasarlanmış sade, reklamsız bir bebek günlüğüdür. Uykusuz günlerde bile birkaç saniyede kayıt girin; bebeğinizin son durumunu tek bakışta görün.

NELER YAPABİLİRSİNİZ
• Tek dokunuşla beslenme (anne sütü, mama, emzirme), uyku, bez, ilaç ve ateş kaydı
• Bugün ekranı: son beslenme, son bez, bugünkü uyku ve toplam mama
• Süt sağma ve serbest notlar (kusma, gaz, huzursuzluk)
• Haftalık özet, grafikler ve trend analizi
• Büyüme takibi (kilo, boy, baş çevresi)
• Aşı ve doktor kontrol defteri
• Fotoğraflı gelişim anıları (yalnızca cihazınızda)
• Beslenme, D vitamini ve doktor kontrolü hatırlatmaları

DOKTORA HAZIR
Son 7 günün beslenme, uyku, bez, ateş, ilaç ve not özetini tek sayfalık, paylaşılabilir bir PDF rapora dönüştürün. Doktora giderken hiçbir detayı unutmayın.

GÜVENLİ VE SADE
• Reklamsız ve sade arayüz
• Veriler öncelikle cihazınızda; bulut yedekleme ve aile/bakıcı paylaşımı isteğe bağlı
• Büyük butonlar, tek elle kullanım, tamamen Türkçe
• Verilerinizi dışa aktarın veya tek dokunuşla silin

MINIKRUTIN PREMIUM
Sınırsız PDF doktor raporu, gelişmiş grafikler, aile/bakıcı paylaşımı, bulut yedekleme ve birden fazla bebek profili Premium ile sunulur. Aylık ve yıllık abonelik seçenekleri 14 gün ücretsiz deneme ile sunulur. Abonelik, satın alma onayında Apple Kimliğinizden ücretlendirilir ve dönem bitiminden en az 24 saat önce kapatılmazsa otomatik yenilenir. Aboneliği App Store ayarlarından yönetebilir veya iptal edebilirsiniz.

ÖNEMLİ
MinikRutin tıbbi teşhis veya tedavi önerisi vermez. Sağlık kararları, aşı ve ilaç kullanımı için doktorunuza danışın.

Gizlilik Politikası: https://iclibera.github.io/minikrutin/privacy.html
Kullanım Koşulları (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"""

KEYWORDS = "bebek takip,bebek uyku,bebek beslenme,emzirme takip,mama takip,bez takip,bebek günlüğü,yenidoğan"
SUBTITLE = "Bebek bakım ve uyku günlüğü"
PROMO = "Doktora giderken hiçbir detayı unutmayın. Beslenme, uyku, bez ve sağlık kayıtları tek yerde; haftalık özet ve doktor raporu cebinizde."

cfg = mk.cfg()

# 1) Version localization text (subtitle lives on appInfoLocalizations, not here)
mk.asc_api.set_version_localization(cfg, VER_LOC, {
    "description": DESCRIPTION,
    "keywords": KEYWORDS,
    "promotionalText": PROMO,
    "supportUrl": "https://iclibera.github.io/minikrutin/support.html",
    "marketingUrl": "https://iclibera.github.io/minikrutin/",
})

# 2) Copyright
mk.asc_api.set_copyright(cfg, VERSION_ID, "2026 Bera Icli")

# 3) Subtitle + privacy policy URL on app info localization
mk.asc_api.set_app_info_localization(cfg, INFO_LOC, {
    "subtitle": SUBTITLE,
    "privacyPolicyUrl": "https://iclibera.github.io/minikrutin/privacy.html",
})

# 4) Categories
mk.asc_api.set_categories(cfg, APPINFO, "HEALTH_AND_FITNESS", "LIFESTYLE")

# 5) Content rights
mk.asc_api.set_content_rights(cfg)

# 6) Age rating (4+; honest health/wellness flag)
rating = {
    "violenceCartoonOrFantasy": "NONE",
    "violenceRealistic": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
    "profanityOrCrudeHumor": "NONE",
    "matureOrSuggestiveThemes": "NONE",
    "horrorOrFearThemes": "NONE",
    "medicalOrTreatmentInformation": "NONE",
    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
    "gamblingSimulated": "NONE",
    "sexualContentOrNudity": "NONE",
    "sexualContentGraphicAndNudity": "NONE",
    "contests": "NONE",
    "gunsOrOtherWeapons": "NONE",
    "gambling": False,
    "unrestrictedWebAccess": False,
    "lootBox": False,
    "messagingAndChat": False,
    "parentalControls": False,
    "healthOrWellnessTopics": True,
    "userGeneratedContent": False,
    "ageAssurance": False,
    "advertising": False,
}
mk.asc_api.set_age_rating(cfg, APPINFO, rating)

print("len(description) =", len(DESCRIPTION), "| len(keywords) =", len(KEYWORDS), "| len(subtitle) =", len(SUBTITLE), "| len(promo) =", len(PROMO))
print("DONE")
