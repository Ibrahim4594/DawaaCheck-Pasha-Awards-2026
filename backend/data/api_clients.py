"""
External API Clients for Drug Verification
Async HTTP clients for free, public pharmaceutical APIs.
All APIs are free and require NO API key (OpenFDA works without one at 40 req/min).
"""
import asyncio
import logging
from typing import Optional

import httpx

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# OpenFDA Client
# ---------------------------------------------------------------------------

class OpenFDAClient:
    """
    OpenFDA Drug APIs - free, 40 requests/minute without API key.
    Docs: https://open.fda.gov/apis/drug/
    """

    BASE_URL = "https://api.fda.gov"
    BASE = "https://api.fda.gov/drug"
    TIMEOUT = 15.0

    async def search_drug_labels(self, drug_name: str) -> dict:
        """
        Search drug label data including ingredients, warnings, dosage.
        Endpoint: /drug/label.json
        """
        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/label.json",
                    params={
                        "search": f'openfda.brand_name:"{drug_name}"+openfda.generic_name:"{drug_name}"',
                        "limit": 5,
                    },
                )
                if resp.status_code == 200:
                    return resp.json()
                return {}
        except Exception as e:
            logger.warning("OpenFDA drug label search failed for '%s': %s", drug_name, e)
            return {}

    async def check_recalls(self, drug_name: str) -> list:
        """
        Check FDA enforcement/recall records for a drug.
        Endpoint: /drug/enforcement.json
        """
        recalls: list[dict] = []
        try:
            params = {
                "search": f'openfda.brand_name:"{drug_name}"',
                "limit": 10,
            }
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(f"{self.BASE}/enforcement.json", params=params)
                if resp.status_code == 200:
                    data = resp.json()
                    for rec in data.get("results", []):
                        recalls.append({
                            "source": "OpenFDA",
                            "recall_number": rec.get("recall_number"),
                            "reason": rec.get("reason_for_recall", ""),
                            "status": rec.get("status", ""),
                            "classification": rec.get("classification", ""),
                            "product_description": rec.get("product_description", ""),
                            "recall_initiation_date": rec.get("recall_initiation_date", ""),
                            "lot_numbers": rec.get("code_info", ""),
                        })
                elif resp.status_code != 404:
                    logger.warning("OpenFDA enforcement returned status %s", resp.status_code)
        except Exception as exc:
            logger.warning("OpenFDA recall check failed for '%s': %s", drug_name, exc)
        return recalls

    async def get_adverse_events(self, drug_name: str, limit: int = 10) -> list:
        """
        Get adverse event reports from FAERS (FDA Adverse Event Reporting System).
        Endpoint: /drug/event.json
        """
        events: list[dict] = []
        try:
            params = {
                "search": f'patient.drug.openfda.brand_name:"{drug_name}"',
                "limit": limit,
            }
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(f"{self.BASE}/event.json", params=params)
                if resp.status_code == 200:
                    data = resp.json()
                    for rec in data.get("results", []):
                        reactions = [
                            r.get("reactionmeddrapt", "")
                            for r in rec.get("patient", {}).get("reaction", [])
                        ]
                        events.append({
                            "report_id": rec.get("safetyreportid"),
                            "receive_date": rec.get("receivedate"),
                            "serious": rec.get("serious"),
                            "reactions": reactions,
                            "outcome": rec.get("patient", {}).get("patientonsetage"),
                        })
                elif resp.status_code != 404:
                    logger.warning("OpenFDA adverse events returned status %s", resp.status_code)
        except Exception as exc:
            logger.warning("OpenFDA adverse events query failed for '%s': %s", drug_name, exc)
        return events

    async def get_adverse_event_counts(self, drug_name: str) -> dict:
        """Get counts of adverse event reaction types for signal detection."""
        counts: dict = {}
        try:
            params = {
                "search": f'patient.drug.openfda.brand_name:"{drug_name}"',
                "count": "patient.reaction.reactionmeddrapt.exact",
                "limit": 20,
            }
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(f"{self.BASE}/event.json", params=params)
                if resp.status_code == 200:
                    data = resp.json()
                    for rec in data.get("results", []):
                        counts[rec.get("term", "")] = rec.get("count", 0)
                elif resp.status_code != 404:
                    logger.warning("OpenFDA AE counts returned status %s", resp.status_code)
        except Exception as exc:
            logger.warning("OpenFDA AE counts query failed for '%s': %s", drug_name, exc)
        return counts

    async def get_drug_ndc(self, drug_name: str) -> list:
        """
        Get NDC (National Drug Code) directory information.
        Endpoint: /drug/ndc.json
        """
        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/ndc.json",
                    params={"search": f'brand_name:"{drug_name}"', "limit": 5},
                )
                if resp.status_code == 200:
                    data = resp.json()
                    return data.get("results", [])
                return []
        except Exception as e:
            logger.warning("OpenFDA NDC lookup failed for '%s': %s", drug_name, e)
            return []


