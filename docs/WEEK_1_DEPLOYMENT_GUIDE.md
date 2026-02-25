# ACEI v6.0 - Phase 1, Week 1 Deployment Guide

**Real GOV.UK Scraper + Data Integrity Layer**  
**Status:** Ready for Production Deployment  
**Date:** 25 February 2026

---

## Quick Start (15 Minutes)

### Prerequisites

```bash
# Python 3.9+
python --version

# Install dependencies
pip install supabase requests beautifulsoup4 pdfplumber python-dateutil --break-system-packages
```

### Step 1: Database Setup (5 minutes)

Apply all schema updates to your Supabase project:

**1. Data Integrity Schema:**
```sql
-- Copy contents of: data_integrity_schema.sql
-- Apply via Supabase SQL Editor
```

Creates:
- ✅ `audit_log` table (immutable)
- ✅ `decision_versions` table
- ✅ `data_quality_issues` table
- ✅ Helper views and functions
- ✅ RLS policies

**2. Unclassified Register Schema:**
```sql
-- Copy contents of: unclassified_register_schema.sql
-- Apply via Supabase SQL Editor
```

Creates:
- ✅ `unclassified_register` table
- ✅ 30-day review enforcement
- ✅ Automated alert functions

### Step 2: Environment Configuration (2 minutes)

Create `.env` file:

```bash
# Supabase
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_KEY=your-service-role-key  # Use service role for scraper

# Optional: Blob storage for raw files
# RAW_STORAGE_DIR=/path/to/storage  # Defaults to ./raw_tribunal_data
```

### Step 3: Test Scraper (3 minutes)

```bash
# Run demo scrape (5 decisions, no database)
python real_gov_uk_scraper.py

# Expected output:
# - Scrapes GOV.UK tribunal decisions
# - Parses HTML/PDF
# - Stores raw content locally
# - Shows parsed data
```

### Step 4: Production Deployment (5 minutes)

```bash
# Full scrape with database storage
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_KEY="your-service-role-key"

python real_gov_uk_scraper.py
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     GOV.UK Employment Tribunals             │
│            https://www.gov.uk/employment-tribunal-decisions │
└────────────────────────────┬────────────────────────────────┘
                             │
                             │ HTTP (Rate Limited: 1 req/2 sec)
                             ▼
┌─────────────────────────────────────────────────────────────┐
│              Real GOV.UK Scraper (real_gov_uk_scraper.py)   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  • HTML/PDF Parsing (BeautifulSoup, pdfplumber)      │   │
│  │  • Case Number Extraction                            │   │
│  │  • Parties/Judge/Date Extraction                     │   │
│  │  • SHA-256 Content Hashing                           │   │
│  │  • Raw Content Storage (audit trail)                 │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│        Duplicate Detector (duplicate_detector.py)           │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  • Check if case exists                              │   │
│  │  • Compare content hashes                            │   │
│  │  • Decision: insert / update / skip                  │   │
│  │  • Version tracking                                  │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│      Data Integrity Layer (data_integrity.py)               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  • SHA-256 Verification                              │   │
│  │  • Data Quality Checks (5 checks)                    │   │
│  │  • Audit Logging (immutable)                         │   │
│  │  • Reconciliation Reports                            │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    Supabase Database                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Tables:                                             │   │
│  │  • regulatory_updates (main decisions)               │   │
│  │  • decision_versions (full history)                  │   │
│  │  • audit_log (immutable)                             │   │
│  │  • data_quality_issues (flagged problems)            │   │
│  │  • unclassified_register (30-day review)             │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Files Delivered

### Core Modules

1. **real_gov_uk_scraper.py** (450 lines)
   - Production GOV.UK scraper
   - HTML + PDF parsing
   - Rate limiting (1 req/2 sec)
   - Error handling & retries
   - Raw content storage

2. **duplicate_detector.py** (220 lines)
   - Duplicate detection via content hash
   - Version tracking
   - Merge logic for updated decisions
   - Complete audit trail

3. **data_integrity.py** (280 lines)
   - SHA-256 content verification
   - Immutable audit logging
   - Data quality checks (5 types)
   - Daily quality reports
   - Reconciliation engine

### SQL Schemas

4. **data_integrity_schema.sql**
   - `audit_log` table (immutable)
   - `decision_versions` table
   - `data_quality_issues` table
   - Helper views and functions

5. **unclassified_register_schema.sql**
   - `unclassified_register` table
   - 30-day review enforcement
   - Automated alerts

---

## Usage Examples

### Example 1: Scrape Recent Decisions

```python
from real_gov_uk_scraper import scrape_recent_decisions

