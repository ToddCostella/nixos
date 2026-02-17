# Feature Specification: Flakes Migration + Home Manager + 1Password Dotfile Management

**Feature Branch**: `002-nixos-homemanager-dotfiles`
**Created**: 2026-02-17
**Status**: Draft
**Input**: User description: "Migrate NixOS from traditional channels to Nix flakes, add Home Manager for declarative dotfile management, and integrate 1Password as the secrets backend so dotfiles can be version-controlled without exposing secrets."

## Clarifications

### Session 2026-02-17

- Q: What level of AWS credential management should be included? → A: Multiple named profiles — AWS config file (~/.aws/config) managed declaratively with profile names, regions, and output formats; access keys for each profile sourced from 1Password at activation time.
- Q: How should the GnuPG SSH agent conflict with 1Password SSH agent be resolved? → A: Disable GnuPG SSH support (`enableSSHSupport = false`), use 1Password SSH agent exclusively for SSH keys and git commit signing. GnuPG agent remains available for GPG encryption and signature verification, just without SSH support.
- Q: How should existing manually-created dotfiles be handled when Home Manager takes over? → A: Back up existing dotfiles to `~/.dotfiles-backup/` before the first Home Manager activation, then let Home Manager overwrite them. The backup serves as a reference for any manual customizations that may need to be incorporated into the declarative config.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reproducible System Builds with Flakes (Priority: P1)

As a developer managing my NixOS configuration, I want my system builds to be fully reproducible by locking all dependency versions, so that I can rebuild the exact same system on any machine or at any future point in time.

**Why this priority**: Reproducibility is the foundation. Without locked dependency versions, every other feature (Home Manager, dotfiles, secrets) is built on shifting sand. This must work before anything else is layered on top.

**Independent Test**: Can be fully tested by running the system rebuild command and verifying that all existing system functionality (packages, services, desktop environment, modules) continues to work identically, and that a lockfile is generated tracking exact dependency versions.

**Acceptance Scenarios**:

1. **Given** the existing NixOS configuration with all current modules, **When** the administrator rebuilds the system using the new flake-based approach, **Then** the system boots successfully with all previously installed packages, services, and desktop environment intact.
2. **Given** a freshly generated lockfile, **When** the administrator rebuilds the system a second time without changing any configuration, **Then** the build produces an identical result using the same pinned dependency versions.
3. **Given** the lockfile is committed to version control, **When** another machine clones the repository and rebuilds, **Then** it uses the exact same dependency versions as the original build.
4. **Given** the existing modular architecture (remote-terminal.nix, desktop-gnome.nix, esp32-dev.nix, etc.), **When** the system is rebuilt under the new approach, **Then** all existing modules continue to function without any modifications to their contents.

---

### User Story 2 - Declarative Dotfile Management (Priority: P2)

As a developer, I want my shell configuration, editor settings, terminal multiplexer config, and version control settings managed declaratively alongside my system configuration, so that my entire development environment is reproducible and version-controlled in a single repository.

**Why this priority**: Once the system build is reproducible, the next most valuable layer is managing user-level configuration. Currently dotfiles are unmanaged — they drift, get lost, and can't be reproduced on a fresh install. This story delivers the core value of "one repo defines everything."

**Independent Test**: Can be fully tested by applying the configuration and verifying that the user's home directory contains the expected configuration files for git, zsh, tmux, SSH, and AWS CLI, with correct content matching the declarative definitions.

**Acceptance Scenarios**:

1. **Given** a fresh user home directory with no existing dotfiles, **When** the system configuration is applied, **Then** the user's git configuration is created with the correct name, email, and default branch settings.
2. **Given** the declarative zsh configuration, **When** the system configuration is applied, **Then** the user has a working zsh shell with Oh-My-Zsh, the expected plugins (git, docker, docker-compose, aws, vi-mode, fzf), and the robbyrussell theme.
3. **Given** the declarative tmux configuration, **When** the system configuration is applied, **Then** the user has a working tmux setup with the Catppuccin theme and existing plugins.
4. **Given** the declarative SSH configuration, **When** the system configuration is applied, **Then** the user's SSH config contains the expected host entries, and no private key material appears in any configuration file or version control.
5. **Given** the declarative AWS configuration with multiple named profiles, **When** the system configuration is applied, **Then** the user's AWS config file contains the expected profiles with regions and output formats, and credentials are resolved from 1Password.
6. **Given** the administrator adds a new dotfile to the declarative configuration, **When** the system is rebuilt, **Then** the new dotfile appears in the user's home directory with the correct content.

