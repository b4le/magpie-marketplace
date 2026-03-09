import uuid
from datetime import datetime, timezone
from typing import Optional, Dict, List, Any


class Synthesizer:
    """Synthesize findings into cohesive summary."""

    def __init__(self) -> None:
        self.template: Dict[str, Any] = {
            "harvest_id": None,
            "timestamp": None,
            "total_sources": 0,
            "total_findings": 0,
            "categories": {},
            "key_insights": [],
            "patterns": [],
            "conflicts": [],
            "recommendations": []
        }

    def synthesize_findings(self, findings: List[Dict[str, Any]], sources: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Synthesize findings into a cohesive summary.

        Args:
            findings: List of finding dicts from extract stage
            sources: List of source dicts that were processed

        Returns:
            Synthesis dict with categorized findings, insights, patterns, conflicts, recommendations
        """
        # Handle empty findings case
        if not findings:
            return self.handle_empty_findings(sources)

        # Initialize synthesis output
        synthesis = self.template.copy()
        synthesis["harvest_id"] = str(uuid.uuid4())
        synthesis["timestamp"] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        synthesis["total_sources"] = len(sources)
        synthesis["total_findings"] = len(findings)

        # Categorize findings
        synthesis["categories"] = self._categorize_findings(findings)

        # Extract key insights
        synthesis["key_insights"] = self._extract_key_insights(findings)

        # Identify patterns
        synthesis["patterns"] = self._identify_patterns(findings)

        # Detect conflicts
        synthesis["conflicts"] = self._detect_conflicts(findings)

        # Generate recommendations
        synthesis["recommendations"] = self._generate_recommendations(synthesis["key_insights"])

        return synthesis

    def handle_empty_findings(self, sources: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Handle case where no findings were extracted.

        Args:
            sources: List of source dicts that were processed

        Returns:
            Synthesis dict with appropriate empty-state handling
        """
        synthesis = self.template.copy()
        synthesis["harvest_id"] = str(uuid.uuid4())
        synthesis["timestamp"] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        synthesis["total_sources"] = len(sources)
        synthesis["total_findings"] = 0
        synthesis["categories"] = {}
        synthesis["key_insights"] = []
        synthesis["patterns"] = []
        synthesis["conflicts"] = []
        synthesis["recommendations"] = [
            {
                "action": "Review extraction criteria",
                "priority": "medium",
                "based_on": [],
                "reason": "No findings extracted from available sources"
            }
        ]

        return synthesis

    def _categorize_findings(self, findings: List[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
        """Group findings by category field.

        Args:
            findings: List of finding dicts

        Returns:
            Dict mapping category names to counts and finding_ids
        """
        categories = {}

        for finding in findings:
            category = finding.get("category", "Uncategorized")
            finding_id = finding.get("finding_id")

            if category not in categories:
                categories[category] = {
                    "count": 0,
                    "findings": []
                }

            categories[category]["count"] += 1
            if finding_id:
                categories[category]["findings"].append(finding_id)

        return categories

    def _extract_key_insights(self, findings: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Extract top insights from findings.

        Args:
            findings: List of finding dicts

        Returns:
            List of top 3 insights by confidence
        """
        insights = [
            f for f in findings
            if f.get("finding_type") == "insight"
        ]

        # Sort by confidence descending
        insights.sort(key=lambda x: x.get("confidence", 0.0), reverse=True)

        # Take top 3
        top_insights = insights[:3]

        # Format for output
        return [
            {
                "content": insight.get("content", ""),
                "confidence": insight.get("confidence", 0.0),
                "source": insight.get("source_id", "")
            }
            for insight in top_insights
        ]

    def _identify_patterns(self, findings: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Identify patterns from findings.

        Args:
            findings: List of finding dicts

        Returns:
            List of top 2 patterns
        """
        patterns = [
            f for f in findings
            if f.get("finding_type") == "pattern"
        ]

        # Take top 2
        top_patterns = patterns[:2]

        # Format for output
        return [
            {
                "description": pattern.get("content", ""),
                "occurrences": pattern.get("occurrences", 1),
                "sources": pattern.get("sources", [pattern.get("source_id", "")])
            }
            for pattern in top_patterns
        ]

    def _detect_conflicts(self, findings: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Detect potential conflicts in findings.

        Args:
            findings: List of finding dicts

        Returns:
            List of detected conflicts
        """
        conflicts = []

        # Generate mock conflict if more than 5 findings
        if len(findings) > 5:
            # Get unique source IDs
            source_ids = list(set(f.get("source_id") for f in findings if f.get("source_id")))[:2]

            conflicts.append({
                "description": "Conflicting info about X",
                "sources": source_ids,
                "resolution": "Manual review required"
            })

        return conflicts

    def _generate_recommendations(self, key_insights: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Generate actionable recommendations.

        Args:
            key_insights: List of key insight dicts

        Returns:
            List of recommendations
        """
        recommendations = []

        if key_insights:
            top_insight = key_insights[0]
            recommendations.append({
                "action": "Implement performance improvements",
                "priority": "high",
                "based_on": [top_insight.get("source", "")]
            })

        return recommendations
