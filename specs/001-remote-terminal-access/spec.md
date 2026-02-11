# Feature Specification: Remote Terminal Access from iOS

**Feature Branch**: `001-remote-terminal-access`
**Created**: 2026-02-11
**Status**: Draft
**Input**: User description: "My current configuration on my nixos machine is multiple wezterm panes in a single wezterm instance/window. My desire is to occasionally connect to my desktop machine from an iPhone or iPad to interact with my terminals. I am ok changing my wezterm usage to support this multi device configuration"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Connect to Desktop Terminals from iPad (Priority: P1)

Todd is away from his desk and needs to check on a long-running process or quickly interact with a terminal session on his NixOS desktop. He opens a terminal app on his iPad, connects to the desktop, and is presented with his existing terminal sessions — the same panes and running processes he left behind. He interacts with them as if sitting at the desktop, then closes the iPad and walks away. The sessions continue running on the desktop.

**Why this priority**: This is the core value proposition. Without reliable remote connection to persistent terminal sessions, nothing else matters.

**Independent Test**: Can be fully tested by connecting from an iOS device to the NixOS desktop over the local network, attaching to a running terminal session, executing a command, disconnecting, and verifying the session persists.

**Acceptance Scenarios**:

1. **Given** terminal sessions are running on the NixOS desktop, **When** Todd connects from his iPad via the terminal app, **Then** he can attach to the existing sessions and see all running panes/windows.
2. **Given** Todd is connected from his iPad, **When** he closes the terminal app or the iPad goes to sleep, **Then** all terminal sessions continue running on the desktop undisturbed.
3. **Given** Todd is connected from his iPad, **When** he executes commands in a terminal pane, **Then** the output appears in real time with no perceptible lag on a local network.

---

### User Story 2 - Survive Network Interruptions (Priority: P2)

Todd is connected from his iPhone over WiFi. He walks between rooms, his phone briefly switches networks, or the connection drops momentarily. Instead of losing his connection and having to reconnect and reattach manually, the connection recovers automatically and he picks up right where he left off.

**Why this priority**: Mobile devices frequently change networks. Without resilient connections, the remote experience is frustrating and unreliable.

**Independent Test**: Can be tested by connecting from an iOS device, toggling airplane mode on for 10 seconds, toggling it off, and verifying the session resumes without manual reconnection.

**Acceptance Scenarios**:

1. **Given** Todd is connected from his iPhone, **When** the WiFi connection drops for up to 30 seconds, **Then** the session automatically reconnects without requiring manual intervention.
2. **Given** Todd is connected over WiFi, **When** the device switches between WiFi networks, **Then** the session resumes within a few seconds of the new network being available.
3. **Given** Todd is connected from his iPad, **When** the iPad goes to sleep and wakes up minutes later, **Then** the session is either still connected or reconnects automatically.

---

### User Story 3 - Use the Same Terminal Layout on Desktop and Remotely (Priority: P3)

Todd wants a consistent workflow. When he is at his desk, he uses WezTerm to interact with his terminal sessions. The same sessions he sees locally are the ones he connects to remotely. He does not need to maintain two separate sets of terminals — one local, one remote.

**Why this priority**: Workflow consistency avoids cognitive overhead and duplicate processes. This is what makes the setup feel seamless rather than bolted-on.

**Independent Test**: Can be tested by creating a named terminal session on the desktop, verifying it is visible from WezTerm locally, then connecting from an iOS device and confirming the same session is accessible.

**Acceptance Scenarios**:

1. **Given** Todd has terminal sessions running, **When** he sits at his desktop and opens WezTerm, **Then** he can attach to the same persistent sessions he accesses remotely.
2. **Given** Todd creates a new terminal window remotely from his iPad, **When** he returns to his desktop, **Then** the new window is available in his local WezTerm session.

---

### Edge Cases

- What happens when Todd connects from his iPad while also being actively connected at his desktop? Both connections MUST coexist — the remote connection MUST NOT disconnect the local session.
- What happens when the desktop machine reboots? Terminal sessions are lost (expected behavior). Todd MUST be able to start new sessions after the machine boots.
- What happens when Todd connects from outside the local network? Remote access is scoped to the local network only. Connections from outside the home network are out of scope and the firewall MUST NOT expose connection ports to the public internet.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The NixOS system MUST run a terminal multiplexer that keeps terminal sessions alive independently of any connected client.
- **FR-002**: The NixOS system MUST accept remote terminal connections over an encrypted protocol.
- **FR-003**: The remote connection MUST support automatic reconnection after network interruptions without losing the terminal session.
- **FR-004**: Todd MUST be able to connect from an iPhone or iPad using a commercially available iOS terminal app.
- **FR-005**: WezTerm on the desktop MUST be able to attach to the same persistent terminal sessions used by remote clients.
- **FR-006**: Multiple simultaneous connections (local desktop + remote iOS) to the same terminal sessions MUST be supported.
- **FR-007**: The NixOS firewall MUST be configured to allow the necessary inbound connection ports.
- **FR-008**: All configuration changes MUST be declarative in the NixOS `.nix` files (per project constitution).
- **FR-009**: The system MUST authenticate remote connections using SSH key-based authentication.

### Key Entities

- **Terminal Session**: A persistent, named collection of terminal panes/windows that survives client disconnection. Has a name, creation time, and one or more attached clients.
- **Remote Connection**: An encrypted network session from an iOS device to the NixOS desktop. Has a transport protocol, connection state (connected/reconnecting/disconnected), and an associated terminal session.
- **Local Connection**: A WezTerm instance on the desktop attached to the same persistent terminal sessions. Coexists with remote connections.

### Assumptions

- The NixOS desktop is powered on and connected to the network when remote access is needed.
- Todd already has SSH key-based authentication set up, or will set it up as part of this feature.
- An iOS terminal app will need to be purchased/installed separately on Todd's devices (not part of the NixOS configuration).
- WezTerm will remain the local desktop terminal emulator; the change is in how sessions are managed (moving pane management to the multiplexer rather than WezTerm-native panes).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Todd can connect from an iOS device and interact with a terminal session within 10 seconds of opening the app.
- **SC-002**: Terminal sessions persist through client disconnection — reconnecting after 5 minutes shows the same session state and running processes.
- **SC-003**: After a network interruption of up to 30 seconds, the session resumes automatically without Todd needing to manually reconnect and reattach.
- **SC-004**: Todd can interact with the same terminal sessions from both WezTerm on the desktop and the iOS app simultaneously.
- **SC-005**: The entire configuration is applied via a single `sudo nixos-rebuild switch` with no manual post-install steps beyond iOS app setup.
