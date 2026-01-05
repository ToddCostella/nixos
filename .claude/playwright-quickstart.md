# Playwright Quick Start

## Enable Playwright Dependencies

1. Edit `configuration.nix` and add to the imports section:
   ```nix
   imports = [
     ./playwright-dev.nix  # Add this line
   ];
   ```

2. Apply the configuration:
   ```bash
   sudo nixos-rebuild switch
   ```

3. Install Playwright browsers in Buoyancy Platform:
   ```bash
   cd /home/todd/dev/buoyancy-platform/frontend
   npx playwright install chromium
   ```

4. Run E2E tests:
   ```bash
   npx playwright test interaction-panel.spec.ts
   ```

See `PLAYWRIGHT-SETUP.md` for full documentation.
