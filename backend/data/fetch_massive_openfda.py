"""
Fetch massive drug data from OpenFDA API.
Gets drug labels, adverse events, and recalls for hundreds of common drugs.
"""
import json
import urllib.request
import urllib.parse
import time
import sys

# Comprehensive list of common drug names (generic names)
DRUG_NAMES = [
    # Pain & Inflammation
    "acetaminophen", "ibuprofen", "naproxen", "aspirin", "diclofenac",
    "meloxicam", "celecoxib", "indomethacin", "piroxicam", "ketorolac",
    "tramadol", "morphine", "codeine", "oxycodone", "hydrocodone",
    "fentanyl", "buprenorphine", "naloxone", "naltrexone", "gabapentin",
    "pregabalin", "duloxetine", "amitriptyline", "nortriptyline",

    # Antibiotics
    "amoxicillin", "azithromycin", "ciprofloxacin", "levofloxacin",
    "metronidazole", "doxycycline", "clindamycin", "trimethoprim",
    "sulfamethoxazole", "cephalexin", "ceftriaxone", "cefuroxime",
    "clarithromycin", "erythromycin", "penicillin", "ampicillin",
    "gentamicin", "tobramycin", "vancomycin", "linezolid",
    "nitrofurantoin", "fosfomycin", "meropenem", "piperacillin",
    "rifampin", "isoniazid", "ethambutol", "pyrazinamide",
    "moxifloxacin", "ofloxacin", "norfloxacin", "cefixime",
    "ceftazidime", "cefotaxime", "amikacin", "colistin",

    # Cardiovascular
    "amlodipine", "lisinopril", "losartan", "metoprolol", "atenolol",
    "propranolol", "carvedilol", "valsartan", "irbesartan", "telmisartan",
    "ramipril", "enalapril", "captopril", "hydrochlorothiazide",
    "furosemide", "spironolactone", "digoxin", "warfarin", "heparin",
    "clopidogrel", "ticagrelor", "rivaroxaban", "apixaban", "dabigatran",
    "atorvastatin", "rosuvastatin", "simvastatin", "pravastatin",
    "fenofibrate", "ezetimibe", "nifedipine", "diltiazem", "verapamil",
    "nitroglycerin", "isosorbide", "hydralazine", "minoxidil",
    "doxazosin", "prazosin", "clonidine", "methyldopa",
    "amiodarone", "sotalol", "flecainide",

    # Diabetes
    "metformin", "glimepiride", "gliclazide", "glipizide", "glyburide",
    "sitagliptin", "linagliptin", "saxagliptin", "vildagliptin",
    "empagliflozin", "dapagliflozin", "canagliflozin",
    "liraglutide", "semaglutide", "dulaglutide", "exenatide",
    "pioglitazone", "acarbose", "insulin",

    # Respiratory
    "salbutamol", "albuterol", "ipratropium", "tiotropium",
    "fluticasone", "budesonide", "beclomethasone", "montelukast",
    "theophylline", "roflumilast", "formoterol", "salmeterol",
    "cetirizine", "loratadine", "fexofenadine", "desloratadine",
    "chlorpheniramine", "diphenhydramine", "promethazine",
    "dextromethorphan", "guaifenesin", "pseudoephedrine",

    # GI
    "omeprazole", "esomeprazole", "pantoprazole", "lansoprazole",
    "rabeprazole", "ranitidine", "famotidine", "sucralfate",
    "domperidone", "metoclopramide", "ondansetron", "granisetron",
    "loperamide", "bismuth", "mesalamine", "sulfasalazine",
    "lactulose", "polyethylene glycol", "bisacodyl", "senna",

    # Psychiatric / Neuro
    "sertraline", "fluoxetine", "paroxetine", "citalopram",
    "escitalopram", "venlafaxine", "desvenlafaxine", "mirtazapine",
    "bupropion", "trazodone", "quetiapine", "olanzapine",
    "risperidone", "aripiprazole", "haloperidol", "chlorpromazine",
    "lithium", "valproate", "carbamazepine", "lamotrigine",
    "topiramate", "levetiracetam", "phenytoin", "phenobarbital",
    "diazepam", "lorazepam", "alprazolam", "clonazepam",
    "zolpidem", "zopiclone", "melatonin",
    "donepezil", "memantine", "rivastigmine",
    "methylphenidate", "atomoxetine",
    "sumatriptan", "rizatriptan",

    # Endocrine / Hormones
    "levothyroxine", "methimazole", "propylthiouracil",
    "prednisolone", "prednisone", "dexamethasone", "hydrocortisone",
    "methylprednisolone", "betamethasone", "fludrocortisone",
    "testosterone", "estradiol", "progesterone",
    "letrozole", "tamoxifen", "anastrozole",
    "finasteride", "dutasteride", "sildenafil", "tadalafil",

    # Infectious Disease
    "acyclovir", "valacyclovir", "oseltamivir", "remdesivir",
    "fluconazole", "itraconazole", "voriconazole", "ketoconazole",
    "terbinafine", "nystatin", "amphotericin",
    "ivermectin", "albendazole", "mebendazole", "praziquantel",
    "chloroquine", "hydroxychloroquine", "artemether", "lumefantrine",
    "quinine", "primaquine", "atovaquone",

    # Dermatology
    "tretinoin", "adapalene", "benzoyl peroxide", "clotrimazole",
    "miconazole", "mupirocin", "fusidic acid", "permethrin",
    "calamine", "clobetasol", "mometasone",

    # Eyes
    "timolol", "latanoprost", "brimonidine", "dorzolamide",
    "ciprofloxacin ophthalmic", "artificial tears",

    # Vitamins & Supplements
    "vitamin d", "calcium", "iron", "folic acid", "vitamin b12",
    "zinc", "potassium", "magnesium", "vitamin c", "vitamin a",
    "thiamine", "pyridoxine", "biotin",

    # Oncology (common supportive)
    "methotrexate", "cyclophosphamide", "azathioprine",
    "mycophenolate", "tacrolimus", "cyclosporine",
    "filgrastim", "epoetin",

    # Urology
    "tamsulosin", "alfuzosin", "solifenacin", "oxybutynin",
    "mirabegron", "phenazopyridine",

    # Musculoskeletal
    "allopurinol", "colchicine", "febuxostat",
    "alendronate", "risedronate", "calcitonin",
    "tizanidine", "baclofen", "cyclobenzaprine",
    "methotrexate", "hydroxychloroquine", "sulfasalazine",

    # Anesthesia / Emergency
    "lidocaine", "bupivacaine", "epinephrine", "atropine",
    "dopamine", "dobutamine", "norepinephrine",
    "midazolam", "propofol", "ketamine",

    # Miscellaneous
    "allopurinol", "probenecid", "acetylcysteine",
    "desmopressin", "octreotide", "bromocriptine",
    "cabergoline", "levodopa", "carbidopa", "entacapone",
    "ropinirole", "pramipexole", "selegiline",
]

