#!/bin/bash
# Detect project type based on file fingerprints
# Outputs JSON: {"profile": "name", "confidence": "high|medium|low", "fingerprints": [...]}
#
# Detection priority (highest to lowest):
# 1. Data Science (notebooks)
# 2. Go, Rust, Java (language-specific build files)
# 3. TypeScript, JavaScript (Node ecosystem)
# 4. Python (generic)
# 5. Core (fallback)

set -euo pipefail

PROJECT_DIR="${1:-.}"

# Validate directory exists
if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: Directory '$PROJECT_DIR' does not exist" >&2
    echo '{"profile": "core", "confidence": "low", "fingerprints": []}'
    exit 0
fi

cd "$PROJECT_DIR"

# Check for jq dependency
if ! command -v jq &> /dev/null; then
    echo "Warning: jq not installed - using fallback profile" >&2
    echo '{"profile": "core", "confidence": "low", "fingerprints": []}'
    exit 0
fi

detected_profile=""
confidence="low"
fingerprints=()

# Detection uses elif-chain to ensure priority ordering (first match wins)

# Data Science detection (notebooks present)
# Use find for recursive search since compgen doesn't support **
if [[ -z "$detected_profile" ]]; then
    if compgen -G "*.ipynb" > /dev/null 2>&1 || \
       [[ -n "$(find . -maxdepth 3 -name '*.ipynb' -print -quit 2>/dev/null)" ]]; then
        detected_profile="data-science"
        confidence="medium"
        fingerprints+=("*.ipynb")
    fi
fi

# Go detection
if [[ -z "$detected_profile" ]] && [[ -f "go.mod" ]]; then
    detected_profile="go"
    confidence="high"
    fingerprints+=("go.mod")
    [[ -f "go.sum" ]] && fingerprints+=("go.sum")
fi

# Rust detection
if [[ -z "$detected_profile" ]] && [[ -f "Cargo.toml" ]]; then
    detected_profile="rust"
    confidence="high"
    fingerprints+=("Cargo.toml")
    [[ -f "Cargo.lock" ]] && fingerprints+=("Cargo.lock")
fi

# Java detection (Maven or Gradle)
if [[ -z "$detected_profile" ]]; then
    if [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; then
        detected_profile="java"
        confidence="high"
        [[ -f "pom.xml" ]] && fingerprints+=("pom.xml")
        [[ -f "build.gradle" ]] && fingerprints+=("build.gradle")
        [[ -f "build.gradle.kts" ]] && fingerprints+=("build.gradle.kts")
    fi
fi

# TypeScript detection (tsconfig present)
if [[ -z "$detected_profile" ]] && [[ -f "tsconfig.json" ]]; then
    detected_profile="typescript"
    confidence="high"
    fingerprints+=("tsconfig.json")
    [[ -f "package.json" ]] && fingerprints+=("package.json")
fi

# JavaScript detection (package.json but no tsconfig)
if [[ -z "$detected_profile" ]] && [[ -f "package.json" ]]; then
    detected_profile="javascript"
    confidence="high"
    fingerprints+=("package.json")
fi

# Python detection (lowest language priority - common in polyglot repos)
if [[ -z "$detected_profile" ]]; then
    if [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
        detected_profile="python"
        confidence="high"
        [[ -f "pyproject.toml" ]] && fingerprints+=("pyproject.toml")
        [[ -f "requirements.txt" ]] && fingerprints+=("requirements.txt")
        [[ -f "setup.py" ]] && fingerprints+=("setup.py")
    fi
fi

# Default to core if nothing detected
if [[ -z "$detected_profile" ]]; then
    detected_profile="core"
    confidence="low"
fi

# Output JSON safely using jq
if [[ ${#fingerprints[@]} -eq 0 ]]; then
    fingerprints_json="[]"
else
    fingerprints_json=$(printf '%s\n' "${fingerprints[@]}" | jq -R . | jq -s .)
fi

jq -n \
    --arg profile "$detected_profile" \
    --arg confidence "$confidence" \
    --argjson fingerprints "$fingerprints_json" \
    '{profile: $profile, confidence: $confidence, fingerprints: $fingerprints}'