---

### User Story 3 - Secrets Managed Through 1Password (Priority: P3)

As a developer, I want sensitive values in my dotfiles (SSH keys, signing keys, API tokens) to be sourced from 1Password at activation time, so that I can commit my entire configuration to git without ever exposing secrets in plaintext.

**Why this priority**: Secrets management is the safety net that makes the entire "commit everything to git" approach viable. Without it, the administrator would need to manually exclude sensitive files or risk leaking credentials. This story completes the trust model.

**Independent Test**: Can be fully tested by inspecting the committed configuration files to confirm no plaintext secrets exist, then applying the configuration on a machine with 1Password authenticated to verify that secrets are correctly resolved and functional.

**Acceptance Scenarios**:

1. **Given** a dotfile that references a secret value (e.g., a git signing key), **When** the configuration repository is inspected (including full git history), **Then** no plaintext secret values appear anywhere — only references to the external secrets provider.
2. **Given** 1Password is authenticated on the machine, **When** the system configuration is applied, **Then** secret values are resolved and injected into the appropriate dotfiles at activation time.
3. **Given** 1Password is NOT authenticated on the machine, **When** the system configuration is applied, **Then** the system handles the missing secrets gracefully — non-secret functionality continues to work, and the administrator receives a clear indication of which secrets could not be resolved.
4. **Given** the administrator needs to add a new secret to a dotfile, **When** they follow the established pattern, **Then** they can add the secret reference without modifying the secrets resolution mechanism itself.

---

### User Story 4 - SSH Key Management Through 1Password (Priority: P4)

As a developer, I want my SSH keys managed through 1Password's SSH agent, so that private keys never exist as files on disk and I can use a single key store across authentication and commit signing.

**Why this priority**: SSH keys are the most commonly leaked secret in dotfile repositories. Delegating key storage to 1Password eliminates the risk of accidentally committing private keys and simplifies key management across multiple machines.

**Independent Test**: Can be fully tested by verifying that SSH connections to configured hosts succeed using the 1Password SSH agent, and that git commit signing works without any private key files present in `~/.ssh/`.

**Acceptance Scenarios**:

1. **Given** 1Password SSH agent is configured and running, **When** the user initiates an SSH connection to a configured host, **Then** authentication succeeds using keys stored in 1Password without any private key files on disk.
2. **Given** 1Password SSH agent is configured for git commit signing, **When** the user creates a git commit, **Then** the commit is signed using the key from 1Password.
3. **Given** the SSH configuration includes host entries, **When** the configuration is committed to version control, **Then** only non-sensitive host configuration (hostnames, usernames, port numbers) appears in the repository — no key material.

---

### Edge Cases

- What happens when the administrator rebuilds the system without internet access? The lockfile should allow offline builds from the local Nix store if dependencies were previously fetched.
- What happens when 1Password CLI session expires during a rebuild? The system should either prompt for re-authentication or fail with a clear error indicating which secrets could not be resolved.
- What happens when an existing manually-created dotfile conflicts with a declaratively managed one? The declarative configuration should take precedence, and the administrator should be warned about conflicts during activation.
- What happens when the administrator wants to temporarily override a managed dotfile for debugging? The system should support a clear mechanism for local overrides that don't get committed.
- What happens when dependency versions need to be updated? There should be a clear, single command to update the lockfile and review changes before applying.
- What happens if GnuPG SSH support is disabled but 1Password SSH agent is not yet configured? SSH authentication should fail with a clear error rather than silently falling back to no agent.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST lock all dependency versions in a committed lockfile so that builds are reproducible across machines and time.
- **FR-002**: The system MUST continue to function identically to the current configuration after migration — all existing packages, services, modules, and desktop environment settings MUST be preserved.
- **FR-003**: All existing feature modules (remote-terminal.nix, desktop-gnome.nix, desktop-cosmic.nix, desktop-icons.nix, esp32-dev.nix, photo-restoration.nix, playwright-dev.nix) MUST continue to work without modification to their contents.
- **FR-004**: The system MUST declaratively manage user dotfiles for the "todd" account, including at minimum: git configuration, zsh/Oh-My-Zsh configuration, tmux configuration, SSH client configuration, and AWS configuration (multiple named profiles).
- **FR-005**: The system MUST source all sensitive values (SSH keys, signing keys, API tokens, AWS access keys and secret keys) from 1Password at activation time, never storing them in plaintext in configuration files.
- **FR-015**: The system MUST declaratively manage AWS CLI configuration (~/.aws/config) with support for multiple named profiles, including region and output format per profile, while sourcing access key ID and secret access key for each profile from 1Password.
- **FR-006**: The system MUST integrate with 1Password's SSH agent for SSH key management, eliminating the need for private key files on disk. The existing GnuPG SSH agent support MUST be disabled to avoid conflict; GnuPG agent remains enabled for non-SSH uses (GPG encryption, signature verification).
- **FR-007**: The system MUST support git commit signing through 1Password-managed keys.
- **FR-008**: The system MUST provide a clear, repeatable pattern for adding new secrets so that extending the configuration does not require understanding the internals of the secrets mechanism.
- **FR-009**: The system MUST be rebuildable with a single command from the repository root.
- **FR-010**: The system MUST gracefully handle the case where 1Password is not authenticated — non-secret functionality should continue to work.
- **FR-011**: The lockfile and all non-secret configuration files MUST be committed to version control.
- **FR-012**: No plaintext secrets MUST appear in any committed file or in git history.
- **FR-013**: The new dotfile management module MUST follow the existing modular architecture pattern (separate .nix file imported from the main configuration).
- **FR-014**: The system MUST provide a clear command to update dependency versions (lockfile) when the administrator chooses to upgrade.