# ---------------------------------------------------------------------------
# RxNorm Client
# ---------------------------------------------------------------------------

class RxNormClient:
    """
    NIH RxNorm - completely free, no API key needed.
    Docs: https://lhncbc.nlm.nih.gov/RxNav/APIs/
    """

    BASE = "https://rxnav.nlm.nih.gov/REST"
    BASE_URL = BASE
    TIMEOUT = 15.0

    async def get_rxcui(self, drug_name: str) -> Optional[str]:
        """Get RxCUI identifier for a drug name."""
        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/rxcui.json",
                    params={"name": drug_name, "search": 2},
                )
                if resp.status_code == 200:
                    data = resp.json()
                    ids = data.get("idGroup", {}).get("rxnormId", [])
                    return ids[0] if ids else None
                return None
        except Exception as e:
            logger.warning("RxNorm RXCUI lookup failed for '%s': %s", drug_name, e)
            return None

    async def get_generic_name(self, brand_name: str) -> Optional[str]:
        """Convert a brand name to its generic (ingredient) name via RxNorm."""
        try:
            rxcui = await self.get_rxcui(brand_name)
            if not rxcui:
                return None

            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/rxcui/{rxcui}/related.json",
                    params={"tty": "IN"},  # IN = Ingredient
                )
                if resp.status_code == 200:
                    data = resp.json()
                    concept_groups = data.get("relatedGroup", {}).get("conceptGroup", [])
                    for group in concept_groups:
                        props = group.get("conceptProperties", [])
                        if props:
                            return props[0].get("name")
                return None
        except Exception as e:
            logger.warning("RxNorm generic name lookup failed for '%s': %s", brand_name, e)
            return None

    async def get_generic_alternatives(self, drug_name: str) -> list[dict]:
        """Find generic alternatives for a branded drug using RxNorm relations."""
        alternatives: list[dict] = []
        try:
            rxcui = await self.get_rxcui(drug_name)
            if not rxcui:
                return alternatives

            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/rxcui/{rxcui}/related.json",
                    params={"tty": "SBD+SCD+GPCK+BPCK"},
                )
                if resp.status_code == 200:
                    data = resp.json()
                    groups = data.get("relatedGroup", {}).get("conceptGroup", [])
                    for group in groups:
                        for prop in group.get("conceptProperties", []):
                            alternatives.append({
                                "rxcui": prop.get("rxcui"),
                                "name": prop.get("name"),
                                "tty": prop.get("tty"),
                                "source": "RxNorm",
                            })
        except Exception as exc:
            logger.warning("RxNorm alternatives lookup failed for '%s': %s", drug_name, exc)
        return alternatives[:10]

    async def check_interactions(self, rxcui1: str, rxcui2: str) -> list:
        """
        Check drug-drug interactions between two drugs using their RxCUI IDs.
        Returns a list of interaction descriptions.
        """
        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/interaction/list.json",
                    params={"rxcuis": f"{rxcui1}+{rxcui2}"},
                )
                if resp.status_code == 200:
                    data = resp.json()
                    interactions = []
                    for group in data.get("fullInteractionTypeGroup", []):
                        for itype in group.get("fullInteractionType", []):
                            for pair in itype.get("interactionPair", []):
                                interactions.append({
                                    "severity": pair.get("severity", "N/A"),
                                    "description": pair.get("description", ""),
                                })
                    return interactions
                return []
        except Exception as e:
            logger.warning("RxNorm interaction check failed (%s, %s): %s", rxcui1, rxcui2, e)
            return []

    async def check_interactions_by_name(self, drug1: str, drug2: str) -> list:
        """
        Convenience method: check interactions using drug names instead of RxCUIs.
        Resolves names to RxCUIs first, then checks interactions.
        """
        try:
            rxcui1 = await self.get_rxcui(drug1)
            rxcui2 = await self.get_rxcui(drug2)
            if not rxcui1 or not rxcui2:
                return []
            return await self.check_interactions(rxcui1, rxcui2)
        except Exception as e:
            logger.warning("RxNorm interaction check by name failed (%s, %s): %s", drug1, drug2, e)
            return []

    async def get_drug_info(self, drug_name: str) -> dict:
        """Get comprehensive drug information from RxNorm."""
        try:
            rxcui = await self.get_rxcui(drug_name)
            if not rxcui:
                return {}
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/rxcui/{rxcui}/allProperties.json",
                    params={"prop": "all"},
                )
                if resp.status_code == 200:
                    return resp.json()
                return {}
        except Exception as e:
            logger.warning("RxNorm drug info lookup failed for '%s': %s", drug_name, e)
            return {}


