"""
Expand WHO AWaRe and Pediatric Safety databases.
"""
import json

# Expanded WHO AWaRe Classification (2023 update)
WHO_AWARE_EXPANDED = {
    "access": [
        {"name": "Amoxicillin", "class": "Penicillins", "key_access": True, "oral_available": True},
        {"name": "Amoxicillin + Clavulanic Acid", "class": "Penicillins + BLI", "key_access": True, "oral_available": True},
        {"name": "Ampicillin", "class": "Penicillins", "key_access": True, "oral_available": True},
        {"name": "Benzylpenicillin", "class": "Penicillins", "key_access": True, "oral_available": False},
        {"name": "Phenoxymethylpenicillin", "class": "Penicillins", "key_access": True, "oral_available": True},
        {"name": "Cloxacillin", "class": "Penicillins", "key_access": True, "oral_available": True},
        {"name": "Cefalexin", "class": "1st Gen Cephalosporins", "key_access": False, "oral_available": True},
        {"name": "Cefazolin", "class": "1st Gen Cephalosporins", "key_access": False, "oral_available": False},
        {"name": "Chloramphenicol", "class": "Amphenicols", "key_access": True, "oral_available": True},
        {"name": "Doxycycline", "class": "Tetracyclines", "key_access": True, "oral_available": True},
        {"name": "Gentamicin", "class": "Aminoglycosides", "key_access": True, "oral_available": False},
        {"name": "Metronidazole", "class": "Nitroimidazoles", "key_access": True, "oral_available": True},
        {"name": "Nitrofurantoin", "class": "Nitrofurans", "key_access": True, "oral_available": True},
        {"name": "Sulfamethoxazole + Trimethoprim", "class": "Sulfonamides", "key_access": True, "oral_available": True},
        {"name": "Spectinomycin", "class": "Aminocyclitols", "key_access": False, "oral_available": False},
        {"name": "Clindamycin", "class": "Lincosamides", "key_access": False, "oral_available": True},
        {"name": "Secnidazole", "class": "Nitroimidazoles", "key_access": False, "oral_available": True},
        {"name": "Tinidazole", "class": "Nitroimidazoles", "key_access": False, "oral_available": True},
    ],
    "watch": [
        {"name": "Azithromycin", "class": "Macrolides", "priority_pathogen": True, "oral_available": True},
        {"name": "Clarithromycin", "class": "Macrolides", "priority_pathogen": True, "oral_available": True},
        {"name": "Erythromycin", "class": "Macrolides", "priority_pathogen": False, "oral_available": True},
        {"name": "Ciprofloxacin", "class": "Fluoroquinolones", "priority_pathogen": True, "oral_available": True},
        {"name": "Levofloxacin", "class": "Fluoroquinolones", "priority_pathogen": True, "oral_available": True},
        {"name": "Moxifloxacin", "class": "Fluoroquinolones", "priority_pathogen": True, "oral_available": True},
        {"name": "Norfloxacin", "class": "Fluoroquinolones", "priority_pathogen": False, "oral_available": True},
        {"name": "Ofloxacin", "class": "Fluoroquinolones", "priority_pathogen": False, "oral_available": True},
        {"name": "Cefuroxime", "class": "2nd Gen Cephalosporins", "priority_pathogen": True, "oral_available": True},
        {"name": "Cefaclor", "class": "2nd Gen Cephalosporins", "priority_pathogen": False, "oral_available": True},
        {"name": "Cefixime", "class": "3rd Gen Cephalosporins", "priority_pathogen": True, "oral_available": True},
        {"name": "Ceftriaxone", "class": "3rd Gen Cephalosporins", "priority_pathogen": True, "oral_available": False},
        {"name": "Cefotaxime", "class": "3rd Gen Cephalosporins", "priority_pathogen": True, "oral_available": False},
        {"name": "Ceftazidime", "class": "3rd Gen Cephalosporins", "priority_pathogen": True, "oral_available": False},
        {"name": "Cefoperazone", "class": "3rd Gen Cephalosporins", "priority_pathogen": True, "oral_available": False},
        {"name": "Cefpodoxime", "class": "3rd Gen Cephalosporins", "priority_pathogen": False, "oral_available": True},
        {"name": "Cefdinir", "class": "3rd Gen Cephalosporins", "priority_pathogen": False, "oral_available": True},
        {"name": "Piperacillin + Tazobactam", "class": "Penicillins + BLI", "priority_pathogen": True, "oral_available": False},
        {"name": "Amikacin", "class": "Aminoglycosides", "priority_pathogen": True, "oral_available": False},
        {"name": "Tobramycin", "class": "Aminoglycosides", "priority_pathogen": False, "oral_available": False},
        {"name": "Vancomycin (oral)", "class": "Glycopeptides", "priority_pathogen": False, "oral_available": True},
        {"name": "Fosfomycin", "class": "Phosphonic acids", "priority_pathogen": False, "oral_available": True},
        {"name": "Rifampicin", "class": "Rifamycins", "priority_pathogen": False, "oral_available": True},
        {"name": "Fusidic Acid", "class": "Steroid antibiotics", "priority_pathogen": False, "oral_available": True},
    ],
    "reserve": [
        {"name": "Meropenem", "class": "Carbapenems", "last_resort": True, "stewardship_required": True},
        {"name": "Imipenem + Cilastatin", "class": "Carbapenems", "last_resort": True, "stewardship_required": True},
        {"name": "Ertapenem", "class": "Carbapenems", "last_resort": True, "stewardship_required": True},
        {"name": "Doripenem", "class": "Carbapenems", "last_resort": True, "stewardship_required": True},
        {"name": "Aztreonam", "class": "Monobactams", "last_resort": True, "stewardship_required": True},
        {"name": "Cefepime", "class": "4th Gen Cephalosporins", "last_resort": True, "stewardship_required": True},
        {"name": "Ceftaroline", "class": "5th Gen Cephalosporins", "last_resort": True, "stewardship_required": True},
        {"name": "Ceftazidime + Avibactam", "class": "Cephalosporin + BLI", "last_resort": True, "stewardship_required": True},
        {"name": "Ceftolozane + Tazobactam", "class": "Cephalosporin + BLI", "last_resort": True, "stewardship_required": True},
        {"name": "Vancomycin (IV)", "class": "Glycopeptides", "last_resort": True, "stewardship_required": True},
        {"name": "Teicoplanin", "class": "Glycopeptides", "last_resort": True, "stewardship_required": True},
        {"name": "Linezolid", "class": "Oxazolidinones", "last_resort": True, "stewardship_required": True},
        {"name": "Daptomycin", "class": "Lipopeptides", "last_resort": True, "stewardship_required": True},
        {"name": "Colistin", "class": "Polymyxins", "last_resort": True, "stewardship_required": True},
        {"name": "Polymyxin B", "class": "Polymyxins", "last_resort": True, "stewardship_required": True},
        {"name": "Tigecycline", "class": "Glycylcyclines", "last_resort": True, "stewardship_required": True},
        {"name": "Fosfomycin (IV)", "class": "Phosphonic acids", "last_resort": True, "stewardship_required": True},
        {"name": "Plazomicin", "class": "Aminoglycosides", "last_resort": True, "stewardship_required": True},
    ]
}

