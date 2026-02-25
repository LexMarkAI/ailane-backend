"""
ACEI v6.0 - Real GOV.UK Employment Tribunal Scraper
Phase 1, Week 1, Priority 1A

Production-grade scraper for https://www.gov.uk/employment-tribunal-decisions
Implements: HTML parsing, PDF extraction, rate limiting, error handling, audit trail
"""

import os
import re
import time
import hashlib
import requests
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass, asdict
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
import logging
from pathlib import Path

# PDF parsing
try:
    import pdfplumber
    PDF_AVAILABLE = True
except ImportError:
    PDF_AVAILABLE = False
    logging.warning("pdfplumber not available - PDF parsing disabled")

# Supabase
from supabase import create_client, Client

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# =============================================================================
# CONFIGURATION
# =============================================================================

# GOV.UK Employment Tribunal Decisions
GOV_UK_BASE_URL = "https://www.gov.uk"
TRIBUNALS_URL = "https://www.gov.uk/employment-tribunal-decisions"

# Rate limiting (respect GOV.UK)
RATE_LIMIT_DELAY = 2.0  # seconds between requests
MAX_RETRIES = 3
RETRY_BACKOFF = 5  # seconds

# Supabase
SUPABASE_URL = os.getenv('SUPABASE_URL', '')
SUPABASE_KEY = os.getenv('SUPABASE_KEY', '')

# Storage for raw content (audit trail)
RAW_STORAGE_DIR = Path('/home/claude/raw_tribunal_data')
RAW_STORAGE_DIR.mkdir(exist_ok=True)

# Initialize Supabase
if SUPABASE_URL and SUPABASE_KEY:
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
else:
    logger.warning("Supabase credentials not found - database storage disabled")
    supabase = None

# =============================================================================
# DATA CLASSES
# =============================================================================

@dataclass
class TribunalDecision:
    """Represents a parsed tribunal decision"""
    source_identifier: str  # Case number (e.g., ET-2026-001234)
    title: str
    url: str
    published_date: Optional[datetime]
    parties: Optional[str]
    judge: Optional[str]
    decision_text: str
    content_hash: str  # SHA-256 hash for integrity
    scraped_at: datetime
    raw_content_path: Optional[str]  # Path to stored raw HTML/PDF
    
# =============================================================================
# HTTP SESSION WITH RATE LIMITING
# =============================================================================

class RateLimitedSession:
    """HTTP session with rate limiting and retry logic"""
    
    def __init__(self, delay: float = RATE_LIMIT_DELAY):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'ACEI-Scraper/1.0 (Research; ailane.co.uk)'
        })
        self.delay = delay
        self.last_request_time = 0
    
    def get(self, url: str, **kwargs) -> requests.Response:
        """GET request with rate limiting and retries"""
        # Rate limiting
        elapsed = time.time() - self.last_request_time
        if elapsed < self.delay:
            time.sleep(self.delay - elapsed)
        
        # Retry logic
        for attempt in range(MAX_RETRIES):
            try:
                self.last_request_time = time.time()
                response = self.session.get(url, timeout=30, **kwargs)
                response.raise_for_status()
                return response
                
            except requests.exceptions.RequestException as e:
                logger.warning(f"Request failed (attempt {attempt + 1}/{MAX_RETRIES}): {e}")
                if attempt < MAX_RETRIES - 1:
                    time.sleep(RETRY_BACKOFF * (attempt + 1))
                else:
                    raise
        
        raise requests.exceptions.RequestException(f"Failed after {MAX_RETRIES} attempts")

# =============================================================================
# HTML PARSING
# =============================================================================