# ---------------------------------------------------------------------------
# DailyMed Client
# ---------------------------------------------------------------------------

class DailyMedClient:
    """
    NIH DailyMed - free, no API key needed.
    Docs: https://dailymed.nlm.nih.gov/dailymed/app-support-web-services.cfm
    """

    BASE = "https://dailymed.nlm.nih.gov/dailymed/services/v2"
    BASE_URL = BASE
    TIMEOUT = 15.0

    async def search_drug(self, drug_name: str) -> dict:
        """Search for drug information by name."""
        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/spls.json",
                    params={"drug_name": drug_name, "page": 1, "pagesize": 5},
                )
                if resp.status_code == 200:
                    return resp.json()
                return {}
        except Exception as e:
            logger.warning("DailyMed search failed for '%s': %s", drug_name, e)
            return {}

    async def get_drug_spls(self, drug_name: str) -> list:
        """Get Structured Product Labeling documents for a drug."""
        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/spls.json",
                    params={"drug_name": drug_name},
                )
                if resp.status_code == 200:
                    data = resp.json()
                    return data.get("data", [])
                return []
        except Exception as e:
            logger.warning("DailyMed SPL lookup failed for '%s': %s", drug_name, e)
            return []

    async def get_drug_classes(self, drug_name: str) -> list:
        """Get pharmacologic classes for a drug."""
        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/drugclasses.json",
                    params={"drug_name": drug_name},
                )
                if resp.status_code == 200:
                    data = resp.json()
                    return data.get("data", [])
                return []
        except Exception as e:
            logger.warning("DailyMed drug classes lookup failed for '%s': %s", drug_name, e)
            return []

    async def get_pediatric_info(self, drug_name: str) -> Optional[dict]:
        """Get pediatric use information from DailyMed drug labels."""
        try:
            result = await self.search_drug(drug_name)
            spls = result.get("data", [])
            if not spls:
                return None

            setid = spls[0].get("setid")
            if not setid:
                return None

            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(f"{self.BASE}/spls/{setid}.json")
                if resp.status_code == 200:
                    data = resp.json()
                    return {
                        "title": data.get("title"),
                        "setid": setid,
                        "pediatric_use": data.get("pediatric_use"),
                        "dosage_and_administration": data.get("dosage_and_administration"),
                        "contraindications": data.get("contraindications"),
                        "warnings": data.get("warnings"),
                        "source": "DailyMed",
                    }
        except Exception as exc:
            logger.warning("DailyMed pediatric info lookup failed for '%s': %s", drug_name, exc)
        return None


