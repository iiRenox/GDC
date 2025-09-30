# Changelog

This file tracks all major changes to the codebase, including new features, refactoring, and bug fixes.

## [YYYY-MM-DD] - Initial Setup
- **Action**: CREATE
- **File**: `CHANGELOG.md`
- **Reason**: Initial project setup. Adhering to the project's master prompt requirements.
- **Missing Assets**: None.

- **Action**: VERIFY
- **File**: `ReplicatedStorage/Docs/ARCHITECTURE.md`
- **Reason**: Created to document the high-level component design and data flow.

- **Action**: VERIFY
- **File**: `ReplicatedStorage/Remotes/`
- **Reason**: Verified that all necessary RemoteEvents and RemoteFunctions are present as per the master prompt.

- **Action**: VERIFY
- **File**: `ReplicatedStorage/GameConfig`
- **Reason**: Validated the existing GameConfig. It is more detailed than the prompt's template and will be used as the source of truth. Its values are preferred over the prompt's where conflicts exist.