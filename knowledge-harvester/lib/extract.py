"""Extract findings from harvested sources."""

import uuid
from datetime import datetime, timezone
from typing import Optional


VALID_FINDING_TYPES = {
    "fact", "concept", "pattern", "relationship", "insight",
    "example", "definition", "procedure", "principle", "warning"
}

VALID_IMPORTANCE_LEVELS = {"critical", "high", "medium", "low"}


class Extractor:
    """Extract findings from harvested sources."""

    def extract_findings(self, source: dict) -> list[dict]:
        """Extract findings from a source.

        Args:
            source: Dict with id, source_type, path, metadata (from ranked.json)

        Returns:
            List of finding dicts matching extractions.schema.json
        """
        findings = []
        source_path = source.get("path", "").lower()
        source_id = source.get("id", "unknown")

        # Mock extraction logic based on path heuristics
        if "critical" in source_path:
            # Generate insight finding
            findings.append(self._create_finding(
                source_id=source_id,
                finding_type="insight",
                content=f"Critical insight extracted from {source.get('path', 'source')}",
                confidence=0.90,
                category="Performance",
                importance="critical",
                tags=["performance", "critical"],
                citation_text="Critical content identified in source",
                actionable=True
            ))

            # Generate pattern finding
            findings.append(self._create_finding(
                source_id=source_id,
                finding_type="pattern",
                content=f"Pattern identified in critical source {source.get('path', 'source')}",
                confidence=0.85,
                category="Debugging",
                importance="critical",
                tags=["debugging", "pattern"],
                citation_text="Pattern evidence from source",
                actionable=True
            ))
        else:
            # Generate fact finding
            findings.append(self._create_finding(
                source_id=source_id,
                finding_type="fact",
                content=f"Fact extracted from {source.get('path', 'source')}",
                confidence=0.75,
                category="Process",
                importance="medium",
                tags=["process"],
                citation_text="Factual content from source",
                actionable=False
            ))

        return findings

    def _create_finding(
        self,
        source_id: str,
        finding_type: str,
        content: str,
        confidence: float,
        category: str,
        importance: str,
        tags: list[str],
        citation_text: str,
        actionable: bool
    ) -> dict:
        """Create a finding dict with all required fields.

        Args:
            source_id: Source ID reference
            finding_type: Type of finding
            content: Finding content
            confidence: Confidence score (0.0-1.0)
            category: High-level category
            importance: Importance level
            tags: List of tags
            citation_text: Citation text
            actionable: Whether finding is actionable

        Returns:
            Finding dict matching schema
        """
        finding = {
            "version": "1.0.0",
            "source_id": source_id,
            "finding_type": finding_type,
            "content": content,
            "confidence": confidence,
            "category": category,
            "citations": [
                {
                    "text": citation_text
                }
            ],
            "metadata": {
                "extracted_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
                "tags": tags,
                "importance": importance,
                "actionable": actionable
            },
            "finding_id": str(uuid.uuid4())
        }

        return finding

    def validate_finding(self, finding: dict) -> bool:
        """Validate a finding against schema requirements.

        Args:
            finding: Finding dict to validate

        Returns:
            True if valid

        Raises:
            ValueError: If finding is invalid (with descriptive message)
        """
        # Required top-level fields
        required_fields = [
            "version", "source_id", "finding_type", "content",
            "confidence", "category", "citations"
        ]

        for field in required_fields:
            if field not in finding:
                raise ValueError(f"Missing required field: {field}")

        # Validate finding_type
        if finding["finding_type"] not in VALID_FINDING_TYPES:
            raise ValueError(
                f"Invalid finding_type '{finding['finding_type']}'. "
                f"Must be one of: {', '.join(sorted(VALID_FINDING_TYPES))}"
            )

        # Validate confidence range
        confidence = finding["confidence"]
        if not isinstance(confidence, (int, float)):
            raise ValueError(f"confidence must be numeric, got {type(confidence).__name__}")

        if not (0.0 <= confidence <= 1.0):
            raise ValueError(f"confidence must be between 0.0 and 1.0, got {confidence}")

        # Validate citations
        if not isinstance(finding["citations"], list):
            raise ValueError("citations must be a list")

        if len(finding["citations"]) == 0:
            raise ValueError("citations list cannot be empty")

        for i, citation in enumerate(finding["citations"]):
            if not isinstance(citation, dict):
                raise ValueError(f"citations[{i}] must be a dict")

            if "text" not in citation:
                raise ValueError(f"citations[{i}] missing required 'text' field")

        # Validate finding_id if present
        if "finding_id" in finding:
            finding_id = finding["finding_id"]
            try:
                # Validate UUID format
                uuid.UUID(finding_id, version=4)
            except (ValueError, AttributeError, TypeError):
                raise ValueError(f"finding_id must be valid UUID v4 format, got '{finding_id}'")

        # Validate metadata if present
        if "metadata" in finding:
            metadata = finding["metadata"]
            if not isinstance(metadata, dict):
                raise ValueError("metadata must be a dict")

            # Validate importance if present
            if "importance" in metadata:
                importance = metadata["importance"]
                if importance not in VALID_IMPORTANCE_LEVELS:
                    raise ValueError(
                        f"Invalid importance '{importance}'. "
                        f"Must be one of: {', '.join(sorted(VALID_IMPORTANCE_LEVELS))}"
                    )

        return True
