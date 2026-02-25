"""
ACEI v6.0 - Complete Calculation Engine
Phase 1, Week 1 - ENHANCED with EII/SCI Integration

Implements:
- Event Volume Index (EVI) - from scraper
- Enforcement Intensity Index (EII) - from uploaded specs
- Structural Change Index (SCI) - from uploaded specs
- Complete Likelihood (L) calculation
- Article III mathematical engine

Based on:
- ACEI Constitution v6.0 Article III
- ACEI_Technical_Methodology_Section_v6.docx
- acei_eii_sci_module_v6.py
"""

import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from supabase import Client
import logging

logger = logging.getLogger(__name__)

# =============================================================================
# CONFIGURATION - Article III & Annex A
# =============================================================================

# EVI Baselines (weekly tribunal decision counts)
EVI_BASELINES = {
    "dismissal_termination": 25,
    "discrimination_harassment": 20,
    "wages_time_pay": 15,
    "whistleblowing_protected_disclosure": 3,
    "employment_status_classification": 5,
    "redundancy_organizational_change": 10,
    "parental_family_rights": 10,
    "trade_union_collective": 4,
    "contract_notice_disputes": 8,
    "health_safety_protections": 3,
    "data_protection_privacy": 2,
    "transfers_insolvency": 5
}

# Likelihood weights (Article III)
LIKELIHOOD_WEIGHTS = {
    'evi': 0.40,
    'eii': 0.30,
    'sci': 0.30
}

# EII weights (from Technical Methodology)
EII_WEIGHTS = {
    'ras': 0.40,  # Regulatory Action Score
    'tas': 0.30,  # Tribunal Activity Score
    'gps': 0.20,  # Guidance/Policy Signal
    'mvs': 0.10   # Media Visibility Score
}

