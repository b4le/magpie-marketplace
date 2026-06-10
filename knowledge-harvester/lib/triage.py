"""Triage scoring module for knowledge harvester pipeline.

Stage 2: Scores candidates and decides include/exclude/review.
Uses configurable lenses (relevance, freshness, authority, depth, uniqueness)
and aggregation methods to produce ranked candidates with triage decisions.
"""


class TriageScorer:
    """Score candidates using configurable lenses and aggregation."""

    def __init__(self, threshold: float = 7.0, aggregation_method: str = "weighted_average"):
        """Initialize the triage scorer.

        Args:
            threshold: Minimum score for 'include' decision (0-10 scale).
                Default 7.0.
            aggregation_method: One of weighted_average, minimum, maximum, product.
                Default weighted_average.

        Raises:
            ValueError: If aggregation_method is not valid.
        """
        valid_methods = ["weighted_average", "minimum", "maximum", "product"]
        if aggregation_method not in valid_methods:
            raise ValueError(
                f"Invalid aggregation_method '{aggregation_method}'. "
                f"Must be one of {valid_methods}"
            )

        self.threshold = threshold
        self.aggregation_method = aggregation_method
        self.weights = {
            "relevance": 0.3,
            "freshness": 0.2,
            "authority": 0.2,
            "depth": 0.15,
            "uniqueness": 0.15
        }

    def calculate_combined_score(self, scores: dict) -> float:
        """Aggregate lens scores into combined score.

        Args:
            scores: Dict with keys relevance, freshness, authority, depth, uniqueness.
                Each value should be a number from 0-10.

        Returns:
            Combined score 0-10, rounded to 2 decimal places.

        Raises:
            KeyError: If required score lens is missing (for weighted_average).
            ValueError: If aggregation_method is invalid.
        """
        if self.aggregation_method == "weighted_average":
            # Validate all required lenses present
            for lens in self.weights:
                if lens not in scores:
                    raise KeyError(f"Missing required score: {lens}")

            # Calculate weighted average
            total = sum(scores[lens] * self.weights[lens] for lens in self.weights)
            return round(total, 2)

        elif self.aggregation_method == "minimum":
            return min(scores.values())

        elif self.aggregation_method == "maximum":
            return max(scores.values())

        elif self.aggregation_method == "product":
            # Product method: multiply normalized scores, then denormalize
            product = 1.0
            for score in scores.values():
                product *= (score / 10.0)
            return round(product * 10, 2)

        else:
            raise ValueError(f"Unknown aggregation method: {self.aggregation_method}")

    def _mock_score_candidate(self, candidate: dict) -> dict:
        """Generate mock scores based on filename hints.

        This is for testing/development. In production, scores would come from LLM.

        Scoring heuristics:
        - "critical" in path → high scores (9+)
        - "archived" or "old" in path → low scores (2-4)
        - "borderline" in path → threshold-adjacent scores (~6.9)
        - default → moderate scores (~7.5)

        Args:
            candidate: Candidate dict with 'path' field.

        Returns:
            Dict with relevance, freshness, authority, depth, uniqueness scores.
        """
        path = candidate.get("path", "").lower()

        if "critical" in path:
            return {
                "relevance": 9.5,
                "freshness": 9.0,
                "authority": 8.5,
                "depth": 9.2,
                "uniqueness": 8.8
            }
        elif "archived" in path or "old" in path:
            return {
                "relevance": 3.0,
                "freshness": 2.0,
                "authority": 4.0,
                "depth": 3.5,
                "uniqueness": 2.5
            }
        elif "borderline" in path:
            return {
                "relevance": 6.8,
                "freshness": 7.2,
                "authority": 6.5,
                "depth": 7.0,
                "uniqueness": 6.9
            }
        else:
            return {
                "relevance": 7.5,
                "freshness": 8.0,
                "authority": 7.0,
                "depth": 7.5,
                "uniqueness": 7.2
            }

    def _determine_decision(self, combined_score: float) -> tuple:
        """Determine triage decision based on combined score.

        Decision logic:
        - score >= threshold → "include"
        - score >= threshold - 1 → "review"
        - score < threshold - 1 → "exclude"

        Args:
            combined_score: The aggregated score from 0-10.

        Returns:
            Tuple of (decision, decision_reason).
        """
        if combined_score >= self.threshold:
            decision = "include"
            reason = f"Score {combined_score} meets inclusion threshold {self.threshold}"
        elif combined_score >= self.threshold - 1:
            decision = "review"
            reason = f"Score {combined_score} near threshold {self.threshold}, requires manual review"
        else:
            decision = "exclude"
            reason = f"Score {combined_score} below review threshold {self.threshold - 1}"

        return decision, reason

    def score_candidates(self, candidates: list) -> list:
        """Score and rank candidates.

        Args:
            candidates: List of candidate dicts from enumerate stage.
                Each candidate should have: id, source_type, path, metadata.

        Returns:
            List of ranked candidates matching ranked.schema.json, including:
            - All fields from original candidate
            - scores: {relevance, freshness, authority, depth, uniqueness}
            - combined_score: float (0-10)
            - decision: "include" | "exclude" | "review"
            - decision_reason: string explaining the decision
            - ranking: int (1 = highest score)

        The list is sorted by combined_score in descending order.
        """
        ranked = []

        # Score each candidate
        for candidate in candidates:
            # Mock score generation (Phase 2 will use actual LLM scoring)
            scores = self._mock_score_candidate(candidate)

            # Calculate combined score
            combined = self.calculate_combined_score(scores)

            # Determine decision
            decision, reason = self._determine_decision(combined)

            # Build ranked item with all required fields
            ranked_item = {
                **candidate,  # Preserve all original fields
                "scores": scores,
                "combined_score": combined,
                "decision": decision,
                "decision_reason": reason
            }
            ranked.append(ranked_item)

        # Sort by combined score (highest first) and add ranking
        ranked.sort(key=lambda x: x["combined_score"], reverse=True)
        for i, item in enumerate(ranked):
            item["ranking"] = i + 1

        return ranked
