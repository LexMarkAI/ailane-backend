"""
ACEI v6.0 - Data Integrity & Audit Layer
Phase 1, Week 1, Priority 1C

Implements Article XI requirements:
- Content hash verification (SHA-256)
- Immutable audit log
- Data lineage tracking
- Data quality checks
- Reconciliation reports
"""

import hashlib
import json
from datetime import datetime
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from supabase import Client
import logging

logger = logging.getLogger(__name__)

# =============================================================================
# DATA CLASSES
# =============================================================================

@dataclass
class AuditLogEntry:
    """Immutable audit log entry"""
    id: str
    event_type: str  # 'insert', 'update', 'delete', 'scrape', 'categorization'
    table_name: str
    record_id: str
    user_id: str
    timestamp: datetime
    changes: Dict
    reason: str
    ip_address: Optional[str] = None
    
@dataclass
class DataQualityIssue:
    """Data quality check failure"""
    record_id: str
    field_name: str
    issue_type: str  # 'missing', 'invalid', 'malformed', 'suspicious'
    severity: str  # 'critical', 'warning', 'info'
    description: str
    detected_at: datetime

# =============================================================================
# DATA INTEGRITY VALIDATOR
# =============================================================================

class DataIntegrityValidator:
    """Validates data integrity using content hashing and checksums"""
    
    @staticmethod
    def compute_content_hash(content: str or bytes) -> str:
        """
        Compute SHA-256 hash of content.
        
        Args:
            content: String or bytes to hash
            
        Returns:
            Hex digest of SHA-256 hash
        """
        if isinstance(content, str):
            content = content.encode('utf-8')
        
        return hashlib.sha256(content).hexdigest()
    
    @staticmethod
    def verify_content_hash(content: str or bytes, expected_hash: str) -> bool:
        """
        Verify content matches expected hash.
        
        Returns:
            True if hash matches, False otherwise
        """
        actual_hash = DataIntegrityValidator.compute_content_hash(content)
        return actual_hash == expected_hash
    
    @staticmethod
    def compute_record_fingerprint(record: Dict) -> str:
        """
        Compute fingerprint of database record (excluding timestamps).
        
        Useful for detecting unauthorized modifications.
        """
        # Create stable representation
        stable_record = {
            k: v for k, v in sorted(record.items())
            if k not in ['created_at', 'updated_at', 'id']
        }
        
        # Convert to JSON with sorted keys
        json_str = json.dumps(stable_record, sort_keys=True, default=str)
        
        return DataIntegrityValidator.compute_content_hash(json_str)

# =============================================================================
# AUDIT LOGGER
# =============================================================================

class AuditLogger:
    """Immutable audit logging system"""
    
    def __init__(self, supabase: Client):
        self.supabase = supabase
    
    def log_event(
        self,
        event_type: str,
        table_name: str,
        record_id: str,
        user_id: str,
        changes: Dict,
        reason: str,
        ip_address: Optional[str] = None
    ) -> Optional[str]:
        """
        Create immutable audit log entry.
        
        Returns:
            Audit log entry ID or None if failed
        """
        try:
            data = {
                "event_type": event_type,
                "table_name": table_name,
                "record_id": record_id,
                "user_id": user_id,
                "timestamp": datetime.now().isoformat(),
                "changes": changes,
                "reason": reason,
                "ip_address": ip_address
            }
            
            result = self.supabase.table('audit_log').insert(data).execute()
            
            if result.data:
                audit_id = result.data[0]['id']
                logger.info(f"📝 Audit log created: {event_type} on {table_name}/{record_id}")
                return audit_id
            
            return None
            
        except Exception as e:
            logger.error(f"❌ Error creating audit log: {e}")
            return None
    
    def get_record_audit_trail(self, table_name: str, record_id: str) -> List[AuditLogEntry]:
        """Get complete audit trail for a specific record"""
        try:
            result = self.supabase.table('audit_log')\
                .select('*')\
                .eq('table_name', table_name)\
                .eq('record_id', record_id)\
                .order('timestamp', desc=False)\
                .execute()
            
            entries = []
            for record in result.data:
                entries.append(AuditLogEntry(
                    id=record['id'],
                    event_type=record['event_type'],
                    table_name=record['table_name'],
                    record_id=record['record_id'],
                    user_id=record['user_id'],
                    timestamp=datetime.fromisoformat(record['timestamp']),
                    changes=record['changes'],
                    reason=record['reason'],
                    ip_address=record.get('ip_address')
                ))
            
            return entries
            
        except Exception as e:
            logger.error(f"Error getting audit trail: {e}")
            return []
    
    def get_recent_events(self, limit: int = 100, event_type: Optional[str] = None) -> List[Dict]:
        """Get recent audit events"""
        try:
            query = self.supabase.table('audit_log')\
                .select('*')\
                .order('timestamp', desc=True)\
                .limit(limit)
            
            if event_type:
                query = query.eq('event_type', event_type)
            
            result = query.execute()
            return result.data
            
        except Exception as e:
            logger.error(f"Error getting recent events: {e}")
            return []

