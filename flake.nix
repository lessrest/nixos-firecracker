{
  inputs = {
    nixpkgs.url = path:/home/mbrock/nixpkgs;
    home-manager.url = github:nix-community/home-manager;
    emacs-overlay.url = github:nix-community/emacs-overlay;
    deploy-rs.url = github:serokell/deploy-rs;

    # nc-vsock = {
    #   url = github:stefanha/nc-vsock;
    #   flake = false;
    # };

    figlet-fonts = {
      flake = false;
      url = github:xero/figlet-fonts;
    };
  };

  outputs = { self, nixpkgs, home-manager, emacs-overlay, deploy-rs, figlet-fonts }:
    let
      systemKernel = system: system.config.system.build.kernel.dev;

      firecrackerSystem = { isContainer }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (import ./firecracker/system.nix {
              inherit nixpkgs figlet-fonts;
              isContainer = isContainer;
            })

            home-manager.nixosModules.home-manager
            {
              nixpkgs.overlays = [emacs-overlay.overlay];
            }
          ];
        };

    in {
      nixosConfigurations.hetzner = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          home-manager.nixosModules.home-manager

          (import ./hetzner-system.nix {
            inherit self nixpkgs;
          })

          (import ./firecracker-guests.nix {
            inherit self;
          })

          {
            restless.firecracker.networkSize = 5;

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.mbrock = import ./mbrock.nix;

            nixpkgs.overlays = [emacs-overlay.overlay];

            environment.systemPackages = [
              deploy-rs.packages.x86_64-linux.deploy-rs
            ];
          }
        ];
      };

      nixosConfigurations.firecracker-container =
        firecrackerSystem { isContainer = true; };

      nixosConfigurations.firecracker =
        firecrackerSystem { isContainer = false; };

      firecracker-vmlinux =
        let system = self.nixosConfigurations.firecracker;
        in system.config.system.build.kernel.dev;

      firecracker-rootfs =
        let system = self.nixosConfigurations.firecracker-container;
        in system.config.system.build.rootfs;

      deploy.nodes.guest-1 = {
        hostname = "tap1.local";
        profiles.system = {
          fastConnection = true;
          sshUser = "mbrock";
          user = "root";
          path =
            deploy-rs.lib.x86_64-linux.activate.nixos
              self.nixosConfigurations.firecracker-container;
        };
      };
    };
}