# Remove duplicates
DRUG_NAMES = list(dict.fromkeys(DRUG_NAMES))

def fetch_url(url, retries=2):
    for attempt in range(retries + 1):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'DawaaCheck/1.0'})
            with urllib.request.urlopen(req, timeout=15) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except Exception as e:
            if attempt < retries:
                time.sleep(1)
            else:
                return None

def fetch_drug_labels(drug_name):
    """Fetch drug label info from OpenFDA"""
    encoded = urllib.parse.quote(drug_name)
    url = f"https://api.fda.gov/drug/label.json?search=openfda.generic_name:\"{encoded}\"&limit=3"
    return fetch_url(url)

def fetch_drug_adverse_events(drug_name):
    """Fetch adverse event counts"""
    encoded = urllib.parse.quote(drug_name)
    url = f"https://api.fda.gov/drug/event.json?search=patient.drug.openfda.generic_name:\"{encoded}\"&count=patient.reaction.reactionmeddrapt.exact&limit=10"
    return fetch_url(url)

def main():
    all_drugs = []
    all_adverse = []
    total = len(DRUG_NAMES)

    print(f"Fetching data for {total} drugs from OpenFDA...")

    for i, drug in enumerate(DRUG_NAMES):
        sys.stdout.write(f"\r[{i+1}/{total}] {drug}...                    ")
        sys.stdout.flush()

        # Fetch label data
        label_data = fetch_drug_labels(drug)
        if label_data and 'results' in label_data:
            for result in label_data['results']:
                openfda = result.get('openfda', {})
                entry = {
                    'generic_name': openfda.get('generic_name', [drug])[0] if openfda.get('generic_name') else drug,
                    'brand_names': openfda.get('brand_name', []),
                    'manufacturer': openfda.get('manufacturer_name', ['Unknown'])[0] if openfda.get('manufacturer_name') else 'Unknown',
                    'route': openfda.get('route', []),
                    'substance_name': openfda.get('substance_name', []),
                    'product_type': openfda.get('product_type', []),
                    'dosage_form': result.get('dosage_and_administration', [''])[0][:200] if result.get('dosage_and_administration') else '',
                    'indications': result.get('indications_and_usage', [''])[0][:300] if result.get('indications_and_usage') else '',
                    'warnings': result.get('warnings', [''])[0][:300] if result.get('warnings') else '',
                    'contraindications': result.get('contraindications', [''])[0][:300] if result.get('contraindications') else '',
                    'drug_interactions': result.get('drug_interactions', [''])[0][:300] if result.get('drug_interactions') else '',
                    'pregnancy': result.get('pregnancy', [''])[0][:200] if result.get('pregnancy') else '',
                    'pediatric_use': result.get('pediatric_use', [''])[0][:200] if result.get('pediatric_use') else '',
                    'adverse_reactions': result.get('adverse_reactions', [''])[0][:300] if result.get('adverse_reactions') else '',
                }
                all_drugs.append(entry)

        # Fetch adverse events (every 3rd drug to save time)
        if i % 3 == 0:
            ae_data = fetch_drug_adverse_events(drug)
            if ae_data and 'results' in ae_data:
                all_adverse.append({
                    'drug_name': drug,
                    'top_reactions': [{'reaction': r['term'], 'count': r['count']} for r in ae_data['results'][:10]]
                })

        # Rate limit: OpenFDA allows 240 requests/minute without key
        time.sleep(0.3)

    print(f"\n\nFetched {len(all_drugs)} drug labels, {len(all_adverse)} adverse event profiles")

    # Save
    with open('openfda_drugs_massive.json', 'w', encoding='utf-8') as f:
        json.dump(all_drugs, f, indent=2, ensure_ascii=False)

    with open('openfda_adverse_events.json', 'w', encoding='utf-8') as f:
        json.dump(all_adverse, f, indent=2, ensure_ascii=False)

    print(f"Saved to openfda_drugs_massive.json and openfda_adverse_events.json")

if __name__ == '__main__':
    main()
