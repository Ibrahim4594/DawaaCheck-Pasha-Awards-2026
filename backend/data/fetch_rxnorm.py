"""
Fetch drug data from RxNorm API (NIH, free, no API key).
Gets drug classifications, NDC codes, and relationships.
"""
import json
import logging
import urllib.request
import time
import sys

logger = logging.getLogger(__name__)

DRUG_NAMES = [
    "acetaminophen", "ibuprofen", "amoxicillin", "azithromycin", "metformin",
    "lisinopril", "amlodipine", "atorvastatin", "omeprazole", "losartan",
    "metoprolol", "levothyroxine", "albuterol", "gabapentin", "sertraline",
    "furosemide", "hydrochlorothiazide", "montelukast", "rosuvastatin",
    "escitalopram", "fluoxetine", "prednisone", "pantoprazole", "clopidogrel",
    "tramadol", "cetirizine", "ciprofloxacin", "doxycycline", "pregabalin",
    "carvedilol", "warfarin", "diazepam", "lorazepam", "clonazepam",
    "quetiapine", "risperidone", "olanzapine", "aripiprazole", "lamotrigine",
    "levetiracetam", "valproic acid", "topiramate", "duloxetine", "venlafaxine",
    "bupropion", "trazodone", "mirtazapine", "fluconazole", "acyclovir",
    "tamsulosin", "finasteride", "sildenafil", "tadalafil", "allopurinol",
    "colchicine", "methotrexate", "hydroxychloroquine", "cyclosporine",
    "tacrolimus", "insulin glargine", "sitagliptin", "empagliflozin",
    "glimepiride", "pioglitazone", "dapagliflozin", "liraglutide",
    "spironolactone", "ramipril", "valsartan", "telmisartan", "bisoprolol",
    "propranolol", "atenolol", "digoxin", "amiodarone", "diltiazem",
    "nifedipine", "rivaroxaban", "apixaban", "enoxaparin",
    "salbutamol", "budesonide", "fluticasone", "tiotropium", "ipratropium",
    "montelukast", "theophylline", "loratadine", "fexofenadine",
    "domperidone", "ondansetron", "ranitidine", "esomeprazole",
    "diclofenac", "naproxen", "meloxicam", "celecoxib", "ketorolac",
    "morphine", "codeine", "fentanyl", "oxycodone",
    "ceftriaxone", "meropenem", "vancomycin", "linezolid", "clindamycin",
    "levofloxacin", "moxifloxacin", "nitrofurantoin", "rifampicin",
    "isoniazid", "ethambutol", "pyrazinamide", "albendazole",
    "prednisolone", "dexamethasone", "methylprednisolone", "hydrocortisone",
    "insulin aspart", "insulin lispro",
]

# Remove duplicates
DRUG_NAMES = list(dict.fromkeys(DRUG_NAMES))

def fetch_url(url):
    try:
        req = urllib.request.Request(url, headers={
            'User-Agent': 'DawaaCheck/1.0',
            'Accept': 'application/json'
        })
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except Exception:
        logger.debug("Failed to fetch RxNorm URL: %s", url)
        return None

def get_rxcui(drug_name):
    """Get RxNorm Concept ID for a drug name"""
    encoded = urllib.parse.quote(drug_name)
    url = f"https://rxnav.nlm.nih.gov/REST/rxcui.json?name={encoded}&search=1"
    data = fetch_url(url)
    if data and 'idGroup' in data and 'rxnormId' in data['idGroup']:
        return data['idGroup']['rxnormId'][0]
    return None

def get_drug_info(rxcui):
    """Get drug properties from RxNorm"""
    url = f"https://rxnav.nlm.nih.gov/REST/rxcui/{rxcui}/allProperties.json?prop=all"
    return fetch_url(url)

def get_drug_class(rxcui):
    """Get drug classification"""
    url = f"https://rxnav.nlm.nih.gov/REST/rxclass/class/byRxcui.json?rxcui={rxcui}&relaSource=ATC"
    return fetch_url(url)

import urllib.parse

def main():
    all_drugs = []
    total = len(DRUG_NAMES)

    print(f"Fetching RxNorm data for {total} drugs...")

    for i, drug in enumerate(DRUG_NAMES):
        sys.stdout.write(f"\r[{i+1}/{total}] {drug}...                    ")
        sys.stdout.flush()

        rxcui = get_rxcui(drug)
        if not rxcui:
            time.sleep(0.2)
            continue

        entry = {
            'name': drug,
            'rxcui': rxcui,
            'classes': [],
            'properties': {}
        }

        # Get classification
        class_data = get_drug_class(rxcui)
        if class_data and 'rxclassDrugInfoList' in class_data:
            drug_info_list = class_data['rxclassDrugInfoList'].get('rxclassDrugInfo', [])
            for info in drug_info_list[:5]:  # top 5 classifications
                if 'rxclassMinConceptItem' in info:
                    cls = info['rxclassMinConceptItem']
                    entry['classes'].append({
                        'name': cls.get('className', ''),
                        'type': cls.get('classType', ''),
                        'id': cls.get('classId', '')
                    })

        # Get properties
        prop_data = get_drug_info(rxcui)
        if prop_data and 'propConceptGroup' in prop_data:
            for group in prop_data['propConceptGroup'].get('propConcept', []):
                prop_name = group.get('propName', '')
                prop_value = group.get('propValue', '')
                if prop_name in ['RxNorm Name', 'TTY', 'AVAILABLE_STRENGTH', 'QUANTITY', 'Source']:
                    entry['properties'][prop_name] = prop_value

        all_drugs.append(entry)
        time.sleep(0.3)  # Rate limit

    print(f"\n\nFetched RxNorm data for {len(all_drugs)} drugs")

    with open('rxnorm_classifications.json', 'w', encoding='utf-8') as f:
        json.dump(all_drugs, f, indent=2, ensure_ascii=False)

    print(f"Saved to rxnorm_classifications.json")

if __name__ == '__main__':
    main()