### Key Entities

- **System Configuration**: The declarative description of the entire NixOS system — packages, services, kernel parameters, user accounts. Currently defined in configuration.nix and feature modules.
- **Dotfile**: A user-level configuration file (e.g., .gitconfig, .zshrc, .tmux.conf, ~/.ssh/config, ~/.aws/config) that customizes the behavior of development tools. Managed declaratively and generated at activation time.
- **AWS Profile**: A named configuration block within ~/.aws/config defining region, output format, and credential source for a specific AWS account or role. Non-sensitive profile metadata is committed; access keys are sourced from 1Password.
- **Secret Reference**: A pointer to a value stored in 1Password (e.g., an `op://` URI) that is resolved at activation time. The reference itself is safe to commit; the resolved value is not.
- **Lockfile**: A machine-generated file that records the exact versions of all dependencies used in a build, ensuring reproducibility.
- **Feature Module**: A self-contained .nix file that encapsulates configuration for a specific feature area (e.g., remote-terminal.nix, desktop-gnome.nix). The new dotfile management module follows this pattern.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After migration, the system rebuilds successfully and all previously installed packages, services, and desktop environment features are functional — zero regressions.
- **SC-002**: The administrator can go from a fresh clone of the repository to a fully configured system (excluding secrets authentication) with a single rebuild command.
- **SC-003**: 100% of managed dotfiles are generated declaratively from the configuration — no manual file creation or copying required after a rebuild.
- **SC-004**: Zero plaintext secrets exist in any committed file across the entire git history of the repository.
- **SC-005**: Adding a new secret-backed value to a dotfile requires adding no more than 2 lines to the configuration (the reference and its usage).
- **SC-006**: SSH authentication and git commit signing work without any private key files stored on the local filesystem.
- **SC-007**: When 1Password is not authenticated, the system rebuild still completes successfully for all non-secret configuration, and the user receives clear feedback about unresolved secrets.
- **SC-008**: All existing feature modules continue to work without any modifications to their file contents.
- **SC-009**: Dependency updates are performed via a single command that updates the lockfile, allowing the administrator to review changes before applying.

## Assumptions

- The administrator (user "todd") has an active 1Password account with the 1Password CLI (`op`) available or installable.
- SSH keys and git signing keys are already stored (or will be stored) in 1Password before activation.
- The system has internet access during the initial migration to fetch and lock dependencies.
- The existing zsh configuration (Oh-My-Zsh with plugins: git, docker, docker-compose, aws, vi-mode, fzf; theme: robbyrussell) should be preserved exactly in the new declarative management.
- The existing tmux configuration (Catppuccin theme, current plugins) should be preserved in the new declarative management.
- The existing git configuration (name: Todd Costella, email: ToddCostella@gmail.com, default branch: main) should be preserved.
- The hostname `nixos-dev` will be used to identify this system's configuration.
- NixOS 24.05 compatibility is required; no features exclusive to newer releases should be used.