# =============================================================================
# DATA QUALITY CHECKER
# =============================================================================

class DataQualityChecker:
    """Validates data quality and completeness"""
    
    def __init__(self, supabase: Client):
        self.supabase = supabase
    
    def check_decision_quality(self, decision: Dict) -> List[DataQualityIssue]:
        """
        Run quality checks on tribunal decision.
        
        Checks:
        - Required fields present
        - Field formats valid
        - Content not suspiciously short
        - Date validity
        - Hash integrity
        """
        issues = []
        record_id = decision.get('id', 'unknown')
        
        # Check 1: Required fields
        required_fields = ['source_identifier', 'title', 'full_text', 'url']
        for field in required_fields:
            if not decision.get(field):
                issues.append(DataQualityIssue(
                    record_id=record_id,
                    field_name=field,
                    issue_type='missing',
                    severity='critical',
                    description=f"Required field '{field}' is missing or empty",
                    detected_at=datetime.now()
                ))
        
        # Check 2: Content length
        full_text = decision.get('full_text', '')
        if len(full_text) < 100:
            issues.append(DataQualityIssue(
                record_id=record_id,
                field_name='full_text',
                issue_type='suspicious',
                severity='warning',
                description=f"Decision text suspiciously short ({len(full_text)} chars)",
                detected_at=datetime.now()
            ))
        
        # Check 3: URL format
        url = decision.get('url', '')
        if url and not url.startswith(('http://', 'https://')):
            issues.append(DataQualityIssue(
                record_id=record_id,
                field_name='url',
                issue_type='invalid',
                severity='warning',
                description=f"URL format invalid: {url}",
                detected_at=datetime.now()
            ))
        
        # Check 4: Date validity
        pub_date = decision.get('published_date')
        if pub_date:
            try:
                date_obj = datetime.fromisoformat(pub_date.replace('Z', '+00:00'))
                # Check not in future
                if date_obj > datetime.now():
                    issues.append(DataQualityIssue(
                        record_id=record_id,
                        field_name='published_date',
                        issue_type='invalid',
                        severity='warning',
                        description=f"Published date in future: {pub_date}",
                        detected_at=datetime.now()
                    ))
            except ValueError:
                issues.append(DataQualityIssue(
                    record_id=record_id,
                    field_name='published_date',
                    issue_type='malformed',
                    severity='warning',
                    description=f"Date format invalid: {pub_date}",
                    detected_at=datetime.now()
                ))
        
        # Check 5: Hash integrity (if provided)
        metadata = decision.get('metadata', {})
        if 'content_hash' in metadata and full_text:
            expected_hash = metadata['content_hash']
            actual_hash = DataIntegrityValidator.compute_content_hash(full_text)
            if actual_hash != expected_hash:
                issues.append(DataQualityIssue(
                    record_id=record_id,
                    field_name='content_hash',
                    issue_type='invalid',
                    severity='critical',
                    description="Content hash mismatch - possible tampering",
                    detected_at=datetime.now()
                ))
        
        return issues
    
    def run_daily_quality_report(self) -> Dict:
        """
        Generate daily data quality report.
        
        Returns:
            {
                'total_records': int,
                'issues_found': int,
                'critical_issues': int,
                'issues_by_type': Dict,
                'recommendations': List[str]
            }
        """
        try:
            # Get recent decisions (last 7 days)
            seven_days_ago = (datetime.now() - timedelta(days=7)).isoformat()
            
            result = self.supabase.table('regulatory_updates')\
                .select('*')\
                .gte('created_at', seven_days_ago)\
                .eq('source_type', 'employment_tribunal')\
                .execute()
            
            total_records = len(result.data)
            all_issues = []
            
            for record in result.data:
                issues = self.check_decision_quality(record)
                all_issues.extend(issues)
            
            # Analyze issues
            critical_count = sum(1 for issue in all_issues if issue.severity == 'critical')
            
            issues_by_type = {}
            for issue in all_issues:
                issue_type = issue.issue_type
                issues_by_type[issue_type] = issues_by_type.get(issue_type, 0) + 1
            
            # Generate recommendations
            recommendations = []
            if critical_count > 0:
                recommendations.append(f"⚠️  {critical_count} critical issues require immediate attention")
            
            if issues_by_type.get('missing', 0) > total_records * 0.1:
                recommendations.append("High rate of missing required fields - check scraper")
            
            if issues_by_type.get('suspicious', 0) > total_records * 0.05:
                recommendations.append("Many suspiciously short decisions - verify scraping logic")
            
            report = {
                'report_date': datetime.now().isoformat(),
                'total_records': total_records,
                'issues_found': len(all_issues),
                'critical_issues': critical_count,
                'issues_by_type': issues_by_type,
                'recommendations': recommendations,
                'details': [asdict(issue) for issue in all_issues[:50]]  # Top 50
            }
            
            logger.info(f"📊 Quality report: {len(all_issues)} issues in {total_records} records")
            return report
            
        except Exception as e:
            logger.error(f"Error generating quality report: {e}")
            return {}