# Expanded Pediatric Safety Database
PEDIATRIC_SAFETY_EXPANDED = {
    "contraindicated": [
        {"drug": "Aspirin", "reason": "Reye's syndrome risk in children <16 with viral illness", "age_limit": "<16 years", "alternative": "Paracetamol or Ibuprofen"},
        {"drug": "Tetracycline", "reason": "Permanent tooth discoloration and enamel hypoplasia", "age_limit": "<8 years", "alternative": "Amoxicillin or Azithromycin"},
        {"drug": "Doxycycline", "reason": "Tooth discoloration risk (though lower than other tetracyclines)", "age_limit": "<8 years (except life-threatening)", "alternative": "Amoxicillin"},
        {"drug": "Ciprofloxacin", "reason": "Musculoskeletal toxicity - cartilage damage in weight-bearing joints", "age_limit": "<18 years (with exceptions)", "alternative": "Amoxicillin + Clavulanate"},
        {"drug": "Loperamide", "reason": "Risk of paralytic ileus and CNS depression", "age_limit": "<2 years", "alternative": "ORS (Oral Rehydration Solution)"},
        {"drug": "Codeine", "reason": "Ultra-rapid CYP2D6 metabolizers risk fatal respiratory depression", "age_limit": "<12 years", "alternative": "Paracetamol or Ibuprofen"},
        {"drug": "Metoclopramide", "reason": "Higher risk of extrapyramidal reactions and tardive dyskinesia", "age_limit": "<1 year (restricted <18)", "alternative": "Ondansetron"},
        {"drug": "Bismuth Subsalicylate", "reason": "Reye's syndrome risk (contains salicylate)", "age_limit": "<12 years", "alternative": "ORS"},
        {"drug": "Lomotil (Diphenoxylate)", "reason": "Severe CNS depression and respiratory arrest risk", "age_limit": "<2 years", "alternative": "ORS"},
        {"drug": "Promethazine", "reason": "Fatal respiratory depression reported in children", "age_limit": "<2 years", "alternative": "Cetirizine or Loratadine"},
        {"drug": "Diethylstilbestrol", "reason": "Reproductive tract abnormalities", "age_limit": "All pediatric", "alternative": "None - not indicated"},
        {"drug": "Fluoroquinolones (all)", "reason": "Articular cartilage damage in immature joints", "age_limit": "<18 years (exceptions exist)", "alternative": "Beta-lactams or macrolides"},
    ],
    "dose_adjustment_required": [
        {"drug": "Paracetamol", "standard_dose": "15mg/kg every 4-6 hours", "max_daily": "75mg/kg/day (max 4g)", "notes": "Weight-based dosing essential. Most common cause of pediatric overdose."},
        {"drug": "Ibuprofen", "standard_dose": "5-10mg/kg every 6-8 hours", "max_daily": "40mg/kg/day", "notes": "Not for infants <3 months or <5kg. Give with food."},
        {"drug": "Amoxicillin", "standard_dose": "25-50mg/kg/day in 2-3 divided doses", "max_daily": "3g/day", "notes": "High dose (80-90mg/kg) for resistant otitis media."},
        {"drug": "Azithromycin", "standard_dose": "10mg/kg day 1, then 5mg/kg days 2-5", "max_daily": "500mg day 1, 250mg days 2-5", "notes": "Weight-based dosing. Suspension preferred for young children."},
        {"drug": "Cetirizine", "standard_dose": "2.5mg (6mo-2y), 5mg (2-6y), 10mg (>6y)", "max_daily": "Age-dependent", "notes": "Non-sedating preferred over 1st gen antihistamines."},
        {"drug": "Salbutamol", "standard_dose": "100-200mcg (1-2 puffs) via spacer every 4-6 hours", "max_daily": "800mcg (8 puffs) in acute asthma", "notes": "Always use spacer device in children. Nebulizer for <2 years."},
        {"drug": "Prednisolone", "standard_dose": "1-2mg/kg/day for 3-5 days", "max_daily": "60mg/day", "notes": "Short courses don't need tapering. For acute asthma, croup, allergic reactions."},
        {"drug": "Omeprazole", "standard_dose": "0.7-1.4mg/kg once daily", "max_daily": "20mg (<20kg), 40mg (>20kg)", "notes": "MUPS tablets can be dispersed. Capsule contents can be mixed with applesauce."},
        {"drug": "Ondansetron", "standard_dose": "0.15mg/kg (max 4mg per dose)", "max_daily": "16mg", "notes": "Single dose often sufficient for gastroenteritis-related vomiting."},
        {"drug": "Montelukast", "standard_dose": "4mg (2-5y), 5mg (6-14y), 10mg (>14y)", "max_daily": "Age-dependent dose", "notes": "Given at bedtime. FDA black box warning for neuropsychiatric events."},
        {"drug": "Iron (Ferrous Sulfate)", "standard_dose": "3-6mg/kg/day elemental iron", "max_daily": "Age/weight dependent", "notes": "Give between meals with vitamin C. Can cause dark stools."},
        {"drug": "Metformin", "standard_dose": "500mg once daily, titrate to 2000mg/day", "max_daily": "2000mg", "notes": "Only approved for type 2 diabetes in children ≥10 years."},
        {"drug": "Fluoxetine", "standard_dose": "10mg/day, may increase to 20mg after 1 week", "max_daily": "20mg (children), 60mg (adolescents)", "notes": "Only SSRI approved for pediatric depression (≥8 years). FDA black box warning for suicidality."},
        {"drug": "Methylphenidate", "standard_dose": "5mg twice daily, titrate by 5-10mg/week", "max_daily": "60mg/day", "notes": "For ADHD ≥6 years. Monitor growth, appetite, sleep, heart rate."},
        {"drug": "Insulin", "standard_dose": "0.5-1 unit/kg/day", "max_daily": "Variable", "notes": "Type 1 diabetes. Adjust based on blood glucose, carb intake, activity."},
    ],
    "monitoring_required": [
        {"drug": "Valproic Acid", "monitoring": ["Liver function tests", "CBC with platelets", "Serum levels"], "frequency": "Baseline, 1 month, then every 3-6 months", "concern": "Hepatotoxicity risk highest in children <2 years on polytherapy"},
        {"drug": "Carbamazepine", "monitoring": ["CBC", "Liver function", "Serum levels", "Sodium"], "frequency": "Baseline, 2 weeks, 1 month, then every 3-6 months", "concern": "Aplastic anemia, hyponatremia, Stevens-Johnson syndrome risk"},
        {"drug": "Phenytoin", "monitoring": ["Free phenytoin level", "Albumin", "Liver function"], "frequency": "After dose changes and every 3-6 months", "concern": "Non-linear kinetics make dosing challenging in children"},
        {"drug": "Theophylline", "monitoring": ["Serum theophylline level"], "frequency": "After dose changes, during illness", "concern": "Narrow therapeutic index (10-20 mcg/mL). Metabolism varies with age."},
        {"drug": "Aminoglycosides", "monitoring": ["Trough level", "Peak level", "Creatinine", "Audiometry"], "frequency": "After 3rd dose, then twice weekly", "concern": "Nephrotoxicity and ototoxicity. Extended interval dosing preferred."},
        {"drug": "Vancomycin", "monitoring": ["Trough level", "Creatinine"], "frequency": "Before 4th dose, then every 3-5 days", "concern": "Target trough 10-20 mcg/mL. Red man syndrome with rapid infusion."},
        {"drug": "Methotrexate", "monitoring": ["CBC", "Liver function", "Creatinine"], "frequency": "Weekly initially, then monthly", "concern": "Myelosuppression, hepatotoxicity. Supplement with folic acid."},
        {"drug": "Cyclosporine", "monitoring": ["Trough level", "Creatinine", "Blood pressure", "Magnesium"], "frequency": "Twice weekly initially, then monthly", "concern": "Nephrotoxicity, hypertension, hirsutism"},
    ]
}

def main():
    with open('who_aware.json', 'w', encoding='utf-8') as f:
        json.dump(WHO_AWARE_EXPANDED, f, indent=2, ensure_ascii=False)

    total_who = sum(len(v) for v in WHO_AWARE_EXPANDED.values())
    print(f"WHO AWaRe database expanded to {total_who} antibiotics (Access: {len(WHO_AWARE_EXPANDED['access'])}, Watch: {len(WHO_AWARE_EXPANDED['watch'])}, Reserve: {len(WHO_AWARE_EXPANDED['reserve'])})")

    with open('pediatric_safety.json', 'w', encoding='utf-8') as f:
        json.dump(PEDIATRIC_SAFETY_EXPANDED, f, indent=2, ensure_ascii=False)

    total_ped = sum(len(v) for v in PEDIATRIC_SAFETY_EXPANDED.values())
    print(f"Pediatric safety database expanded to {total_ped} entries (Contraindicated: {len(PEDIATRIC_SAFETY_EXPANDED['contraindicated'])}, Dose Adj: {len(PEDIATRIC_SAFETY_EXPANDED['dose_adjustment_required'])}, Monitoring: {len(PEDIATRIC_SAFETY_EXPANDED['monitoring_required'])})")

if __name__ == '__main__':
    main()
