"""Checkpoint management for knowledge-harvester.

Handles saving and loading pipeline state for resume capability.
"""

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


class CheckpointManager:
    """Manages checkpoint state for harvest pipeline resumption."""

    STAGE_NAMES = {
        1: "enumerate",
        2: "triage",
        3: "harvest",
        4: "extract",
        5: "synthesize",
        6: "complete"
    }

    def __init__(self, workspace: Path, harvest_id: str):
        """Initialize checkpoint manager.

        Args:
            workspace: Workspace directory path
            harvest_id: Unique identifier for this harvest
        """
        self.workspace = workspace
        self.harvest_id = harvest_id
        self.checkpoint_file = workspace / "checkpoint.json"

        # Initialize checkpoint structure
        self._checkpoint = {
            "version": "1.0.0",
            "harvest_id": harvest_id,
            "created_at": self._timestamp(),
            "updated_at": self._timestamp(),
            "current_stage": 1,
            "stage_outputs": {},
            "progress": {"completed": 0, "total": 0, "percentage": 0},
            "errors": [],
            "metadata": {
                "source_directory": str(workspace)
            },
            "stage_history": []
        }

    @property
    def checkpoint(self) -> dict:
        """Access checkpoint data."""
        return self._checkpoint

    @property
    def current_stage(self) -> int:
        """Get current stage number."""
        return self._checkpoint.get("current_stage", 1)

    def _timestamp(self) -> str:
        """Generate ISO8601 timestamp."""
        return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    def save(self) -> None:
        """Save checkpoint to disk."""
        self._checkpoint["updated_at"] = self._timestamp()
        self.checkpoint_file.write_text(json.dumps(self._checkpoint, indent=2))

    def load(self) -> bool:
        """Load checkpoint from disk if exists.

        Returns:
            True if checkpoint loaded, False if starting fresh
        """
        if not self.checkpoint_file.exists():
            return False

        try:
            saved = json.loads(self.checkpoint_file.read_text())
            self._checkpoint = saved
            return True
        except (json.JSONDecodeError, KeyError) as e:
            # Invalid checkpoint, continue with fresh state
            return False

    def record_stage_start(self, stage: int) -> None:
        """Record stage start in history.

        Args:
            stage: Stage number (1-6)
        """
        self._checkpoint["stage_history"].append({
            "stage": stage,
            "started_at": self._timestamp(),
            "status": "in_progress"
        })
        self._checkpoint["current_stage"] = stage
        self.save()

    def record_stage_complete(self, stage: int, output_path: Optional[str] = None) -> None:
        """Record stage completion.

        Args:
            stage: Stage number (1-6)
            output_path: Optional path to stage output file
        """
        # Update history
        for entry in self._checkpoint["stage_history"]:
            if entry["stage"] == stage and entry["status"] == "in_progress":
                entry["completed_at"] = self._timestamp()
                entry["status"] = "completed"
                break

        # Record output path
        if output_path:
            stage_name = self.STAGE_NAMES.get(stage, f"stage{stage}")
            self._checkpoint["stage_outputs"][stage_name] = output_path

        self.save()

    def record_error(self, stage: int, message: str, recoverable: bool = True) -> None:
        """Record an error.

        Args:
            stage: Stage number where error occurred
            message: Error message
            recoverable: Whether the error is recoverable
        """
        self._checkpoint["errors"].append({
            "timestamp": self._timestamp(),
            "stage": self.STAGE_NAMES.get(stage, f"stage{stage}"),
            "message": message,
            "recoverable": recoverable
        })
        self.save()

    def is_stage_complete(self, stage: int) -> bool:
        """Check if a stage is already complete.

        Args:
            stage: Stage number (1-6)

        Returns:
            True if stage is marked as completed
        """
        for entry in self._checkpoint["stage_history"]:
            if entry["stage"] == stage and entry["status"] == "completed":
                return True
        return False

    def update_metadata(self, key: str, value: any) -> None:
        """Update checkpoint metadata.

        Args:
            key: Metadata key
            value: Metadata value
        """
        self._checkpoint["metadata"][key] = value
        self.save()
