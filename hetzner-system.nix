{ self, nixpkgs }:

{ config, pkgs, ... }:

let
  keys = import ./keys.nix;

  # buildFirecrackerImage = _:
  #   pkgs.stdenv.mkDerivation {
  #     pname = "firecracker-image";
  #     version = "1";
  #     src = /dev/null;
  #     buildInputs = with pkgs; [
  #       firecracker
  #       firectl
  #       e2fsprogs
  #     ];

  #     buildPhase = ''
  #       dd of=disk.img if=/dev/zero bs=1M count=4096
  #       mkfs.ext4 disk.img
  #     '';
  #   };

in {
  imports = [./hetzner-hardware.nix];

  environment.systemPackages = with pkgs; [
    gcc
    tmux
    elixir_1_12
    erlangR24
    beamPackages.elixir_ls
    file
    firecracker
    firectl
    git
    gnumake
    ripgrep
    tailscale
    vim
    lsof

    nodejs-16_x
    yarn
  ];

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
      secret-key-files = /run/node.town.pem
    '';
  };

  nix.registry.nixpkgs.flake = nixpkgs;

  services.openssh.enable = true;
  security.sudo.wheelNeedsPassword = false;

  programs.mosh.enable = true;

  networking.hostName = "hamlet";
  time.timeZone = "Europe/Riga";

  programs.bash.promptInit = ''
    if [ "$TERM" != "dumb" -o -n "$INSIDE_EMACS" ]; then
      PS1=$'\[\e[1m\]\h\[\e[0m\]:\w\[\e[1m\]`eval "$PS1GIT"`\[\e[0m\]\$ '
      PS1GIT='[[ `git status --short 2>/dev/null` ]] && echo \*'
      [[ $TERM = xterm ]] && PS1='\[\033]2;\h:\w\007\]'"$PS1"
    fi
  '';

  users.users.root.openssh.authorizedKeys.keys = [keys.mbrock-ssh];
  users.users.mbrock = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [keys.mbrock-ssh];
  };

  users.users.firecracker = {
    isSystemUser = true;
  };

  services.gitDaemon = {
    enable = true;
    basePath = "/srv/git";
    repositories = ["/srv/git"];
  };

  system.activationScripts = {
    setupGitRoot = ''
      mkdir -p /srv/git
      chown git /srv/git
      chgrp wheel /srv/git
      chmod 775 /srv/git
    '';
  };

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/nvme0n1";

  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;

  system.stateVersion = "21.11";

  networking = {
    networkmanager.enable = true;
    nat.enable = true;

    firewall = {
      enable = true;
      trustedInterfaces = ["tailscale0"];
      allowedUDPPorts = [config.services.tailscale.port];
      allowedTCPPorts = [80 443 9418];
      allowPing = true;
    };
  };

  services.tailscale.enable = true;

  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";
    after = ["network-pre.target" "tailscale.service"];
    wants = ["network-pre.target" "tailscale.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig.Type = "oneshot";
    script = ''
      sleep 2
      PATH=${pkgs.tailscale}/bin:${pkgs.jq}/bin:$PATH
      status="$(tailscale status -json | jq -r .BackendState)"
      if [ $status = "Running" ]; then
        exit 0
      fi

      authkey=$(cat /run/keys/tailscale-connect)

      tailscale up -authkey "$authkey"
    '';
  };

  security.acme.acceptTerms = true;
  security.acme.email = "mikael@brockman.se";
  security.acme.certs."node.town" = {
    group = "nginx";
    credentialsFile = "/secrets/acme.env";
    dnsProvider = "dnsimple";
    domain = "node.town";
    extraDomainNames = [
      "*.node.town"
      "*.tty.node.town"
    ];
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      "node.town" = {
        forceSSL = true;
        useACMEHost = "node.town";
        locations."/" = {
          root = "/restless/www";
        };
      };

      "root.node.town" = {
        forceSSL = true;
        useACMEHost = "node.town";
        locations."/" = {
          root = "/restless/www/root";
        };
      };
    };
  };

  services.nix-serve = {
    enable = true;
    secretKeyFile = "/run/node.town.pem";
  };
}
