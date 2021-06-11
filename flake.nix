{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";

  outputs = { self, nixpkgs }:
    let
      systemKernel = system: system.config.system.build.kernel.dev;
    in {
      nixosConfigurations.hetzner = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [(import ./hetzner.nix { inherit self nixpkgs; } )];
      };

      nixosConfigurations.firecracker = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [(import ./firecracker-system.nix)];
      };

      firecracker-vmlinux =
        self.nixosConfigurations.firecracker.config.system.build.kernel.dev;
    };
}