# ---------------------------------------------------------------------------
# PubChem Client
# ---------------------------------------------------------------------------

class PubChemClient:
    """
    PubChem - completely free, no API key needed.
    Docs: https://pubchem.ncbi.nlm.nih.gov/docs/pug-rest
    """

    BASE = "https://pubchem.ncbi.nlm.nih.gov/rest/pug"
    BASE_URL = BASE
    TIMEOUT = 15.0

    async def verify_compound(self, compound_name: str) -> bool:
        """Verify if a compound name is a real pharmaceutical ingredient."""
        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/compound/name/{compound_name}/JSON"
                )
                return resp.status_code == 200
        except Exception as e:
            logger.warning("PubChem compound verification failed for '%s': %s", compound_name, e)
            return False

    async def verify_compound_detailed(self, compound_name: str) -> Optional[dict]:
        """Verify a compound and return structured result."""
        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/compound/name/{compound_name}/JSON"
                )
                if resp.status_code == 200:
                    data = resp.json()
                    compounds = data.get("PC_Compounds", [])
                    if compounds:
                        cid = compounds[0].get("id", {}).get("id", {}).get("cid")
                        return {
                            "name": compound_name,
                            "cid": cid,
                            "verified": True,
                            "source": "PubChem",
                        }
                elif resp.status_code == 404:
                    return {
                        "name": compound_name,
                        "cid": None,
                        "verified": False,
                        "source": "PubChem",
                    }
        except Exception as exc:
            logger.warning("PubChem compound verification failed for '%s': %s", compound_name, exc)
        return None

    async def get_compound_info(self, compound_name: str) -> dict:
        """Get compound information including molecular formula, weight, etc."""
        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/compound/name/{compound_name}/property/"
                    "MolecularFormula,MolecularWeight,IUPACName,IsomericSMILES/JSON"
                )
                if resp.status_code == 200:
                    data = resp.json()
                    properties = data.get("PropertyTable", {}).get("Properties", [])
                    return properties[0] if properties else {}
                return {}
        except Exception as e:
            logger.warning("PubChem compound info failed for '%s': %s", compound_name, e)
            return {}

    async def get_compound_synonyms(self, compound_name: str) -> list[str]:
        """Get alternative names / synonyms for a compound."""
        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                resp = await client.get(
                    f"{self.BASE}/compound/name/{compound_name}/synonyms/JSON"
                )
                if resp.status_code == 200:
                    data = resp.json()
                    info_list = data.get("InformationList", {}).get("Information", [])
                    if info_list:
                        return info_list[0].get("Synonym", [])[:20]
                return []
        except Exception as e:
            logger.warning("PubChem synonyms lookup failed for '%s': %s", compound_name, e)
            return []

    async def verify_compounds_batch(self, compound_names: list[str]) -> list[dict]:
        """Verify multiple compound names in parallel."""
        tasks = [self.verify_compound_detailed(name) for name in compound_names]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        verified: list[dict] = []
        for r in results:
            if isinstance(r, dict):
                verified.append(r)
            elif isinstance(r, Exception):
                logger.warning("PubChem batch verification error: %s", r)
        return verified


# ---------------------------------------------------------------------------
# Convenience singletons
# ---------------------------------------------------------------------------

openfda_client = OpenFDAClient()
rxnorm_client = RxNormClient()
dailymed_client = DailyMedClient()
pubchem_client = PubChemClient()
