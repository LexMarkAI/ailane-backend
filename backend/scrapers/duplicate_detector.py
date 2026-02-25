"""
ACEI v6.0 - Duplicate Detection & Version Tracking
Phase 1, Week 1, Priority 1B

Handles:
- Case number deduplication
- Decision updates (same case, new ruling)
- Content hash verification
- Version tracking with audit trail
"""

import hashlib
from datetime import datetime
from typing import Optional, Dict, List
from dataclasses import dataclass
from supabase import Client
import logging

logger = logging.getLogger(__name__)

# =============================================================================
# DATA CLASSES
# =============================================================================

@dataclass
class DecisionVersion:
    """Represents a version of a tribunal decision"""
    id: str
    source_identifier: str
    version: int
    content_hash: str
    changed_at: datetime
    changed_by: str
    change_reason: str
    previous_version_id: Optional[str]

# =============================================================================
# DUPLICATE DETECTOR
# =============================================================================

class DuplicateDetector:
    """Detects and handles duplicate tribunal decisions"""
    
    def __init__(self, supabase: Client):
        self.supabase = supabase
    
    def check_duplicate(self, source_identifier: str, content_hash: str) -> Dict:
        """
        Check if decision already exists in database.
        
        Returns:
            {
                'is_duplicate': bool,
                'action': 'insert' | 'update' | 'skip',
                'existing_id': str | None,
                'existing_hash': str | None,
                'version': int
            }
        """
        try:
            # Query for existing decision
            result = self.supabase.table('regulatory_updates')\
                .select('id, metadata')\
                .eq('source_identifier', source_identifier)\
                .eq('source_type', 'employment_tribunal')\
                .execute()
            
            if not result.data:
                # No existing decision - insert new
                return {
                    'is_duplicate': False,
                    'action': 'insert',
                    'existing_id': None,
                    'existing_hash': None,
                    'version': 1
                }
            
            # Found existing decision
            existing = result.data[0]
            existing_id = existing['id']
            existing_hash = existing.get('metadata', {}).get('content_hash', '')
            
            if existing_hash == content_hash:
                # Exact duplicate - skip
                logger.info(f"Exact duplicate found: {source_identifier}")
                return {
                    'is_duplicate': True,
                    'action': 'skip',
                    'existing_id': existing_id,
                    'existing_hash': existing_hash,
                    'version': self._get_latest_version(source_identifier)
                }
            else:
                # Content changed - update
                logger.info(f"Updated decision found: {source_identifier}")
                return {
                    'is_duplicate': True,
                    'action': 'update',
                    'existing_id': existing_id,
                    'existing_hash': existing_hash,
                    'version': self._get_latest_version(source_identifier) + 1
                }
                
        except Exception as e:
            logger.error(f"Error checking duplicate: {e}")
            return {
                'is_duplicate': False,
                'action': 'insert',
                'existing_id': None,
                'existing_hash': None,
                'version': 1
            }
    
    def _get_latest_version(self, source_identifier: str) -> int:
        """Get latest version number for a decision"""
        try:
            result = self.supabase.table('decision_versions')\
                .select('version')\
                .eq('source_identifier', source_identifier)\
                .order('version', desc=True)\
                .limit(1)\
                .execute()
            
            if result.data:
                return result.data[0]['version']
            return 0
            
        except Exception as e:
            logger.error(f"Error getting latest version: {e}")
            return 0
    
    def create_version_record(
        self,
        source_identifier: str,
        version: int,
        content_hash: str,
        changed_by: str = 'scraper',
        change_reason: str = 'New scrape',
        previous_version_id: Optional[str] = None
    ) -> Optional[str]:
        """Create version tracking record"""
        try:
            data = {
                "source_identifier": source_identifier,
                "version": version,
                "content_hash": content_hash,
                "changed_at": datetime.now().isoformat(),
                "changed_by": changed_by,
                "change_reason": change_reason,
                "previous_version_id": previous_version_id
            }
            
            result = self.supabase.table('decision_versions').insert(data).execute()
            
            if result.data:
                version_id = result.data[0]['id']
                logger.info(f"Created version record: {source_identifier} v{version}")
                return version_id
            
            return None
            
        except Exception as e:
            logger.error(f"Error creating version record: {e}")
            return None
    
    def merge_duplicate(
        self,
        existing_id: str,
        new_data: Dict,
        content_hash: str,
        version: int
    ) -> bool:
        """
        Update existing decision with new data.
        Creates version record before updating.
        """
        try:
            # Get existing data for version record
            existing = self.supabase.table('regulatory_updates')\
                .select('*')\
                .eq('id', existing_id)\
                .execute()
            
            if not existing.data:
                logger.error(f"Cannot merge - existing record not found: {existing_id}")
                return False
            
            existing_data = existing.data[0]
            
            # Create version record for old version
            old_version_id = self.create_version_record(
                source_identifier=new_data['source_identifier'],
                version=version - 1,
                content_hash=existing_data.get('metadata', {}).get('content_hash', ''),
                changed_by='scraper',
                change_reason='Superseded by new version'
            )
            
            # Update with new data
            update_data = {
                **new_data,
                'metadata': {
                    **new_data.get('metadata', {}),
                    'updated_at': datetime.now().isoformat(),
                    'version': version,
                    'previous_version_id': old_version_id
                }
            }
            
            result = self.supabase.table('regulatory_updates')\
                .update(update_data)\
                .eq('id', existing_id)\
                .execute()
            
            # Create version record for new version
            self.create_version_record(
                source_identifier=new_data['source_identifier'],
                version=version,
                content_hash=content_hash,
                changed_by='scraper',
                change_reason='Updated from new scrape',
                previous_version_id=old_version_id
            )
            
            logger.info(f"✅ Merged duplicate: {new_data['source_identifier']} (v{version})")
            return True
            
        except Exception as e:
            logger.error(f"❌ Error merging duplicate: {e}")
            return False
    
    def get_decision_history(self, source_identifier: str) -> List[DecisionVersion]:
        """Get full version history for a decision"""
        try:
            result = self.supabase.table('decision_versions')\
                .select('*')\
                .eq('source_identifier', source_identifier)\
                .order('version', desc=False)\
                .execute()
            
            versions = []
            for record in result.data:
                versions.append(DecisionVersion(
                    id=record['id'],
                    source_identifier=record['source_identifier'],
                    version=record['version'],
                    content_hash=record['content_hash'],
                    changed_at=datetime.fromisoformat(record['changed_at']),
                    changed_by=record['changed_by'],
                    change_reason=record['change_reason'],
                    previous_version_id=record.get('previous_version_id')
                ))
            
            return versions
            
        except Exception as e:
            logger.error(f"Error getting decision history: {e}")
            return []

