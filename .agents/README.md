# Agent Governance & Quality Architecture

## Overview
This repository integrates with the **`d3nexus`** governance and quality assurance system.

## Directory Structure
- `.agents/config.json`: Agent rules configuration and auto-commit flags.
- `.agents/rules/`: Enforced rule sets (`CRITICAL_RULES.md`, `CLAUDE.md`, `LOCALIZATION_RULES.md`).
- `.agents/quality/check_quality.json`: Project quality registry defining registered providers (`ios-core`).
- `.agents/quality/ios-quality.json`: iOS capability manifest declaring hermetic verification commands (`format`, `lint`, `architecture`, `boundaries`, `test`, `coverage`, `acceptance`) and profile selections (`pr`, `epic`).

## Quality Profiles
- **`pr`**: Lightweight gate for pull requests (`format`, `lint`, `test`).
- **`epic`**: Strict Gate 4 certification (`format`, `lint`, `architecture`, `boundaries`, `test`, `coverage`).
