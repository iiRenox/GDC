# Architecture Overview

This document outlines the high-level architecture of the game, detailing the major components and their interactions.

## Core Principles

- **Server-Authoritative**: The server is the single source of truth for all game state. Clients send requests, and the server validates and executes them.
- **Modularity**: Functionality is divided into independent services located in `ServerScriptService/Services/`. Each service manages a specific domain (e.g., building, combat, player resources).
- **Centralized Configuration**: All game balance constants, costs, and core settings are stored in `ReplicatedStorage/GameConfig`.
- **Secure Communication**: All client-server communication is routed through `ServerScriptService/RemoteHandler`, which performs validation, rate-limiting, and sanitation of all incoming requests.

## Data Flow

1.  **Client Input**: The client captures player input (e.g., movement, build requests, firing) and sends it to the server via a specific `RemoteEvent` or `RemoteFunction` in `ReplicatedStorage/Remotes`.
2.  **Remote Handler**: `RemoteHandler.server.lua` receives the request. It validates the player, checks for rate-limiting, and ensures the payload is valid.
3.  **Service Layer**: The `RemoteHandler` forwards the validated request to the appropriate service (e.g., `BuildManager`, `SpeederManager`).
4.  **State Change**: The service executes the game logic. This may involve checking player resources (`PlayerManager`), applying damage (`CombatService` via `HeartSystem`), or creating new instances (`BuildManager`).
5.  **Replication**: The server makes the necessary changes to the `Workspace` or other replicated storage. These changes are automatically replicated to all clients.
6.  **Client Feedback**: For purely visual or audio effects (e.g., explosions, hit markers), the server can fire a `RemoteEvent` back to clients to play the effect locally without affecting game state.

## Key Server Components

-   **GameManager**: Handles the overall match state, including team assignment, player spawning, and initializing all other services.
-   **RemoteHandler**: The secure gateway for all client-to-server communication.
-   **PlayerManager**: Manages player data, including team affiliation and Bit resources.
-   **BuildManager**: Manages the construction, placement, and ownership of all buildings.
-   **CombatService**: Processes all damage events, working with the `HeartSystem` to apply damage and handle destruction.
-   **HeartSystem (Module)**: A standalone module that manages the unique multi-stage health of all damageable entities.
-   **Vehicle/Unit Services** (`SpeederManager`, `TeslaService`, etc.): Each handles the specific logic for its corresponding unit type.