# =============================================================================
# USAGE EXAMPLE
# =============================================================================

def process_with_duplicate_detection(supabase: Client, decision_data: Dict) -> str:
    """
    Process a scraped decision with duplicate detection.
    
    Returns:
        'inserted' | 'updated' | 'skipped'
    """
    detector = DuplicateDetector(supabase)
    
    source_identifier = decision_data['source_identifier']
    content_hash = decision_data['metadata']['content_hash']
    
    # Check for duplicates
    dup_check = detector.check_duplicate(source_identifier, content_hash)
    
    if dup_check['action'] == 'skip':
        logger.info(f"⏭️  Skipping exact duplicate: {source_identifier}")
        return 'skipped'
    
    elif dup_check['action'] == 'update':
        logger.info(f"🔄 Updating existing decision: {source_identifier}")
        success = detector.merge_duplicate(
            existing_id=dup_check['existing_id'],
            new_data=decision_data,
            content_hash=content_hash,
            version=dup_check['version']
        )
        return 'updated' if success else 'error'
    
    else:  # 'insert'
        logger.info(f"✅ Inserting new decision: {source_identifier}")
        try:
            result = supabase.table('regulatory_updates').insert(decision_data).execute()
            
            # Create initial version record
            if result.data:
                detector.create_version_record(
                    source_identifier=source_identifier,
                    version=1,
                    content_hash=content_hash,
                    changed_by='scraper',
                    change_reason='Initial scrape'
                )
            
            return 'inserted'
            
        except Exception as e:
            logger.error(f"Error inserting decision: {e}")
            return 'error'

if __name__ == "__main__":
    # Demo usage
    print("""
    Duplicate Detection & Version Tracking Module
    
    Usage:
        from duplicate_detector import DuplicateDetector, process_with_duplicate_detection
        
        # Initialize
        detector = DuplicateDetector(supabase_client)
        
        # Check for duplicate
        dup_check = detector.check_duplicate('ET-2026-001234', 'abc123...')
        
        # Process with auto-detection
        action = process_with_duplicate_detection(supabase_client, decision_data)
        
        # Get version history
        history = detector.get_decision_history('ET-2026-001234')
    """)
