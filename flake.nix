{
  description = "QSC MCP Server - Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        mkScript = name: text:
          pkgs.writeShellScriptBin name ''
            set -euo pipefail
            ${text}
          '';
      in
      {
        # nix develop
        devShells.default = pkgs.mkShell {
          name = "mcp-server-dev";
          buildInputs = [
            pkgs.python313
            pkgs.python313Packages.fastmcp
            pkgs.python313Packages.pip
            pkgs.python313Packages.cyclopts
            pkgs.python313Packages.requests
            pkgs.psmisc # provides fuser
            (mkScript "mcp-start" ''
              # Cleanup port 8001, 6274 (client), 6277 (proxy)
              fuser -k 8001/tcp 2>/dev/null || true
              fuser -k 6274/tcp 2>/dev/null || true
              fuser -k 6277/tcp 2>/dev/null || true
              
              echo "🚀 Starting MCP Server on http://localhost:8001..."
              python server.py &
              SERVER_PID=$!
              
              sleep 2
              echo "🔍 Starting MCP Inspector on http://localhost:6274..."
              # Inspector connecting to our server at the correct /mcp endpoint
              npx @modelcontextprotocol/inspector http://localhost:8001/mcp &
              INSPECTOR_PID=$!
              
              trap "kill $SERVER_PID $INSPECTOR_PID 2>/dev/null" EXIT
              wait
            '')
          ];
          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib 
            ]}:$LD_LIBRARY_PATH"  
            
            # Cleanup port 8001
            echo "Cleaning up port 8001..."
            fuser -k 8001/tcp 2>/dev/null || true

            if [ ! -d .venv ]; then
              echo "Creating virtual environment..."
              python -m venv .venv
            fi
            source .venv/bin/activate
            
            # Install mcp-ui-server if not present
            if ! python -c "import mcp_ui_server" 2>/dev/null; then
              echo "Installing mcp-ui-server..."
              pip install mcp-ui-server
            fi

            echo ""
            echo "╔══════════════════════════════════════════════╗"
            echo "║   MCP Server Development Shell               ║"
            echo "╠══════════════════════════════════════════════╣"
            echo "║  Standard MCP-UI (MCP Apps) Ready            ║"
            echo "║  Run 'mcp-start' to launch server + inspector║"
            echo "╚══════════════════════════════════════════════╝"
            echo ""
          '';
        };
      });
}