# Scrape 20 most recent decisions
decisions = scrape_recent_decisions(max_decisions=20)

# Results stored in:
# - Supabase: regulatory_updates table
# - Local: ./raw_tribunal_data/ (raw HTML/PDF)
```

### Example 2: Duplicate Detection

```python
from duplicate_detector import DuplicateDetector, process_with_duplicate_detection
from supabase import create_client

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# Check for duplicate
detector = DuplicateDetector(supabase)
dup_check = detector.check_duplicate('ET-2026-001234', 'abc123hash...')

# Result: {'is_duplicate': True/False, 'action': 'insert/update/skip', ...}

# Process with auto-detection
decision_data = {...}
action = process_with_duplicate_detection(supabase, decision_data)
# Returns: 'inserted', 'updated', or 'skipped'
```

### Example 3: Data Quality Checks

```python
from data_integrity import DataQualityChecker

checker = DataQualityChecker(supabase)

# Check single decision
decision = {...}
issues = checker.check_decision_quality(decision)

# Run daily report
report = checker.run_daily_quality_report()
# Returns: {
#   'total_records': 150,
#   'issues_found': 12,
#   'critical_issues': 2,
#   'issues_by_type': {...},
#   'recommendations': [...]
# }
```

### Example 4: Audit Trail

```python
from data_integrity import AuditLogger

audit = AuditLogger(supabase)

# Log event
audit.log_event(
    event_type='scrape',
    table_name='regulatory_updates',
    record_id='ET-2026-001234',
    user_id='scraper',
    changes={'action': 'new_scrape', 'source': 'GOV.UK'},
    reason='Automated daily scrape'
)

# Get audit trail for record
trail = audit.get_record_audit_trail('regulatory_updates', 'ET-2026-001234')
# Returns: List of AuditLogEntry objects
```

### Example 5: Version History

```python
from duplicate_detector import DuplicateDetector

detector = DuplicateDetector(supabase)

# Get full version history
history = detector.get_decision_history('ET-2026-001234')
# Returns: List of DecisionVersion objects

for version in history:
    print(f"v{version.version}: {version.changed_at} - {version.change_reason}")
```

---

## Production Deployment

### Option 1: Render Cron Job (Recommended)

```yaml
# render.yaml
services:
  - type: cron
    name: acei-tribunal-scraper
    schedule: "0 6 * * *"  # 6am GMT daily
    env: docker
    dockerfilePath: ./Dockerfile
    envVars:
      - key: SUPABASE_URL
        sync: false
      - key: SUPABASE_KEY
        sync: false
```

```dockerfile
# Dockerfile
FROM python:3.11-slim

RUN pip install supabase requests beautifulsoup4 pdfplumber python-dateutil

COPY real_gov_uk_scraper.py /app/
COPY duplicate_detector.py /app/
COPY data_integrity.py /app/

WORKDIR /app
CMD ["python", "real_gov_uk_scraper.py"]
```

### Option 2: GitHub Actions

```yaml
# .github/workflows/daily-scraper.yml
name: Daily Tribunal Scraper

on:
  schedule:
    - cron: '0 6 * * *'  # 6am GMT daily
  workflow_dispatch:  # Manual trigger

jobs:
  scrape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          pip install supabase requests beautifulsoup4 pdfplumber python-dateutil
      
      - name: Run scraper
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_KEY: ${{ secrets.SUPABASE_KEY }}
        run: |
          python real_gov_uk_scraper.py
```

### Option 3: Manual Cron (Linux Server)

```bash
# Add to crontab
crontab -e

# Add this line (6am daily):
0 6 * * * cd /path/to/acei && /usr/bin/python3 real_gov_uk_scraper.py >> logs/scraper.log 2>&1
```

---

## Monitoring & Alerts

### Daily Data Quality Report

Run daily to check data integrity:

```python
from data_integrity import DataQualityChecker

checker = DataQualityChecker(supabase)
report = checker.run_daily_quality_report()

# Email report or log to monitoring system
if report['critical_issues'] > 0:
    # Send alert
    send_alert(f"⚠️ {report['critical_issues']} critical data quality issues")
```

### Reconciliation Check

After each scrape:

```python
from data_integrity import ReconciliationEngine

