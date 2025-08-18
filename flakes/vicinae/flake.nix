{
  description = "Vicinae binary flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system (import nixpkgs { inherit system; }));
  in {
    packages = forAllSystems (system: pkgs: {
      vicinae = pkgs.stdenvNoCC.mkDerivation {
        pname = "vicinae";
        version = "0.2.1";
        src = pkgs.fetchurl {
          url = "https://github.com/vicinaehq/vicinae/releases/download/v0.2.1/vicinae-linux-x86_64-v0.2.1.tar.gz";
          sha256 = "736602fe2db2ba5dc829ab147b12ab5b4a3cec713c5fad1a073912f88ee79d02";
        };
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        unpackPhase = ''
          runHook preUnpack
          mkdir source
          cd source
          tar -xzf "$src"
          runHook postUnpack
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p "$out/bin"
          target=""
          if [ -f vicinae ]; then
            target="vicinae"
          else
            target="$(find . -type f -maxdepth 2 -name vicinae | head -n1 || true)"
          fi
          if [ -n "$target" ]; then
            install -m755 "$target" "$out/bin/vicinae"
          else
            echo "vicinae binary not found in archive" >&2
            exit 1
          fi
          runHook postInstall
        '';
        meta = with pkgs.lib; {
          description = "Vicinae prebuilt binary";
          homepage = "https://github.com/vicinaehq/vicinae";
          platforms = [ "x86_64-linux" ];
          license = licenses.unfree;
        };
      };
      default = self.packages.${system}.vicinae;
    });

    apps = forAllSystems (system: pkgs: {
      vicinae = {
        type = "app";
        program = "${self.packages.${system}.vicinae}/bin/vicinae";
      };
      default = self.apps.${system}.vicinae;
    });
  };
}
