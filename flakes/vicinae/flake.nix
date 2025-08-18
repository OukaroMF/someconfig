{
  description = "Vicinae binary flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" ];
    forAllSystems =
      f: nixpkgs.lib.genAttrs systems (system:
        let pkgs = import nixpkgs { inherit system; };
        in f system pkgs
      );
  in {
    packages = forAllSystems (system: pkgs: {
      vicinae = pkgs.stdenvNoCC.mkDerivation {
        pname = "vicinae";
        version = "0.2.1";
        src = pkgs.fetchurl {
          url = "https://github.com/vicinaehq/vicinae/releases/download/v0.2.1/vicinae-linux-x86_64-v0.2.1.tar.gz";
          sha256 = "736602fe2db2ba5dc829ab147b12ab5b4a3cec713c5fad1a073912f88ee79d02";
        };
        nativeBuildInputs = [ pkgs.makeWrapper ];
        buildInputs = [
          pkgs.qt6.qtbase
          pkgs.qt6.qtwayland
          pkgs.qt6.qtsvg
          pkgs.libglvnd
          pkgs.stdenv.cc.cc.lib
          pkgs.abseil-cpp
          pkgs.fontconfig
          pkgs.freetype
          pkgs.libxkbcommon
          pkgs.xorg.libX11
        ];
        dontAutoPatchelf = true;
        dontWrapQtApps = true; # 避免 qtPreHook 报错，改用自定义 wrapProgram
        # 移除 qtWrapperArgs 中对 self 的递归引用，改由 postFixup 的 wrapProgram 注入 LD_LIBRARY_PATH
        # qtWrapperArgs = [ ... ];
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
          # 安装 share 资源（desktop、icons、qt 资源等）
          if [ -d share ]; then
            mkdir -p "$out/share"
            cp -R share/* "$out/share/"
          fi

          # 创建与上游期望的 Abseil 版本号匹配的兼容链接目录
          mkdir -p "$out/lib/compat"
          for base in \
            libabsl_graphcycles_internal \
            libabsl_kernel_timeout_internal \
            libabsl_malloc_internal \
            libabsl_tracing_internal \
            libabsl_time \
            libabsl_civil_time \
            libabsl_time_zone \
            libabsl_strings \
            libabsl_int128 \
            libabsl_strings_internal \
            libabsl_string_view \
            libabsl_base \
            libabsl_spinlock_wait \
            libabsl_throw_delegate \
            libabsl_raw_logging_internal \
            libabsl_log_severity; do
            src=""
            for cand in ${pkgs.abseil-cpp}/lib/$base.so ${pkgs.abseil-cpp}/lib/$base.so.*; do
              if [ -e "$cand" ]; then src="$cand"; break; fi
            done
            if [ -n "$src" ]; then
              ln -sf "$src" "$out/lib/compat/$base.so.2505.0.0" || true
            fi
          done

          runHook postInstall
        '';
        postFixup = let
          depsLibPath = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.libglvnd
            pkgs.abseil-cpp
            pkgs.qt6.qtbase
            pkgs.qt6.qtwayland
            pkgs.qt6.qtsvg
            pkgs.fontconfig
            pkgs.freetype
            pkgs.libxkbcommon
            pkgs.xorg.libX11
          ];
          qtPluginPath = pkgs.lib.makeSearchPath "lib/qt6/plugins" [ pkgs.qt6.qtbase pkgs.qt6.qtwayland pkgs.qt6.qtsvg ];
        in ''
          wrapProgram "$out/bin/vicinae" \
            --prefix LD_LIBRARY_PATH : "$out/lib/compat:${depsLibPath}" \
            --set-default QT_PLUGIN_PATH "${qtPluginPath}" \
            --set-default QT_QPA_PLATFORM "wayland;xcb"
        '';
        meta = with pkgs.lib; {
          description = "Vicinae prebuilt binary";
          homepage = "https://github.com/vicinaehq/vicinae";
          platforms = [ "x86_64-linux" ];
          license = licenses.gpl3Only;
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