# SCI weights (from Technical Methodology)
SCI_WEIGHTS = {
    'scs': 0.40,  # Statutory Change Score
    'cls': 0.30,  # Case Law Shift
    'ips': 0.20,  # Institutional Policy Shift
    'mps': 0.10   # Market Practice Shift
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def logistic(x: float) -> float:
    """Logistic function for smooth scaling"""
    return 1 / (1 + np.exp(-x))

def ordinal_map(score_100: float) -> int:
    """
    Map 0-100 score to ordinal 1-5.
    
    Bands:
    0-20   → 1
    20-40  → 2
    40-60  → 3
    60-80  → 4
    80-100 → 5
    """
    score_100 = max(0, min(100, score_100))
    ordinal = 1 + int(score_100 // 20)
    return min(5, ordinal)  # Cap at 5

# =============================================================================
# EVI CALCULATION (Event Volume Index)
# =============================================================================

class EVICalculator:
    """
    Calculate Event Volume Index from tribunal decision counts.
    
    EVI measures weekly tribunal volume relative to baseline.
    Article III formula with ratio-based scoring.
    """
    
    @staticmethod
    def calculate_evi(category: str, weekly_count: int) -> int:
        """
        Calculate EVI for a category.
        
        Args:
            category: Category identifier (e.g., 'dismissal_termination')
            weekly_count: Number of decisions this week
        
        Returns:
            EVI score (1-5)
        """
        baseline = EVI_BASELINES.get(category, 1)
        ratio = weekly_count / baseline if baseline > 0 else 0
        
        # Ratio-based thresholds (Annex A)
        if ratio <= 1.10:
            return 1
        elif ratio <= 1.25:
            return 2
        elif ratio <= 1.50:
            return 3
        elif ratio <= 2.00:
            return 4
        else:
            return 5
    
    @staticmethod
    def calculate_all_evi(supabase: Client, lookback_days: int = 7) -> Dict[str, int]:
        """
        Calculate EVI scores for all 12 categories.
        
        Args:
            supabase: Supabase client
            lookback_days: Days to look back (default 7 for weekly)
        
        Returns:
            Dict mapping category -> EVI score (1-5)
        """
        try:
            cutoff_date = (datetime.now() - timedelta(days=lookback_days)).isoformat()
            
            result = supabase.table('regulatory_updates')\
                .select('metadata')\
                .gte('published_date', cutoff_date)\
                .eq('source_type', 'employment_tribunal')\
                .execute()
            
            # Count by primary category
            category_counts = {cat: 0 for cat in EVI_BASELINES.keys()}
            
            for record in result.data:
                primary_cat = record.get('metadata', {}).get('primary_category')
                if primary_cat in category_counts:
                    category_counts[primary_cat] += 1
            
            # Calculate EVI for each category
            evi_scores = {}
            for category, count in category_counts.items():
                evi_scores[category] = EVICalculator.calculate_evi(category, count)
            
            logger.info(f"Calculated EVI scores: {evi_scores}")
            return evi_scores
            
        except Exception as e:
            logger.error(f"Error calculating EVI scores: {e}")
            return {cat: 1 for cat in EVI_BASELINES.keys()}  # Default to 1

# =============================================================================
# EII CALCULATION (Enforcement Intensity Index)
# =============================================================================

class EIICalculator:
    """
    Calculate Enforcement Intensity Index.
    
    EII₁₀₀ = 0.40·RAS + 0.30·TAS + 0.20·GPS + 0.10·MVS
    
    Measures active enforcement posture through:
    - Regulatory Action Score (RAS): ACAS, EHRC, HMRC, HSE enforcement
    - Tribunal Activity Score (TAS): Tribunal ruling patterns
    - Guidance/Policy Signal (GPS): Official guidance updates
    - Media Visibility Score (MVS): Media coverage intensity
    """
    
    @staticmethod
    def calculate_ras(enforcement_events: List[Dict]) -> float:
        """
        Calculate Regulatory Action Score (0-100).
        
        Based on:
        - ACAS conciliation activity
        - EHRC investigations
        - HMRC naming/shaming
        - HSE enforcement notices
        """
        if not enforcement_events:
            return 20.0  # Baseline minimal activity
        
        # Score based on event count and severity
        score = 20.0  # Baseline
        
        for event in enforcement_events:
            event_type = event.get('type', '')
            severity = event.get('severity', 'low')
            
            # Weight by type
            if 'naming' in event_type or 'prosecution' in event_type:
                score += 15 if severity == 'high' else 10
            elif 'investigation' in event_type:
                score += 10 if severity == 'high' else 5
            elif 'notice' in event_type or 'warning' in event_type:
                score += 5 if severity == 'high' else 2
        
        return min(100, score)
    
    @staticmethod
    def calculate_tas(category: str, evi_score: int) -> float:
        """
        Calculate Tribunal Activity Score (0-100).
        
        Derived from EVI - higher tribunal volume = higher enforcement signal.
        """
        # Map EVI (1-5) to TAS (0-100)
        tas_map = {
            1: 20,  # Minimal activity
            2: 40,  # Routine
            3: 60,  # Elevated
            4: 80,  # Intensive
            5: 100  # Maximum
        }
        return tas_map.get(evi_score, 20)
    
    @staticmethod
    def calculate_gps(guidance_updates: List[Dict]) -> float:
        """
        Calculate Guidance/Policy Signal (0-100).
        
        Based on official guidance publications and updates.
        """
        if not guidance_updates:
            return 30.0  # Baseline
        
        score = 30.0
        for update in guidance_updates:
            scope = update.get('scope', 'minor')
            if scope == 'major':
                score += 20
            elif scope == 'moderate':
                score += 10
            else:
                score += 5
        
        return min(100, score)
    
    @staticmethod
    def calculate_mvs(media_mentions: int) -> float:
        """
        Calculate Media Visibility Score (0-100).
        
        Based on employment law media coverage count.
        """
        # Logarithmic scaling
        if media_mentions == 0:
            return 10.0
        
        score = 10 + (np.log10(media_mentions) * 30)
        return min(100, score)
    
    @staticmethod
    def compute_eii(
        ras: float = 20.0,
        tas: float = 20.0,
        gps: float = 30.0,
        mvs: float = 10.0
    ) -> int:
        """
        Compute final EII ordinal score (1-5).
        
        Args:
            ras: Regulatory Action Score (0-100)
            tas: Tribunal Activity Score (0-100)
            gps: Guidance/Policy Signal (0-100)
            mvs: Media Visibility Score (0-100)
        
        Returns:
            EII ordinal (1-5)
        """
        eii_100 = (
            EII_WEIGHTS['ras'] * ras +
            EII_WEIGHTS['tas'] * tas +
            EII_WEIGHTS['gps'] * gps +
            EII_WEIGHTS['mvs'] * mvs
        )
        
        return ordinal_map(eii_100)
    
    @staticmethod
    def calculate_eii_for_category(
        category: str,
        evi_score: int,
        supabase: Client
    ) -> Tuple[int, Dict]:
        """
        Calculate complete EII for a category with component breakdown.
        
        Returns:
            (eii_score, components_dict)
        """
        try:
            # Get enforcement events (placeholder - would query real data)
            enforcement_events = []  # TODO: Query from enforcement_events table
            
            # Get guidance updates (placeholder)
            guidance_updates = []  # TODO: Query from guidance_updates table
            
            # Get media mentions (placeholder)
            media_mentions = 0  # TODO: Query from media_tracking table
            
            # Calculate components
            ras = EIICalculator.calculate_ras(enforcement_events)
            tas = EIICalculator.calculate_tas(category, evi_score)
            gps = EIICalculator.calculate_gps(guidance_updates)
            mvs = EIICalculator.calculate_mvs(media_mentions)
            
            # Compute EII
            eii = EIICalculator.compute_eii(ras, tas, gps, mvs)
            
            components = {
                'ras': ras,
                'tas': tas,
                'gps': gps,
                'mvs': mvs,
                'eii_100': (
                    EII_WEIGHTS['ras'] * ras +
                    EII_WEIGHTS['tas'] * tas +
                    EII_WEIGHTS['gps'] * gps +
                    EII_WEIGHTS['mvs'] * mvs
                ),
                'eii_ordinal': eii
            }
            
            return eii, components
            
        except Exception as e:
            logger.error(f"Error calculating EII: {e}")
            return 2, {}  # Default to routine

# =============================================================================
# SCI CALCULATION (Structural Change Index)
# =============================================================================

class SCICalculator:
    """
    Calculate Structural Change Index.
    
    SCI₁₀₀ = 0.40·SCS + 0.30·CLS + 0.20·IPS + 0.10·MPS
    
    Measures regime-level change through:
    - Statutory Change Score (SCS): Legislative amendments
    - Case Law Shift (CLS): Supreme Court/EAT precedents
    - Institutional Policy Shift (IPS): Government policy changes
    - Market Practice Shift (MPS): Industry norm evolution
    """
    
    @staticmethod
    def calculate_scs(statutory_changes: List[Dict]) -> float:
        """
        Calculate Statutory Change Score (0-100).
        
        Centered at 50 (neutral).
        """
        if not statutory_changes:
            return 50.0  # Neutral
        
        score = 50.0
        for change in statutory_changes:
            impact = change.get('impact', 'minor')
            
            if impact == 'transformational':
                score += 25
            elif impact == 'significant':
                score += 15
            elif impact == 'notable':
                score += 10
            elif impact == 'incremental':
                score += 5
        
        return min(100, max(0, score))
    
    @staticmethod
    def calculate_cls(case_law_shifts: List[Dict]) -> float:
        """
        Calculate Case Law Shift (0-100).
        
        Based on Supreme Court and EAT decisions.
        """
        if not case_law_shifts:
            return 50.0  # Neutral
        
        score = 50.0
        for shift in case_law_shifts:
            court = shift.get('court', 'lower')
            impact = shift.get('impact', 'minor')
            
            if court == 'supreme_court':
                score += 20 if impact == 'major' else 10
            elif court == 'eat':
                score += 15 if impact == 'major' else 7
            else:
                score += 5
        
        return min(100, max(0, score))
    
    @staticmethod
    def calculate_ips(policy_shifts: List[Dict]) -> float:
        """
        Calculate Institutional Policy Shift (0-100).
        
        Government/regulator policy changes.
        """
        if not policy_shifts:
            return 50.0  # Neutral
        
        score = 50.0
        for shift in policy_shifts:
            scope = shift.get('scope', 'minor')
            
            if scope == 'national':
                score += 15
            elif scope == 'sector':
                score += 10
            else:
                score += 5
        
        return min(100, max(0, score))
    
    @staticmethod
    def calculate_mps(market_shifts: List[Dict]) -> float:
        """
        Calculate Market Practice Shift (0-100).
        
        Industry norm evolution.
        """
        if not market_shifts:
            return 50.0  # Neutral
        
        score = 50.0
        for shift in market_shifts:
            adoption = shift.get('adoption_rate', 'low')
            
            if adoption == 'widespread':
                score += 10
            elif adoption == 'growing':
                score += 5
        
        return min(100, max(0, score))
    
    @staticmethod
    def compute_sci(
        scs: float = 50.0,
        cls: float = 50.0,
        ips: float = 50.0,
        mps: float = 50.0
    ) -> int:
        """
        Compute final SCI ordinal score (1-5).
        
        Args:
            scs: Statutory Change Score (0-100)
            cls: Case Law Shift (0-100)
            ips: Institutional Policy Shift (0-100)
            mps: Market Practice Shift (0-100)
        
        Returns:
            SCI ordinal (1-5)
        """
        sci_100 = (
            SCI_WEIGHTS['scs'] * scs +
            SCI_WEIGHTS['cls'] * cls +
            SCI_WEIGHTS['ips'] * ips +
            SCI_WEIGHTS['mps'] * mps
        )
        
        return ordinal_map(sci_100)
    
    @staticmethod
    def calculate_sci_for_category(
        category: str,
        supabase: Client,
        lookback_days: int = 90
    ) -> Tuple[int, Dict]:
        """
        Calculate complete SCI for a category with component breakdown.
        
        Returns:
            (sci_score, components_dict)
        """
        try:
            # Get structural changes (placeholder - would query real data)
            statutory_changes = []  # TODO: Query from structural_events table
            case_law_shifts = []    # TODO: Query from case_law_tracking table
            policy_shifts = []      # TODO: Query from policy_tracking table
            market_shifts = []      # TODO: Query from market_trends table
            
            # Calculate components
            scs = SCICalculator.calculate_scs(statutory_changes)
            cls = SCICalculator.calculate_cls(case_law_shifts)
            ips = SCICalculator.calculate_ips(policy_shifts)
            mps = SCICalculator.calculate_mps(market_shifts)
            
            # Compute SCI
            sci = SCICalculator.compute_sci(scs, cls, ips, mps)
            
            components = {
                'scs': scs,
                'cls': cls,
                'ips': ips,
                'mps': mps,
                'sci_100': (
                    SCI_WEIGHTS['scs'] * scs +
                    SCI_WEIGHTS['cls'] * cls +
                    SCI_WEIGHTS['ips'] * ips +
                    SCI_WEIGHTS['mps'] * mps
                ),
                'sci_ordinal': sci
            }
            
            return sci, components
            
        except Exception as e:
            logger.error(f"Error calculating SCI: {e}")
            return 1, {}  # Default to stable

# =============================================================================
# LIKELIHOOD CALCULATION (Complete Article III)
# =============================================================================

class LikelihoodCalculator:
    """
    Calculate complete Likelihood (L) score per Article III.
    
    L_raw = 0.4 × EVI + 0.3 × EII + 0.3 × SCI
    L = round(L_raw)
    
    Bounded: L ∈ {1, 2, 3, 4, 5}
    """
    
    @staticmethod
    def compute_l(evi: int, eii: int, sci: int) -> int:
        """
        Compute Likelihood score.
        
        Args:
            evi: Event Volume Index (1-5)
            eii: Enforcement Intensity Index (1-5)
            sci: Structural Change Index (1-5)
        
        Returns:
            L score (1-5)
        """
        l_raw = (
            LIKELIHOOD_WEIGHTS['evi'] * evi +
            LIKELIHOOD_WEIGHTS['eii'] * eii +
            LIKELIHOOD_WEIGHTS['sci'] * sci
        )
        
        l_rounded = round(l_raw)
        
        # Ensure bounds
        return max(1, min(5, l_rounded))
    
    @staticmethod
    def calculate_likelihood_for_category(
        category: str,
        supabase: Client
    ) -> Dict:
        """
        Calculate complete Likelihood with full breakdown.
        
        Returns:
            {
                'evi': int,
                'eii': int,
                'sci': int,
                'l': int,
                'l_raw': float,
                'components': {...}
            }
        """
        try:
            # Calculate EVI
            evi_scores = EVICalculator.calculate_all_evi(supabase)
            evi = evi_scores.get(category, 1)
            
            # Calculate EII
            eii, eii_components = EIICalculator.calculate_eii_for_category(
                category, evi, supabase
            )
            
            # Calculate SCI
            sci, sci_components = SCICalculator.calculate_sci_for_category(
                category, supabase
            )
            
            # Calculate L
            l_raw = (
                LIKELIHOOD_WEIGHTS['evi'] * evi +
                LIKELIHOOD_WEIGHTS['eii'] * eii +
                LIKELIHOOD_WEIGHTS['sci'] * sci
            )
            l = LikelihoodCalculator.compute_l(evi, eii, sci)
            
            result = {
                'category': category,
                'evi': evi,
                'eii': eii,
                'sci': sci,
                'l_raw': l_raw,
                'l': l,
                'components': {
                    'eii_detail': eii_components,
                    'sci_detail': sci_components
                },
                'weights': LIKELIHOOD_WEIGHTS,
                'calculated_at': datetime.now().isoformat()
            }
            
            logger.info(f"Calculated L for {category}: L={l} (EVI={evi}, EII={eii}, SCI={sci})")
            return result
            
        except Exception as e:
            logger.error(f"Error calculating Likelihood: {e}")
            return {
                'category': category,
                'evi': 1,
                'eii': 1,
                'sci': 1,
                'l': 1,
                'l_raw': 1.0,
                'error': str(e)
            }

# =============================================================================
# USAGE EXAMPLE
# =============================================================================

if __name__ == "__main__":
    print("""
    ACEI v6.0 - Complete Calculation Engine
    
    Likelihood (L) Calculation:
    L = 0.4 × EVI + 0.3 × EII + 0.3 × SCI
    
    Where:
    - EVI: Event Volume Index (tribunal count ratio)
    - EII: Enforcement Intensity Index (RAS + TAS + GPS + MVS)
    - SCI: Structural Change Index (SCS + CLS + IPS + MPS)
    
    Usage:
        from acei_engine import LikelihoodCalculator
        
        result = LikelihoodCalculator.calculate_likelihood_for_category(
            'whistleblowing_protected_disclosure',
            supabase_client
        )
        
        print(f"Likelihood: {result['l']}")
        print(f"  EVI: {result['evi']}")
        print(f"  EII: {result['eii']}")
        print(f"  SCI: {result['sci']}")
    
    Next: Impact (I), Multipliers (SM, JM), Velocity (v), Aggregation (DRT/DI)
    """)
