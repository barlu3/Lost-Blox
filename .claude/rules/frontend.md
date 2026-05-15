---
paths:
  - "src/client/**"
---

# Roblox UI

## Structure

- All UI lives in LocalScripts under `src/client/`. Never create UI from the server.
- Use `PlayerGui` as the root, not `game.StarterGui` directly.
- Separate UI logic (LocalScript) from UI layout (`.rbxmx` or instance creation in a dedicated module).

## Principles

- Use `UICorner`, `UIStroke`, `UIPadding`, and `UIListLayout` instead of manually tweening or sizing elements.
- Anchor points and position should use scale values (0–1) over offset wherever possible for resolution independence.
- Never hardcode pixel sizes for layout-critical elements; use `UDim2` scale.

## Input

- Use `UserInputService` for keyboard/mouse. Use `ContextActionService` for gamepad/mobile-compatible actions.
- Always guard input handlers with `if not game:GetService("UserInputService").KeyboardEnabled then` checks for cross-platform support.
- Mobile: touch targets minimum 44x44 pixels (offset).

## Performance

- Tween with `TweenService`, not loops. Use `EasingStyle` and `EasingDirection` intentionally.
- Destroy UI elements when they are no longer needed; don't just hide them if they hold connections.
- Disconnect all `RBXScriptConnection`s when a UI component is removed.
