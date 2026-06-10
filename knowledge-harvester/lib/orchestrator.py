"""Pipeline orchestrator for knowledge-harvester.

Coordinates the 6-stage knowledge harvesting pipeline:
1. Enumerate - Discover candidate sources
2. Triage - Score and filter candidates
3. Harvest - Copy files to workspace (bash-only)
4. Extract - Extract findings from sources
5. Synthesize - Generate knowledge synthesis
6. Complete - Final validation and output

Supports checkpoint/resume for interrupted harvests.
"""

import json
import os
import subprocess
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# Import stage implementations
from lib.enumerate import enumerate_local
from lib.triage import TriageScorer
from lib.extract import Extractor
from lib.synthesize import Synthesizer
from lib.checkpoint import CheckpointManager


class HarvestOrchestrator:
    """Orchestrates the knowledge harvesting pipeline."""

    STAGE_NAMES = {
        1: "enumerate",
        2: "triage",
        3: "harvest",
        4: "extract",
        5: "synthesize",
        6: "complete"
    }

    def __init__(self, config: dict, workspace_dir: Optional[str] = None):
        """Initialize the orchestrator.

        Args:
            config: Harvest configuration dict (validated against schema)
            workspace_dir: Optional workspace directory (default: .harvest)
        """
        self.config = config
        self.harvest_id = str(uuid.uuid4())
        self.workspace = Path(workspace_dir or ".harvest")

        # Stage outputs
        self.candidates_file = self.workspace / "candidates.json"
        self.ranked_file = self.workspace / "ranked.json"
        self.manifest_file = self.workspace / "manifest.json"
        self.extractions_file = self.workspace / "extractions.jsonl"
        self.synthesis_file = self.workspace / "output" / "knowledge.md"

        # Initialize checkpoint manager
        self.checkpoint_manager = CheckpointManager(self.workspace, self.harvest_id)
        # Set config metadata (will be saved when workspace is setup)
        self.checkpoint_manager.checkpoint["metadata"]["config_file"] = config.get("name", "inline")

    @property
    def checkpoint_file(self) -> Path:
        """Backward-compatible access to checkpoint file path."""
        return self.checkpoint_manager.checkpoint_file

    @property
    def checkpoint(self) -> dict:
        """Backward-compatible access to checkpoint data."""
        return self.checkpoint_manager.checkpoint

    def _timestamp(self) -> str:
        """Generate ISO8601 timestamp."""
        return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    def _log(self, message: str, level: str = "INFO"):
        """Log a message."""
        timestamp = self._timestamp()
        print(f"[{timestamp}] [{level}] {message}")

    def _save_checkpoint(self):
        """Save checkpoint to disk."""
        self.checkpoint_manager.save()

    def _load_checkpoint(self) -> bool:
        """Load checkpoint from disk if exists.

        Returns:
            True if checkpoint loaded, False if starting fresh
        """
        loaded = self.checkpoint_manager.load()
        if loaded:
            # Restore harvest_id from checkpoint
            self.harvest_id = self.checkpoint_manager.checkpoint.get("harvest_id", self.harvest_id)
            self._log(f"Resumed from checkpoint at stage {self.checkpoint_manager.current_stage}")
            return True
        else:
            if self.checkpoint_manager.checkpoint_file.exists():
                self._log(f"Invalid checkpoint, starting fresh", "WARN")
            return False

    def _record_stage_start(self, stage: int):
        """Record stage start in history."""
        self.checkpoint_manager.record_stage_start(stage)

    def _record_stage_complete(self, stage: int, output_path: Optional[str] = None):
        """Record stage completion."""
        self.checkpoint_manager.record_stage_complete(stage, output_path)

    def _record_error(self, stage: int, message: str, recoverable: bool = True):
        """Record an error."""
        self.checkpoint_manager.record_error(stage, message, recoverable)

    def _is_stage_complete(self, stage: int) -> bool:
        """Check if a stage is already complete."""
        return self.checkpoint_manager.is_stage_complete(stage)

    def setup_workspace(self):
        """Create workspace directory structure."""
        self.workspace.mkdir(parents=True, exist_ok=True)
        (self.workspace / "sources").mkdir(exist_ok=True)
        (self.workspace / "output").mkdir(exist_ok=True)
        self._log(f"Workspace created: {self.workspace}")

    def run_enumerate(self) -> list:
        """Stage 1: Enumerate candidates from configured sources.

        Returns:
            List of candidate dicts
        """
        if self._is_stage_complete(1):
            self._log("Stage 1 (enumerate) already complete, loading from checkpoint")
            return json.loads(self.candidates_file.read_text())

        self._record_stage_start(1)
        self._log("Stage 1: Enumerating candidates...")

        all_candidates = []
        sources = self.config.get("sources", {})

        # Process local sources
        local_sources = sources.get("local", [])
        for source_config in local_sources:
            try:
                candidates = enumerate_local(source_config)
                all_candidates.extend(candidates)
                self._log(f"  Found {len(candidates)} candidates in {source_config.get('path', 'unknown')}")
            except Exception as e:
                self._record_error(1, f"Enumeration failed for {source_config}: {e}")
                self._log(f"  Error enumerating {source_config.get('path')}: {e}", "ERROR")
                # Continue processing other sources - partial success is acceptable

        # Apply limits
        limits = self.config.get("limits", {})
        max_candidates = limits.get("max_candidates", 100)
        if len(all_candidates) > max_candidates:
            self._log(f"  Limiting to {max_candidates} candidates (found {len(all_candidates)})")
            all_candidates = all_candidates[:max_candidates]

        # Save output
        self.candidates_file.write_text(json.dumps(all_candidates, indent=2))
        self._record_stage_complete(1, str(self.candidates_file))
        self._log(f"Stage 1 complete: {len(all_candidates)} candidates")

        return all_candidates

    def run_triage(self, candidates: list) -> list:
        """Stage 2: Score and rank candidates.

        Args:
            candidates: List from enumerate stage

        Returns:
            List of ranked candidates with decisions
        """
        if self._is_stage_complete(2):
            self._log("Stage 2 (triage) already complete, loading from checkpoint")
            return json.loads(self.ranked_file.read_text())

        self._record_stage_start(2)
        self._log("Stage 2: Triaging candidates...")

        # Get triage config
        triage_config = self.config.get("triage", {})
        threshold = triage_config.get("threshold", 7.0)
        aggregation = triage_config.get("aggregation", "weighted_average")

        # Score candidates
        scorer = TriageScorer(threshold=threshold, aggregation_method=aggregation)
        ranked = scorer.score_candidates(candidates)

        # Save output
        self.ranked_file.write_text(json.dumps(ranked, indent=2))
        self._record_stage_complete(2, str(self.ranked_file))

        # Report stats
        included = sum(1 for r in ranked if r["decision"] == "include")
        excluded = sum(1 for r in ranked if r["decision"] == "exclude")
        review = sum(1 for r in ranked if r["decision"] == "review")
        self._log(f"Stage 2 complete: {included} include, {excluded} exclude, {review} review")

        return ranked

    def run_harvest(self, ranked: list) -> dict:
        """Stage 3: Copy included sources to workspace (bash-only).

        Args:
            ranked: List from triage stage

        Returns:
            Manifest dict with harvest details
        """
        if self._is_stage_complete(3):
            self._log("Stage 3 (harvest) already complete, loading from checkpoint")
            return json.loads(self.manifest_file.read_text())

        self._record_stage_start(3)
        self._log("Stage 3: Harvesting sources (bash-only)...")

        # Get the harvest.sh script path
        script_path = Path(__file__).parent / "harvest.sh"

        if not script_path.exists():
            # Fallback: harvest manually
            self._log("  harvest.sh not found, using Python fallback")
            manifest = self._harvest_fallback(ranked)
        else:
            # Run bash script
            try:
                result = subprocess.run(
                    ["bash", str(script_path)],
                    input=json.dumps(ranked),
                    capture_output=True,
                    text=True,
                    cwd=str(self.workspace)
                )

                if result.returncode != 0:
                    self._log(f"  harvest.sh failed: {result.stderr}", "WARN")
                    manifest = self._harvest_fallback(ranked)
                else:
                    manifest = json.loads(self.manifest_file.read_text())

            except Exception as e:
                self._log(f"  harvest.sh error: {e}", "WARN")
                manifest = self._harvest_fallback(ranked)

        self._record_stage_complete(3, str(self.manifest_file))
        self._log(f"Stage 3 complete: {manifest.get('files_harvested', 0)} files harvested")

        return manifest

    def _harvest_fallback(self, ranked: list) -> dict:
        """Fallback harvest using Python when bash script unavailable."""
        import shutil

        sources_dir = self.workspace / "sources"
        manifest = {
            "harvest_timestamp": self._timestamp(),
            "files_harvested": 0,
            "total_size_bytes": 0,
            "files": []
        }

        for candidate in ranked:
            if candidate.get("decision") != "include":
                continue

            source_path = Path(candidate.get("path", ""))
            if not source_path.exists():
                self._log(f"  Skipping missing file: {source_path}", "WARN")
                continue

            # Create destination directory
            dest_dir = sources_dir / candidate.get("id", "unknown")
            dest_dir.mkdir(parents=True, exist_ok=True)
            dest_path = dest_dir / source_path.name

            try:
                shutil.copy2(source_path, dest_path)
                size = dest_path.stat().st_size

                manifest["files"].append({
                    "id": candidate.get("id"),
                    "source_path": str(source_path),
                    "harvest_path": str(dest_path),
                    "size_bytes": size
                })
                manifest["files_harvested"] += 1
                manifest["total_size_bytes"] += size

            except Exception as e:
                self._log(f"  Failed to copy {source_path}: {e}", "WARN")

        self.manifest_file.write_text(json.dumps(manifest, indent=2))
        return manifest

    def run_extract(self, manifest: dict, ranked: list) -> list:
        """Stage 4: Extract findings from harvested sources.

        Args:
            manifest: Manifest from harvest stage
            ranked: Ranked candidates (for metadata)

        Returns:
            List of extracted findings
        """
        if self._is_stage_complete(4):
            self._log("Stage 4 (extract) already complete, loading from checkpoint")
            findings = []
            with open(self.extractions_file) as f:
                for line in f:
                    if line.strip():
                        findings.append(json.loads(line))
            return findings

        self._record_stage_start(4)
        self._log("Stage 4: Extracting findings...")

        # Build lookup of ranked items by id
        ranked_by_id = {r["id"]: r for r in ranked}

        # Get parallelization config
        limits = self.config.get("limits", {})
        max_workers = limits.get("max_workers", 5)

        all_findings = []
        files_to_process = manifest.get("files", [])

        if not files_to_process:
            self._log("  No files to extract from")
            self._record_stage_complete(4, str(self.extractions_file))
            return all_findings

        # Process files in parallel using ThreadPoolExecutor
        self._log(f"  Processing {len(files_to_process)} files with {max_workers} workers")

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all extraction tasks
            future_to_file = {
                executor.submit(
                    self._extract_single_file,
                    file_info,
                    ranked_by_id
                ): file_info
                for file_info in files_to_process
            }

            # Collect results as they complete
            for future in as_completed(future_to_file):
                file_info = future_to_file[future]
                source_id = file_info.get("id")

                try:
                    validated_findings = future.result()
                    all_findings.extend(validated_findings)
                    self._log(f"  Extracted {len(validated_findings)} validated findings from {source_id}")
                except Exception as e:
                    self._record_error(4, f"Extraction failed for {source_id}: {e}")
                    self._log(f"  Error extracting from {source_id}: {e}", "ERROR")

        # Write JSONL output
        with open(self.extractions_file, "w") as f:
            for finding in all_findings:
                f.write(json.dumps(finding) + "\n")

        self._record_stage_complete(4, str(self.extractions_file))
        self._log(f"Stage 4 complete: {len(all_findings)} findings extracted")

        return all_findings

    def _extract_single_file(self, file_info: dict, ranked_by_id: dict) -> list:
        """Extract findings from a single file (worker function for parallel processing).

        Args:
            file_info: File info from manifest
            ranked_by_id: Lookup dict of ranked candidates by ID

        Returns:
            List of validated findings from this file
        """
        source_id = file_info.get("id")
        source = ranked_by_id.get(source_id, {}).copy()
        source["harvest_path"] = file_info.get("harvest_path")

        extractor = Extractor()
        findings = extractor.extract_findings(source)

        # Validate findings before returning
        validated_findings = []
        for finding in findings:
            try:
                if extractor.validate_finding(finding):
                    validated_findings.append(finding)
            except ValueError:
                # Skip invalid findings silently in worker
                pass

        return validated_findings

    def run_synthesize(self, findings: list, sources: list) -> dict:
        """Stage 5: Synthesize findings into output.

        Args:
            findings: List from extract stage
            sources: Source metadata for attribution

        Returns:
            Synthesis dict
        """
        if self._is_stage_complete(5):
            self._log("Stage 5 (synthesize) already complete, loading from checkpoint")
            # Load synthesis from JSON if available
            synthesis_json_path = self.workspace / "output" / "synthesis.json"
            if synthesis_json_path.exists():
                return json.loads(synthesis_json_path.read_text())
            # Fallback to minimal synthesis info
            return {"status": "complete", "output": str(self.synthesis_file)}

        self._record_stage_start(5)
        self._log("Stage 5: Synthesizing findings...")

        synthesizer = Synthesizer()

        if findings:
            synthesis = synthesizer.synthesize_findings(findings, sources)
        else:
            synthesis = synthesizer.handle_empty_findings(sources)

        # Generate markdown output using template
        output_md = self._render_synthesis(synthesis, findings, sources)
        self.synthesis_file.parent.mkdir(parents=True, exist_ok=True)
        self.synthesis_file.write_text(output_md)

        # Also save JSON synthesis
        synthesis_json = self.workspace / "output" / "synthesis.json"
        synthesis_json.write_text(json.dumps(synthesis, indent=2))

        self._record_stage_complete(5, str(self.synthesis_file))
        self._log(f"Stage 5 complete: output written to {self.synthesis_file}")

        return synthesis

    def _render_synthesis(self, synthesis: dict, findings: list, sources: list) -> str:
        """Render synthesis to markdown (simplified Handlebars-like)."""
        # Build sections from categories
        sections = []
        for category, data in synthesis.get("categories", {}).items():
            category_findings = [
                f for f in findings
                if f.get("finding_id") in data.get("findings", [])
            ]
            sections.append({
                "title": category,
                "content": f"{data.get('count', 0)} findings in this category.",
                "findings": [
                    {
                        "claim": f.get("content", ""),
                        "confidence": f"{f.get('confidence', 0):.0%}",
                        "sources": f.get("source_id", "")
                    }
                    for f in category_findings[:5]  # Limit to 5 per category
                ]
            })

        # Generate markdown
        lines = [
            f"# {self.config.get('name', 'Knowledge Synthesis')}",
            "",
            f"> Generated: {self._timestamp()}",
            f"> Sources: {synthesis.get('total_sources', 0)} files | Findings: {synthesis.get('total_findings', 0)} validated",
            "",
            "---",
            "",
            "## Executive Summary",
            "",
        ]

        # Add key insights as summary
        insights = synthesis.get("key_insights", [])
        if insights:
            for insight in insights[:3]:
                lines.append(f"- {insight.get('content', '')}")
            lines.append("")
        else:
            lines.append("No key insights extracted.")
            lines.append("")

        lines.extend([
            "---",
            "",
            "## Key Findings",
            "",
        ])

        # Add sections
        for section in sections:
            lines.append(f"### {section['title']}")
            lines.append("")
            lines.append(section.get("content", ""))
            lines.append("")
            for finding in section.get("findings", []):
                lines.append(f"- **{finding['claim']}** [{finding['confidence']}]")
            lines.append("")

        # Add patterns
        patterns = synthesis.get("patterns", [])
        if patterns:
            lines.extend(["---", "", "## Patterns Identified", ""])
            for pattern in patterns:
                lines.append(f"- {pattern.get('description', '')}")
            lines.append("")

        # Add conflicts
        conflicts = synthesis.get("conflicts", [])
        if conflicts:
            lines.extend(["---", "", "## Conflicts Detected", ""])
            for conflict in conflicts:
                lines.append(f"- {conflict.get('description', '')} - Resolution: {conflict.get('resolution', 'TBD')}")
            lines.append("")

        # Add recommendations
        recommendations = synthesis.get("recommendations", [])
        if recommendations:
            lines.extend(["---", "", "## Recommendations", ""])
            for rec in recommendations:
                lines.append(f"- **[{rec.get('priority', 'medium').upper()}]** {rec.get('action', '')}")
            lines.append("")

        lines.extend([
            "---",
            "",
            f"*Generated by Knowledge Harvester | Harvest ID: {synthesis.get('harvest_id', 'unknown')}*"
        ])

        return "\n".join(lines)

    def run_complete(self) -> dict:
        """Stage 6: Final validation and completion.

        Returns:
            Final harvest summary
        """
        self._record_stage_start(6)
        self._log("Stage 6: Finalizing harvest...")

        # Build summary
        summary = {
            "harvest_id": self.harvest_id,
            "completed_at": self._timestamp(),
            "stages_completed": 6,
            "outputs": {
                "candidates": str(self.candidates_file) if self.candidates_file.exists() else None,
                "ranked": str(self.ranked_file) if self.ranked_file.exists() else None,
                "manifest": str(self.manifest_file) if self.manifest_file.exists() else None,
                "extractions": str(self.extractions_file) if self.extractions_file.exists() else None,
                "synthesis": str(self.synthesis_file) if self.synthesis_file.exists() else None,
            },
            "errors": self.checkpoint_manager.checkpoint.get("errors", [])
        }

        # Save final summary
        summary_file = self.workspace / "output" / "summary.json"
        summary_file.write_text(json.dumps(summary, indent=2))

        self._record_stage_complete(6, str(summary_file))
        self._log(f"Harvest complete! Output: {self.synthesis_file}")

        return summary

    def run(self, resume: bool = False) -> dict:
        """Execute the full harvest pipeline.

        Args:
            resume: Whether to resume from checkpoint

        Returns:
            Final harvest summary
        """
        self._log(f"Starting harvest: {self.config.get('name', 'unnamed')}")

        # Setup workspace
        self.setup_workspace()

        # Handle resume
        if resume:
            self._load_checkpoint()
        else:
            self._save_checkpoint()

        # Execute stages
        try:
            # Stage 1: Enumerate
            candidates = self.run_enumerate()

            # Stage 2: Triage
            ranked = self.run_triage(candidates)

            # Stage 3: Harvest
            manifest = self.run_harvest(ranked)

            # Stage 4: Extract
            included_sources = [r for r in ranked if r.get("decision") == "include"]
            findings = self.run_extract(manifest, ranked)

            # Stage 5: Synthesize
            self.run_synthesize(findings, included_sources)

            # Stage 6: Complete
            summary = self.run_complete()

            return summary

        except Exception as e:
            self._record_error(self.checkpoint_manager.current_stage, str(e), recoverable=True)
            self._log(f"Pipeline failed: {e}", "ERROR")
            raise


def run_harvest(config: dict, workspace: str = ".harvest", resume: bool = False) -> dict:
    """Convenience function to run a harvest.

    Args:
        config: Harvest configuration dict
        workspace: Workspace directory path
        resume: Whether to resume from checkpoint

    Returns:
        Harvest summary dict
    """
    orchestrator = HarvestOrchestrator(config, workspace)
    return orchestrator.run(resume=resume)