reconciler = ReconciliationEngine(supabase)

# Expected IDs from scrape
scraped_ids = ['ET-2026-001234', 'ET-2026-001235', ...]

# Check all were stored
report = reconciler.reconcile_scrape_batch(scraped_ids)

if report['status'] == 'incomplete':
    # Alert on missing decisions
    logger.warning(f"Missing {len(report['missing'])} decisions: {report['missing']}")
```

---

## Testing

### Unit Tests

```python
# test_scraper.py
import unittest
from real_gov_uk_scraper import GOVUKTribunalParser

class TestGOVUKScraper(unittest.TestCase):
    def test_case_number_extraction(self):
        parser = GOVUKTribunalParser()
        case_num = parser._extract_case_number(
            'https://www.gov.uk/decisions/ET-2026-001234',
            None
        )
        self.assertEqual(case_num, 'ET-2026-001234')
    
    def test_parties_extraction(self):
        parser = GOVUKTribunalParser()
        parties = parser._extract_parties(
            'Smith v TechCorp Ltd',
            ''
        )
        self.assertEqual(parties, 'Smith v TechCorp Ltd')

if __name__ == '__main__':
    unittest.main()
```

### Integration Test

```bash
# Test full pipeline with 3 decisions
python -c "
from real_gov_uk_scraper import scrape_recent_decisions
decisions = scrape_recent_decisions(max_decisions=3)
print(f'✅ Scraped {len(decisions)} decisions')
"
```

---

## Troubleshooting

### Issue: No decisions found

**Cause:** GOV.UK structure changed  
**Solution:** Update `_is_decision_link()` method with new URL patterns

### Issue: PDF parsing fails

**Cause:** pdfplumber not installed  
**Solution:** `pip install pdfplumber --break-system-packages`

### Issue: Rate limiting errors

**Cause:** Too many requests  
**Solution:** Increase `RATE_LIMIT_DELAY` in scraper config

### Issue: Duplicate detection not working

**Cause:** Content hash mismatch  
**Solution:** Check if text is being cleaned consistently

### Issue: Supabase connection fails

**Cause:** Invalid credentials  
**Solution:** Verify SUPABASE_URL and SUPABASE_KEY in .env

---

## Performance Metrics

### Scraper Performance

- **Speed:** ~2.5 seconds per decision (rate limited)
- **Success Rate:** Target >95%
- **Duplicates:** Target <5% duplicate rate
- **Data Quality:** Target <5% issues

### Database Growth

- **Weekly:** ~500-800 new decisions
- **Storage:** ~100KB per decision (text + metadata)
- **Raw Files:** ~500KB per decision (PDF/HTML)

---

## Week 1 Deliverables Status

| Task | Status | File |
|------|--------|------|
| Real GOV.UK scraper | ✅ COMPLETE | real_gov_uk_scraper.py |
| HTML/PDF parsing | ✅ COMPLETE | (included above) |
| Rate limiting | ✅ COMPLETE | (included above) |
| Duplicate detection | ✅ COMPLETE | duplicate_detector.py |
| Version tracking | ✅ COMPLETE | (included above) |
| Data integrity layer | ✅ COMPLETE | data_integrity.py |
| SHA-256 hashing | ✅ COMPLETE | (included above) |
| Audit logging | ✅ COMPLETE | (included above) |
| Data quality checks | ✅ COMPLETE | (included above) |
| SQL schemas | ✅ COMPLETE | data_integrity_schema.sql |
| Unclassified register | ✅ COMPLETE | unclassified_register_schema.sql |

**Week 1 Status: 100% COMPLETE** ✅

---

## Next Steps (Week 2)

1. **Unclassified Monitoring Dashboard**
   - Build simple HTML/FastAPI dashboard
   - Review queue for manual classification
   - Keyword performance tracking

2. **Enhanced Categorization**
   - Add confidence scoring (0.0-1.0)
   - TF-IDF scoring for keywords
   - Low confidence flagging (<0.7)

3. **Integration with ACEI v6 scraper**
   - Connect categorization engine
   - Apply 12-category + overlap rules
   - Auto-generate alerts (EVI ≥ 4)

---

## Support

**Documentation:** See roadmap PDF  
**Issues:** Check troubleshooting section  
**Constitutional Compliance:** Article XI (Audit & Model Risk Management)

**Week 1 Complete - Ready for Week 2!** 🚀
