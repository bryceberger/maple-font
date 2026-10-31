{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    nixpkgs,
    pyproject-build-systems,
    pyproject-nix,
    uv2nix,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    lib = pkgs.lib;

    workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = ./.;};
    python = pkgs.python3;
    uv-lock = workspace.mkPyprojectOverlay {
      sourcePreference = "wheel";
    };

    hacks = pkgs.callPackage pyproject-nix.build.hacks {};
    prebuilt = final: prev: {
      afdko = hacks.nixpkgsPrebuilt {
        from = python.pkgs.afdko;
        prev = prev.afdko;
      };
    };

    pythonSet = (pkgs.callPackage pyproject-nix.build.packages {inherit python;}).overrideScope (
      lib.composeManyExtensions [
        pyproject-build-systems.overlays.wheel
        uv-lock
        prebuilt
      ]
    );

    venv = pythonSet.mkVirtualEnv "maple-font-env" workspace.deps.all;
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [venv];
    };

    packages.${system}.default = pkgs.stdenv.mkDerivation {
      pname = "maple-font";
      version = "v7.9";
      src = ./.;

      outputs = ["out" "webfont"];
      nativeBuildInputs = [
        venv
        pkgs.installFonts
      ];

      buildPhase = ''
        python3 ./build.py
      '';
    };
  };
}
