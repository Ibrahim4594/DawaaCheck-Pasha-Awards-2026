"""
Expand price database with more Pakistani medicine prices and generic alternatives.
"""
import json
import logging

logger = logging.getLogger(__name__)

NEW_PRICES = [
    # Antibiotics
    {"brand_name": "Augmentin 625mg", "generic_name": "Amoxicillin + Clavulanate", "brand_price": 850, "generic_alternatives": [
        {"name": "Clamoxin (Getz)", "price": 420}, {"name": "Amoclav (Searle)", "price": 380}, {"name": "Clavam (Sami)", "price": 350}
    ]},
    {"brand_name": "Klaricid 500mg", "generic_name": "Clarithromycin", "brand_price": 780, "generic_alternatives": [
        {"name": "Claribid (Getz)", "price": 380}, {"name": "Klacid (Searle)", "price": 350}
    ]},
    {"brand_name": "Tavanic 500mg", "generic_name": "Levofloxacin", "brand_price": 650, "generic_alternatives": [
        {"name": "Levoget (Getz)", "price": 320}, {"name": "Levoquin (Sami)", "price": 280}
    ]},
    {"brand_name": "Avelox 400mg", "generic_name": "Moxifloxacin", "brand_price": 780, "generic_alternatives": [
        {"name": "Moxiget (Getz)", "price": 380}, {"name": "Moxibact (Hilton)", "price": 350}
    ]},
    {"brand_name": "Zinnat 500mg", "generic_name": "Cefuroxime", "brand_price": 720, "generic_alternatives": [
        {"name": "Cefuget (Getz)", "price": 350}, {"name": "Curasef (Searle)", "price": 320}
    ]},
    {"brand_name": "Dalacin C 300mg", "generic_name": "Clindamycin", "brand_price": 680, "generic_alternatives": [
        {"name": "Clindamax (Getz)", "price": 320}, {"name": "Clindasol (Sami)", "price": 280}
    ]},
    {"brand_name": "Suprax 400mg", "generic_name": "Cefixime", "brand_price": 520, "generic_alternatives": [
        {"name": "Cespan (Abbott)", "price": 480}, {"name": "Mega-Cef (Mega)", "price": 280}
    ]},
    {"brand_name": "Meronem 1g Inj", "generic_name": "Meropenem", "brand_price": 4500, "generic_alternatives": [
        {"name": "Meroget (Getz)", "price": 2200}, {"name": "Merosam (Sami)", "price": 1800}
    ]},

    # Cardiovascular
    {"brand_name": "Norvasc 5mg", "generic_name": "Amlodipine", "brand_price": 280, "generic_alternatives": [
        {"name": "Amlor (Searle)", "price": 120}, {"name": "Amlovas (Getz)", "price": 110}
    ]},
    {"brand_name": "Lipitor 20mg", "generic_name": "Atorvastatin", "brand_price": 580, "generic_alternatives": [
        {"name": "Atorget (Getz)", "price": 280}, {"name": "Atorsave (Searle)", "price": 250}
    ]},
    {"brand_name": "Crestor 10mg", "generic_name": "Rosuvastatin", "brand_price": 650, "generic_alternatives": [
        {"name": "Rosuget (Getz)", "price": 320}, {"name": "Rosulip (Searle)", "price": 280}
    ]},
    {"brand_name": "Plavix 75mg", "generic_name": "Clopidogrel", "brand_price": 780, "generic_alternatives": [
        {"name": "Clopiget (Getz)", "price": 350}, {"name": "Plagrel (Sami)", "price": 280}
    ]},
    {"brand_name": "Concor 5mg", "generic_name": "Bisoprolol", "brand_price": 420, "generic_alternatives": [
        {"name": "Bisoget (Getz)", "price": 200}, {"name": "Bisopak (Hilton)", "price": 180}
    ]},
    {"brand_name": "Tritace 5mg", "generic_name": "Ramipril", "brand_price": 350, "generic_alternatives": [
        {"name": "Ramiget (Getz)", "price": 180}, {"name": "Ramistar (Searle)", "price": 160}
    ]},
    {"brand_name": "Cozaar 50mg", "generic_name": "Losartan", "brand_price": 380, "generic_alternatives": [
        {"name": "Losar (Searle)", "price": 180}, {"name": "Losarget (Getz)", "price": 160}
    ]},
    {"brand_name": "Micardis 40mg", "generic_name": "Telmisartan", "brand_price": 420, "generic_alternatives": [
        {"name": "Telmiget (Getz)", "price": 200}, {"name": "Telsartan (Searle)", "price": 180}
    ]},
    {"brand_name": "Xarelto 20mg", "generic_name": "Rivaroxaban", "brand_price": 4500, "generic_alternatives": [
        {"name": "Rivaxa (Getz)", "price": 2200}, {"name": "Rivaban (Searle)", "price": 1800}
    ]},

    # Diabetes
    {"brand_name": "Glucophage 500mg", "generic_name": "Metformin", "brand_price": 120, "generic_alternatives": [
        {"name": "Gluco-M (Searle)", "price": 80}, {"name": "Metget (Getz)", "price": 70}
    ]},
    {"brand_name": "Amaryl 2mg", "generic_name": "Glimepiride", "brand_price": 280, "generic_alternatives": [
        {"name": "Glimeget (Getz)", "price": 140}, {"name": "Glimstar (Searle)", "price": 120}
    ]},
    {"brand_name": "Januvia 100mg", "generic_name": "Sitagliptin", "brand_price": 1800, "generic_alternatives": [
        {"name": "Sitaget (Getz)", "price": 850}, {"name": "Sitabay (Hilton)", "price": 780}
    ]},
    {"brand_name": "Jardiance 25mg", "generic_name": "Empagliflozin", "brand_price": 2800, "generic_alternatives": [
        {"name": "Empaglif (Getz)", "price": 1400}
    ]},
    {"brand_name": "Diamicron MR 60mg", "generic_name": "Gliclazide", "brand_price": 520, "generic_alternatives": [
        {"name": "Gliclaget (Getz)", "price": 250}, {"name": "Gliclaz (Searle)", "price": 220}
    ]},

    # GI
    {"brand_name": "Nexium 40mg", "generic_name": "Esomeprazole", "brand_price": 580, "generic_alternatives": [
        {"name": "Esoget (Getz)", "price": 280}, {"name": "Esopak (Searle)", "price": 250}
    ]},
    {"brand_name": "Risek 20mg", "generic_name": "Omeprazole", "brand_price": 185, "generic_alternatives": [
        {"name": "Osmopak-N (Platinum)", "price": 120}, {"name": "Getzloc (Getz)", "price": 130}
    ]},
    {"brand_name": "Controloc 40mg", "generic_name": "Pantoprazole", "brand_price": 480, "generic_alternatives": [
        {"name": "Panget (Getz)", "price": 220}, {"name": "Panpak (Searle)", "price": 200}
    ]},
    {"brand_name": "Motilium 10mg", "generic_name": "Domperidone", "brand_price": 120, "generic_alternatives": [
        {"name": "Don-A (Hilton)", "price": 65}, {"name": "Domget (Getz)", "price": 55}
    ]},

    # Respiratory
    {"brand_name": "Seretide 250/50", "generic_name": "Fluticasone + Salmeterol", "brand_price": 2800, "generic_alternatives": [
        {"name": "Flutisam (Getz)", "price": 1400}
    ]},
    {"brand_name": "Symbicort 160/4.5", "generic_name": "Budesonide + Formoterol", "brand_price": 2500, "generic_alternatives": [
        {"name": "Budamate (Getz)", "price": 1200}
    ]},
    {"brand_name": "Singulair 10mg", "generic_name": "Montelukast", "brand_price": 650, "generic_alternatives": [
        {"name": "Montiget (Getz)", "price": 320}, {"name": "Montipak (Searle)", "price": 280}
    ]},
    {"brand_name": "Zyrtec 10mg", "generic_name": "Cetirizine", "brand_price": 120, "generic_alternatives": [
        {"name": "Rigix (Sami)", "price": 65}, {"name": "Cetiget (Getz)", "price": 55}
    ]},
    {"brand_name": "Telfast 120mg", "generic_name": "Fexofenadine", "brand_price": 320, "generic_alternatives": [
        {"name": "Fexoget (Getz)", "price": 160}, {"name": "Fexopak (Searle)", "price": 140}
    ]},

    # Psychiatric
    {"brand_name": "Lexapro 10mg", "generic_name": "Escitalopram", "brand_price": 580, "generic_alternatives": [
        {"name": "Esciget (Getz)", "price": 280}, {"name": "Lexam (Searle)", "price": 250}
    ]},
    {"brand_name": "Zoloft 50mg", "generic_name": "Sertraline", "brand_price": 420, "generic_alternatives": [
        {"name": "Serget (Getz)", "price": 200}, {"name": "Sertrapak (Searle)", "price": 180}
    ]},
    {"brand_name": "Seroquel 25mg", "generic_name": "Quetiapine", "brand_price": 380, "generic_alternatives": [
        {"name": "Quetiget (Getz)", "price": 180}
    ]},
    {"brand_name": "Lyrica 75mg", "generic_name": "Pregabalin", "brand_price": 650, "generic_alternatives": [
        {"name": "Pregaget (Getz)", "price": 320}, {"name": "Pregapak (Searle)", "price": 280}
    ]},
    {"brand_name": "Keppra 500mg", "generic_name": "Levetiracetam", "brand_price": 650, "generic_alternatives": [
        {"name": "Leveget (Getz)", "price": 320}, {"name": "Levepak (Searle)", "price": 280}
    ]},
    {"brand_name": "Lamictal 100mg", "generic_name": "Lamotrigine", "brand_price": 550, "generic_alternatives": [
        {"name": "Lamoget (Getz)", "price": 280}
    ]},

    # Pain
    {"brand_name": "Brufen 400mg", "generic_name": "Ibuprofen", "brand_price": 95, "generic_alternatives": [
        {"name": "Ibucap (AGP)", "price": 55}, {"name": "Ibuget (Getz)", "price": 45}
    ]},
    {"brand_name": "Ponstan 500mg", "generic_name": "Mefenamic Acid", "brand_price": 175, "generic_alternatives": [
        {"name": "Mefget (Getz)", "price": 85}, {"name": "Mefpak (Searle)", "price": 75}
    ]},
    {"brand_name": "Cataflam 50mg", "generic_name": "Diclofenac", "brand_price": 145, "generic_alternatives": [
        {"name": "Arsal (Platinum)", "price": 55}, {"name": "Dicloget (Getz)", "price": 65}
    ]},
    {"brand_name": "Celebrex 200mg", "generic_name": "Celecoxib", "brand_price": 580, "generic_alternatives": [
        {"name": "Celeget (Getz)", "price": 280}, {"name": "Celepak (Searle)", "price": 250}
    ]},

    # Thyroid
    {"brand_name": "Eltroxin 50mcg", "generic_name": "Levothyroxine", "brand_price": 180, "generic_alternatives": [
        {"name": "Thyroget (Getz)", "price": 90}, {"name": "Thyrox (Searle)", "price": 80}
    ]},

    # Dermatology
    {"brand_name": "Dermovate Cream", "generic_name": "Clobetasol", "brand_price": 280, "generic_alternatives": [
        {"name": "Clobet (Searle)", "price": 120}
    ]},
    {"brand_name": "Fucidin Cream", "generic_name": "Fusidic Acid", "brand_price": 380, "generic_alternatives": [
        {"name": "Fusiget (Getz)", "price": 180}
    ]},

    # Others
    {"brand_name": "Viagra 50mg", "generic_name": "Sildenafil", "brand_price": 950, "generic_alternatives": [
        {"name": "Silget (Getz)", "price": 350}, {"name": "Vigore (Searle)", "price": 280}
    ]},
    {"brand_name": "Zyloric 300mg", "generic_name": "Allopurinol", "brand_price": 120, "generic_alternatives": [
        {"name": "Alloget (Getz)", "price": 60}
    ]},
    {"brand_name": "Fosamax 70mg", "generic_name": "Alendronate", "brand_price": 850, "generic_alternatives": [
        {"name": "Aleget (Getz)", "price": 420}
    ]},
    {"brand_name": "Plaquenil 200mg", "generic_name": "Hydroxychloroquine", "brand_price": 350, "generic_alternatives": [
        {"name": "HCQ (Searle)", "price": 150}
    ]},
    {"brand_name": "Tamiflu 75mg", "generic_name": "Oseltamivir", "brand_price": 1200, "generic_alternatives": [
        {"name": "Oseltaget (Getz)", "price": 580}
    ]},
    {"brand_name": "Diflucan 150mg", "generic_name": "Fluconazole", "brand_price": 380, "generic_alternatives": [
        {"name": "Flucoget (Getz)", "price": 120}, {"name": "Flucopak (Searle)", "price": 100}
    ]},
]

def main():
    try:
        with open('price_database.json', 'r', encoding='utf-8') as f:
            existing = json.load(f)
    except Exception:
        logger.warning("Could not load existing price_database.json, starting fresh")
        existing = []

    existing_names = {p['brand_name'] for p in existing}
    added = 0
    for price in NEW_PRICES:
        if price['brand_name'] not in existing_names:
            existing.append(price)
            existing_names.add(price['brand_name'])
            added += 1

    with open('price_database.json', 'w', encoding='utf-8') as f:
        json.dump(existing, f, indent=2, ensure_ascii=False)

    print(f"Added {added} new price entries. Total: {len(existing)}")

if __name__ == '__main__':
    main()
