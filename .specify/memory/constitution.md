<!--
Sync Impact Report
==================
Version change: N/A → 1.0.0 (initial ratification)
Modified principles: N/A (initial creation)
Added sections:
  - Core Principles (5 principles)
  - Operational Constraints
  - Development Workflow
  - Governance
Removed sections: N/A
Templates requiring updates:
  - .specify/templates/plan-template.md: ✅ no update needed
    (Constitution Check section is generic; gates will be
    derived from these principles at plan time)
  - .specify/templates/spec-template.md: ✅ no update needed
    (spec template is feature-agnostic; requirements
    sections align with principles)
  - .specify/templates/tasks-template.md: ✅ no update needed
    (task phases and parallel markers are compatible)
  - .specify/templates/checklist-template.md: ✅ no update needed
  - .specify/templates/agent-file-template.md: ✅ no update needed
Follow-up TODOs: none
-->

# NixOS Config Constitution

## Core Principles

### I. Declarative Configuration

All system state MUST be expressed declaratively in Nix
configuration files. Imperative changes made outside of the
configuration are considered ephemeral and MUST NOT be relied
upon for system correctness.

- Every installed package, enabled service, and user setting
  MUST be traceable to a `.nix` file in this repository.
- The system MUST be fully reproducible from a clean install
  by applying this configuration.
- `hardware-configuration.nix` is auto-generated and MUST NOT
  be modified manually.

**Rationale**: Declarative configuration eliminates drift,
enables rollback, and makes the system state auditable.

### II. Test Before Apply

All configuration changes MUST be validated before they are
applied to the running system.

- Run `sudo nixos-rebuild dry-build` to check for syntax and
  evaluation errors before applying any change.
- Use `sudo nixos-rebuild test` when validating non-trivial
  changes without making them the default boot entry.
- Only after successful validation, apply with
  `sudo nixos-rebuild switch`.
- Commit changes to git only after successful application.

**Rationale**: NixOS provides first-class rollback, but broken
configurations can still disrupt a running session. Validating
first prevents avoidable downtime.

### III. Modularity

System configuration MUST be organized into focused,
composable modules. Each module MUST have a single clear
responsibility.

- Domain-specific concerns (e.g., Playwright dependencies,
  ESP32 tooling, desktop environment) MUST reside in
  dedicated `.nix` files.
- `configuration.nix` serves as the top-level composition
  root that imports modules; it SHOULD NOT contain large
  inline blocks that belong in a module.
- New functionality SHOULD be added as a new module when it
  represents a distinct domain (development toolchain,
  hardware support, desktop customization).

**Rationale**: Modules keep the configuration navigable,
enable selective inclusion, and reduce merge conflicts.

### IV. Reproducibility

The configuration MUST produce a consistent system across
rebuilds and across machines sharing the same hardware
profile.

- Pin Nix channels or flake inputs when stability is
  required.
- Avoid non-deterministic constructs (e.g., `fetchurl`
  without a hash, mutable state in derivations).
- Document any external dependencies that fall outside the
  Nix store (e.g., Docker images pulled at runtime).

**Rationale**: Reproducibility is the foundational promise
of NixOS. Violations undermine the value of declarative
configuration.

### V. Simplicity

Prefer the simplest configuration that meets current needs.
Do not add abstractions, overlays, or indirection layers for
hypothetical future requirements.

- YAGNI: Do not introduce flakes, overlays, or custom
  derivations unless a concrete need is demonstrated.
- Favor upstream NixOS options over custom wrappers.
- Three similar lines of configuration are better than a
  premature abstraction.
- Complexity MUST be justified in a comment when it cannot
  be avoided.

**Rationale**: NixOS configurations can become opaque
quickly. Simplicity keeps the system maintainable by a
single developer.

## Operational Constraints

- **Single-machine scope**: This configuration targets one
  development workstation. Multi-host orchestration is out
  of scope unless explicitly introduced.
- **Technology stack**: NixOS with systemd-boot, GNOME/Sway
  window management, Docker for containerized workloads,
  zsh as the default shell.
- **User model**: Single primary user (`todd`) with sudo
  and Docker group membership.
- **Security baseline**: Do not commit secrets, tokens, or
  credentials to this repository. Use environment variables
  or external secret managers.

## Development Workflow

1. Identify the change: new package, service toggle,
   module addition, or configuration tweak.
2. Edit the appropriate `.nix` file (or create a new
   module if Principle III requires it).
3. Validate: `sudo nixos-rebuild dry-build`.
4. Apply: `sudo nixos-rebuild switch`.
5. Verify the change works as expected.
6. Commit to git with a descriptive message.
7. If the change breaks the system, rollback:
   `sudo nixos-rebuild rollback`.

All changes MUST follow this sequence. Skipping validation
(step 3) is acceptable only for trivial comment or
formatting edits.

## Governance

- This constitution is the authoritative source of
  project-level principles. It supersedes ad-hoc
  conventions.
- Amendments MUST be documented with a version bump, a
  rationale, and an updated `Last Amended` date.
- Versioning follows semantic versioning:
  - **MAJOR**: Principle removed or fundamentally redefined.
  - **MINOR**: New principle added or existing principle
    materially expanded.
  - **PATCH**: Wording clarifications, typo fixes, or
    non-semantic refinements.
- All configuration changes SHOULD be reviewed against
  these principles before committing.
- Use `CLAUDE.md` for runtime development guidance
  specific to AI-assisted workflows.

**Version**: 1.0.0 | **Ratified**: 2026-02-11 | **Last Amended**: 2026-02-11