class GOVUKTribunalParser:
    """Parser for GOV.UK Employment Tribunal Decisions pages"""
    
    def __init__(self):
        self.session = RateLimitedSession()
    
    def parse_decisions_index(self, url: str = TRIBUNALS_URL) -> List[Dict[str, str]]:
        """
        Parse the main decisions index page to get links to individual decisions.
        
        Returns:
            List of dicts with 'url', 'title', 'date' (if available)
        """
        logger.info(f"Parsing index page: {url}")
        
        try:
            response = self.session.get(url)
            soup = BeautifulSoup(response.content, 'html.parser')
            
            decisions = []
            
            # GOV.UK structure: Look for decision links
            # The actual structure may vary - this is a generic approach
            
            # Method 1: Look for links in article/main content area
            content_area = soup.find('main') or soup.find('article') or soup.find('div', class_='govuk-main-wrapper')
            
            if content_area:
                # Find all links that look like tribunal decisions
                links = content_area.find_all('a', href=True)
                
                for link in links:
                    href = link['href']
                    title = link.get_text(strip=True)
                    
                    # Filter for tribunal decision links
                    # Typically contain case numbers or decision identifiers
                    if self._is_decision_link(href, title):
                        full_url = urljoin(GOV_UK_BASE_URL, href)
                        
                        decisions.append({
                            'url': full_url,
                            'title': title,
                            'date': self._extract_date_from_title(title)
                        })
            
            logger.info(f"Found {len(decisions)} decision links")
            return decisions
            
        except Exception as e:
            logger.error(f"Error parsing index page: {e}")
            return []
    
    def _is_decision_link(self, href: str, title: str) -> bool:
        """Check if link looks like a tribunal decision"""
        # Common patterns:
        # - Contains 'ET/' or case numbers
        # - Links to .pdf files
        # - Contains year patterns (2024, 2025, 2026)
        # - Contains 'v' or 'vs' (parties)
        
        decision_patterns = [
            r'ET[-/]\d+',  # Case numbers like ET-2026-001234
            r'\d{4}[-/]\d+',  # Year-based references
            r'\sv\s',  # Parties (Smith v Company)
            r'\.pdf$',  # PDF files
        ]
        
        combined_text = f"{href} {title}".lower()
        
        return any(re.search(pattern, combined_text, re.IGNORECASE) for pattern in decision_patterns)
    
    def _extract_date_from_title(self, title: str) -> Optional[str]:
        """Try to extract date from title"""
        # Look for date patterns like "25 February 2026" or "2026-02-25"
        date_patterns = [
            r'\d{1,2}\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}',
            r'\d{4}-\d{2}-\d{2}'
        ]
        
        for pattern in date_patterns:
            match = re.search(pattern, title, re.IGNORECASE)
            if match:
                return match.group()
        
        return None
    
    def parse_decision_page(self, url: str) -> Optional[TribunalDecision]:
        """
        Parse individual tribunal decision page.
        Handles both HTML pages and PDF links.
        """
        logger.info(f"Parsing decision: {url}")
        
        try:
            # Check if this is a PDF link
            if url.lower().endswith('.pdf'):
                return self._parse_pdf_decision(url)
            else:
                return self._parse_html_decision(url)
                
        except Exception as e:
            logger.error(f"Error parsing decision {url}: {e}")
            return None
    
    def _parse_html_decision(self, url: str) -> Optional[TribunalDecision]:
        """Parse HTML tribunal decision page"""
        try:
            response = self.session.get(url)
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Extract case number from URL or title
            source_identifier = self._extract_case_number(url, soup)
            
            # Extract title
            title_tag = soup.find('h1') or soup.find('title')
            title = title_tag.get_text(strip=True) if title_tag else "Unknown Title"
            
            # Extract main content
            # GOV.UK typically uses specific content classes
            content_area = (
                soup.find('div', class_='govuk-body') or
                soup.find('main') or
                soup.find('article') or
                soup.body
            )
            
            decision_text = content_area.get_text(separator='\n', strip=True) if content_area else ""
            
            # Try to extract structured fields
            parties = self._extract_parties(title, decision_text)
            judge = self._extract_judge(decision_text)
            published_date = self._extract_published_date(soup)
            
            # Store raw HTML for audit trail
            content_hash = hashlib.sha256(response.content).hexdigest()
            raw_path = self._store_raw_content(source_identifier, response.content, 'html')
            
            return TribunalDecision(
                source_identifier=source_identifier,
                title=title,
                url=url,
                published_date=published_date,
                parties=parties,
                judge=judge,
                decision_text=decision_text,
                content_hash=content_hash,
                scraped_at=datetime.now(),
                raw_content_path=raw_path
            )
            
        except Exception as e:
            logger.error(f"Error parsing HTML decision {url}: {e}")
            return None
    
    def _parse_pdf_decision(self, url: str) -> Optional[TribunalDecision]:
        """Parse PDF tribunal decision"""
        if not PDF_AVAILABLE:
            logger.warning(f"Cannot parse PDF {url} - pdfplumber not installed")
            return None
        
        try:
            response = self.session.get(url)
            
            # Extract case number from URL
            source_identifier = self._extract_case_number(url, None)
            
            # Store raw PDF
            content_hash = hashlib.sha256(response.content).hexdigest()
            raw_path = self._store_raw_content(source_identifier, response.content, 'pdf')
            
            # Extract text from PDF
            import io
            with pdfplumber.open(io.BytesIO(response.content)) as pdf:
                # Extract text from all pages
                decision_text = ""
                for page in pdf.pages:
                    decision_text += page.extract_text() or ""
                
                # Clean up text
                decision_text = self._clean_pdf_text(decision_text)
            
            # Extract structured fields
            title = self._extract_title_from_text(decision_text)
            parties = self._extract_parties(title, decision_text)
            judge = self._extract_judge(decision_text)
            published_date = self._extract_date_from_text(decision_text)
            
            return TribunalDecision(
                source_identifier=source_identifier,
                title=title or f"Decision {source_identifier}",
                url=url,
                published_date=published_date,
                parties=parties,
                judge=judge,
                decision_text=decision_text,
                content_hash=content_hash,
                scraped_at=datetime.now(),
                raw_content_path=raw_path
            )
            
        except Exception as e:
            logger.error(f"Error parsing PDF decision {url}: {e}")
            return None
    
    def _extract_case_number(self, url: str, soup: Optional[BeautifulSoup]) -> str:
        """Extract case number from URL or page content"""
        # Try URL first
        url_match = re.search(r'ET[-/]?\d{4}[-/]?\d+', url, re.IGNORECASE)
        if url_match:
            return url_match.group().replace('/', '-')
        
        # Try to extract from soup if available
        if soup:
            text = soup.get_text()
            text_match = re.search(r'Case\s+No[.:]\s*(ET[-/]?\d{4}[-/]?\d+)', text, re.IGNORECASE)
            if text_match:
                return text_match.group(1).replace('/', '-')
        
        # Generate from URL hash if nothing found
        url_hash = hashlib.md5(url.encode()).hexdigest()[:8]
        return f"ET-UNKNOWN-{url_hash}"
    
    def _extract_parties(self, title: str, text: str) -> Optional[str]:
        """Extract party names (Claimant v Respondent)"""
        # Look for "X v Y" or "X vs Y" pattern
        match = re.search(r'([A-Z][a-zA-Z\s&]+)\s+v\.?\s+([A-Z][a-zA-Z\s&.,()]+)', title or text)
        if match:
            return f"{match.group(1).strip()} v {match.group(2).strip()}"
        return None
    
    def _extract_judge(self, text: str) -> Optional[str]:
        """Extract judge name"""
        patterns = [
            r'Employment\s+Judge[:\s]+([A-Z][a-zA-Z\s]+)',
            r'Judge[:\s]+([A-Z][a-zA-Z\s]+)',
            r'Before[:\s]+Employment\s+Judge\s+([A-Z][a-zA-Z\s]+)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(1).strip()
        
        return None
    
    def _extract_published_date(self, soup: BeautifulSoup) -> Optional[datetime]:
        """Extract publication date from HTML"""
        # Look for time tags or date metadata
        time_tag = soup.find('time', attrs={'datetime': True})
        if time_tag:
            try:
                return datetime.fromisoformat(time_tag['datetime'].replace('Z', '+00:00'))
            except:
                pass
        
        return None
    
    def _extract_date_from_text(self, text: str) -> Optional[datetime]:
        """Extract date from text content"""
        # Look for date at start of document
        match = re.search(r'\d{1,2}\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}', text[:500])
        if match:
            try:
                from dateutil import parser
                return parser.parse(match.group())
            except:
                pass
        
        return None
    
    def _extract_title_from_text(self, text: str) -> Optional[str]:
        """Extract title from PDF text (usually first line or first significant text)"""
        lines = text.split('\n')
        for line in lines[:10]:  # Check first 10 lines
            line = line.strip()
            if len(line) > 10 and 'v' in line.lower():  # Likely title if contains 'v' for versus
                return line
        return None
    
    def _clean_pdf_text(self, text: str) -> str:
        """Clean extracted PDF text"""
        # Remove page numbers
        text = re.sub(r'\n\s*\d+\s*\n', '\n', text)
        
        # Remove excessive whitespace
        text = re.sub(r'\n{3,}', '\n\n', text)
        text = re.sub(r' {2,}', ' ', text)
        
        # Remove headers/footers (common patterns)
        text = re.sub(r'EMPLOYMENT TRIBUNALS?\n', '', text, flags=re.IGNORECASE)
        
        return text.strip()
    
    def _store_raw_content(self, case_id: str, content: bytes, file_type: str) -> str:
        """Store raw HTML/PDF content for audit trail"""
        try:
            safe_id = re.sub(r'[^a-zA-Z0-9-]', '_', case_id)
            filename = f"{safe_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.{file_type}"
            filepath = RAW_STORAGE_DIR / filename
            
            with open(filepath, 'wb') as f:
                f.write(content)
            
            logger.info(f"Stored raw content: {filepath}")
            return str(filepath)
            
        except Exception as e:
            logger.error(f"Error storing raw content: {e}")
            return None

# =============================================================================
# SUPABASE STORAGE
# =============================================================================

def store_decision_in_supabase(decision: TribunalDecision) -> bool:
    """Store parsed decision in Supabase"""
    if not supabase:
        logger.warning("Supabase not configured - skipping database storage")
        return False
    
    try:
        data = {
            "source_type": "employment_tribunal",
            "source_identifier": decision.source_identifier,
            "title": decision.title,
            "summary": decision.parties or "",
            "full_text": decision.decision_text,
            "url": decision.url,
            "published_date": decision.published_date.isoformat() if decision.published_date else None,
            "metadata": {
                "parties": decision.parties,
                "judge": decision.judge,
                "content_hash": decision.content_hash,
                "raw_content_path": decision.raw_content_path,
                "scraped_at": decision.scraped_at.isoformat()
            },
            "status": "scraped_pending_categorization"
        }
        
        result = supabase.table('regulatory_updates').insert(data).execute()
        logger.info(f"✅ Stored in Supabase: {decision.source_identifier}")
        return True
        
    except Exception as e:
        logger.error(f"❌ Error storing in Supabase: {e}")
        return False

# =============================================================================
# MAIN SCRAPER
# =============================================================================

def scrape_recent_decisions(max_decisions: int = 20) -> List[TribunalDecision]:
    """
    Scrape recent employment tribunal decisions from GOV.UK.
    
    Args:
        max_decisions: Maximum number of decisions to scrape
    
    Returns:
        List of parsed TribunalDecision objects
    """
    logger.info("="*80)
    logger.info("ACEI v6.0 - Real GOV.UK Tribunal Scraper")
    logger.info("="*80)
    
    parser = GOVUKTribunalParser()
    decisions = []
    
    # Step 1: Get decision links from index page
    logger.info("Step 1: Fetching decision links from index...")
    decision_links = parser.parse_decisions_index()
    
    if not decision_links:
        logger.warning("No decision links found - GOV.UK structure may have changed")
        return []
    
    logger.info(f"Found {len(decision_links)} decision links")
    
    # Step 2: Parse individual decisions (up to max_decisions)
    logger.info(f"Step 2: Parsing up to {max_decisions} decisions...")
    
    for i, link_info in enumerate(decision_links[:max_decisions], 1):
        logger.info(f"  [{i}/{min(len(decision_links), max_decisions)}] {link_info['title'][:60]}...")
        
        decision = parser.parse_decision_page(link_info['url'])
        
        if decision:
            decisions.append(decision)
            
            # Store in Supabase
            store_decision_in_supabase(decision)
        
        # Rate limiting between decisions
        time.sleep(RATE_LIMIT_DELAY)
    
    # Summary
    logger.info("="*80)
    logger.info(f"Scraping Complete")
    logger.info(f"  Total scraped: {len(decisions)}")
    logger.info(f"  Stored in database: {len(decisions)}")
    logger.info(f"  Raw files saved: {RAW_STORAGE_DIR}")
    logger.info("="*80)
    
    return decisions

# =============================================================================
# TESTING / DEMO
# =============================================================================

if __name__ == "__main__":
    # For testing without Supabase, set to demo mode
    if not SUPABASE_URL:
        logger.info("Running in DEMO mode (no Supabase connection)")
        logger.info("Set SUPABASE_URL and SUPABASE_KEY environment variables for production")
    
    # Scrape recent decisions
    decisions = scrape_recent_decisions(max_decisions=5)
    
    # Print summary
    if decisions:
        print("\n" + "="*80)
        print("SCRAPED DECISIONS SUMMARY")
        print("="*80)
        for i, decision in enumerate(decisions, 1):
            print(f"\n{i}. {decision.source_identifier}")
            print(f"   Title: {decision.title[:80]}")
            print(f"   URL: {decision.url}")
            print(f"   Parties: {decision.parties or 'N/A'}")
            print(f"   Judge: {decision.judge or 'N/A'}")
            print(f"   Text length: {len(decision.decision_text)} chars")
            print(f"   Hash: {decision.content_hash[:16]}...")