# =============================================================================
# RECONCILIATION
# =============================================================================

class ReconciliationEngine:
    """Reconciles data between source and database"""
    
    def __init__(self, supabase: Client):
        self.supabase = supabase
    
    def reconcile_scrape_batch(self, scraped_ids: List[str]) -> Dict:
        """
        Reconcile a batch of scraped decisions against database.
        
        Returns:
            {
                'expected': int,
                'found': int,
                'missing': List[str],
                'status': 'complete' | 'incomplete'
            }
        """
        try:
            result = self.supabase.table('regulatory_updates')\
                .select('source_identifier')\
                .in_('source_identifier', scraped_ids)\
                .execute()
            
            found_ids = [r['source_identifier'] for r in result.data]
            missing_ids = [sid for sid in scraped_ids if sid not in found_ids]
            
            status = 'complete' if len(missing_ids) == 0 else 'incomplete'
            
            report = {
                'expected': len(scraped_ids),
                'found': len(found_ids),
                'missing': missing_ids,
                'status': status
            }
            
            if missing_ids:
                logger.warning(f"⚠️  Reconciliation incomplete: {len(missing_ids)} missing")
            else:
                logger.info(f"✅ Reconciliation complete: all {len(scraped_ids)} found")
            
            return report
            
        except Exception as e:
            logger.error(f"Error in reconciliation: {e}")
            return {'status': 'error', 'expected': len(scraped_ids), 'found': 0, 'missing': scraped_ids}

# =============================================================================
# USAGE EXAMPLE
# =============================================================================

if __name__ == "__main__":
    print("""
    Data Integrity & Audit Layer
    
    Features:
    - SHA-256 content hashing
    - Immutable audit logging
    - Data quality checks
    - Reconciliation reporting
    
    Usage:
        from data_integrity import DataIntegrityValidator, AuditLogger, DataQualityChecker
        
        # Compute hash
        hash = DataIntegrityValidator.compute_content_hash(decision_text)
        
        # Verify hash
        is_valid = DataIntegrityValidator.verify_content_hash(content, expected_hash)
        
        # Log audit event
        audit = AuditLogger(supabase_client)
        audit.log_event('insert', 'regulatory_updates', record_id, 'scraper', {...}, 'New scrape')
        
        # Check data quality
        checker = DataQualityChecker(supabase_client)
        issues = checker.check_decision_quality(decision)
        
        # Daily quality report
        report = checker.run_daily_quality_report()
    """)
